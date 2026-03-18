from __future__ import annotations

import hashlib
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import DailyMission, DailyProgress
from app.models.user import User
from app.schemas.missions import MissionClaimRequest, MissionClaimResponse, MissionResponse
from app.services.gamification import calculate_level, check_and_grant_achievements
from app.utils.date import get_today_kst

router = APIRouter(prefix="/api/v1/missions", tags=["missions"])

MISSION_POOL = [
    {"type": "words_5", "category": "words", "targetCount": 5, "xpReward": 15, "progressField": "words_studied"},
    {"type": "words_10", "category": "words", "targetCount": 10, "xpReward": 30, "progressField": "words_studied"},
    {"type": "quiz_1", "category": "quiz", "targetCount": 1, "xpReward": 10, "progressField": "quizzes_completed"},
    {"type": "quiz_3", "category": "quiz", "targetCount": 3, "xpReward": 25, "progressField": "quizzes_completed"},
    {"type": "correct_10", "category": "correct", "targetCount": 10, "xpReward": 15, "progressField": "correct_answers"},
    {"type": "correct_20", "category": "correct", "targetCount": 20, "xpReward": 30, "progressField": "correct_answers"},
    {"type": "chat_1", "category": "chat", "targetCount": 1, "xpReward": 20, "progressField": "conversation_count"},
    {"type": "chat_2", "category": "chat", "targetCount": 2, "xpReward": 35, "progressField": "conversation_count"},
    {"type": "kana_learn_5", "category": "kana", "targetCount": 5, "xpReward": 15, "progressField": "kana_learned"},
]

# 미션 타입별 한국어 라벨/설명 매핑
MISSION_TEXT: dict[str, tuple[str, str]] = {
    "words_5": ("단어 5개 학습", "오늘 단어를 5개 학습하세요"),
    "words_10": ("단어 10개 학습", "오늘 단어를 10개 학습하세요"),
    "quiz_1": ("퀴즈 1회 완료", "퀴즈를 1회 완료하세요"),
    "quiz_3": ("퀴즈 3회 완료", "퀴즈를 3회 완료하세요"),
    "correct_10": ("정답 10개 달성", "퀴즈에서 10개 정답을 맞추세요"),
    "correct_20": ("정답 20개 달성", "퀴즈에서 20개 정답을 맞추세요"),
    "chat_1": ("AI 회화 1회", "AI와 일본어 회화를 1회 진행하세요"),
    "chat_2": ("AI 회화 2회", "AI와 일본어 회화를 2회 진행하세요"),
    "kana_learn_5": ("가나 5개 학습", "히라가나/카타카나를 5개 학습하세요"),
}

XP_REWARDS = {m["type"]: m["xpReward"] for m in MISSION_POOL}


def _select_missions(user_id: str, date_str: str) -> list[dict]:
    """Deterministic 3 missions per day using date+userId as seed."""
    seed = hashlib.md5(f"{date_str}:{user_id}".encode(), usedforsecurity=False).hexdigest()
    seed_int = int(seed, 16)

    categories = {}
    for m in MISSION_POOL:
        categories.setdefault(m["category"], []).append(m)

    cat_keys = sorted(categories.keys())
    selected = []
    for i in range(3):
        cat_idx = (seed_int + i) % len(cat_keys)
        cat = cat_keys[cat_idx]
        missions_in_cat = categories[cat]
        m_idx = (seed_int + i * 7) % len(missions_in_cat)
        selected.append(missions_in_cat[m_idx])

    return selected


@router.get("/today", response_model=list[MissionResponse], status_code=200)
async def get_today_missions(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    today = get_today_kst()
    date_str = str(today)

    # Check existing missions
    result = await db.execute(select(DailyMission).where(DailyMission.user_id == user.id, DailyMission.date == today))
    existing = list(result.scalars().all())

    if not existing:
        # Generate today's missions
        selected = _select_missions(str(user.id), date_str)
        for m in selected:
            mission = DailyMission(
                user_id=user.id,
                date=today,
                mission_type=m["type"],
                target_count=m["targetCount"],
            )
            db.add(mission)
        await db.flush()

        result = await db.execute(select(DailyMission).where(DailyMission.user_id == user.id, DailyMission.date == today))
        existing = list(result.scalars().all())

    # Update currentCount from DailyProgress
    dp_result = await db.execute(select(DailyProgress).where(DailyProgress.user_id == user.id, DailyProgress.date == today))
    dp = dp_result.scalar_one_or_none()

    progress_map = {}
    if dp:
        progress_map = {
            "words_studied": dp.words_studied,
            "quizzes_completed": dp.quizzes_completed,
            "correct_answers": dp.correct_answers,
            "conversation_count": dp.conversation_count,
            "kana_learned": dp.kana_learned,
        }

    missions_response = []
    for mission in existing:
        pool_def = next((m for m in MISSION_POOL if m["type"] == mission.mission_type), None)
        progress_field = pool_def["progressField"] if pool_def else ""
        current = progress_map.get(progress_field, 0)

        mission.current_count = current
        mission.is_completed = current >= mission.target_count

        # Auto-award completed missions
        if mission.is_completed and not mission.reward_claimed:
            xp = XP_REWARDS.get(mission.mission_type, 0)
            if xp > 0:
                user.experience_points += xp
                level_info = calculate_level(user.experience_points)
                user.level = level_info["level"]
                mission.reward_claimed = True

        label, description = MISSION_TEXT.get(mission.mission_type, (mission.mission_type, ""))
        missions_response.append(
            MissionResponse(
                id=mission.id,
                mission_type=mission.mission_type,
                label=label,
                description=description,
                target_count=mission.target_count,
                current_count=current,
                is_completed=mission.is_completed,
                reward_claimed=mission.reward_claimed,
                xp_reward=XP_REWARDS.get(mission.mission_type, 0),
            )
        )

    await db.commit()
    return missions_response


@router.post("/claim", response_model=MissionClaimResponse, status_code=200)
async def claim_mission(
    body: MissionClaimRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    mission = await db.get(DailyMission, body.mission_id)
    if not mission or mission.user_id != user.id:
        raise HTTPException(status_code=404, detail="미션을 찾을 수 없습니다")
    if not mission.is_completed:
        raise HTTPException(status_code=400, detail="미션이 완료되지 않았습니다")
    if mission.reward_claimed:
        raise HTTPException(status_code=400, detail="이미 보상을 받았습니다")

    xp_reward = XP_REWARDS.get(mission.mission_type, 0)
    old_level = user.level
    user.experience_points += xp_reward
    level_info = calculate_level(user.experience_points)
    user.level = level_info["level"]
    mission.reward_claimed = True

    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": user.level,
            "old_level": old_level,
            "streak_count": user.streak_count,
        },
    )

    await db.commit()
    await db.refresh(user)

    return MissionClaimResponse(
        xp_reward=xp_reward,
        total_xp=user.experience_points,
        events=events,
    )
