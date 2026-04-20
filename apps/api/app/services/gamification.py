from __future__ import annotations

import math
import uuid
from datetime import UTC, date, datetime
from typing import Any, TypedDict

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AiCharacter, UserAchievement, UserCharacterUnlock

# ==========================================
# 레벨 시스템
# ==========================================


class LevelInfo(TypedDict):
    level: int
    current_xp: int
    xp_for_next: int


def calculate_level(total_xp: int) -> LevelInfo:
    """현재 XP 기반으로 레벨 계산. level = floor(sqrt(totalXP / 100)) + 1"""
    level = math.floor(math.sqrt(total_xp / 100)) + 1
    xp_at_current_level = (level - 1) ** 2 * 100
    xp_at_next_level = level**2 * 100
    return {
        "level": level,
        "current_xp": total_xp - xp_at_current_level,
        "xp_for_next": xp_at_next_level - xp_at_current_level,
    }


# ==========================================
# 스트릭 시스템
# ==========================================


class StreakResult(TypedDict):
    streak_count: int
    longest_streak: int
    streak_broken: bool


def update_streak(
    last_study_date: datetime | None,
    current_streak: int,
    longest_streak: int,
    today_kst: datetime | None = None,
) -> StreakResult:
    """연속 학습일(스트릭) 업데이트."""
    if today_kst is not None:
        today = date(today_kst.year, today_kst.month, today_kst.day)
    else:
        now = datetime.now(tz=UTC)
        today = now.date()

    if last_study_date is None:
        return {
            "streak_count": 1,
            "longest_streak": max(1, longest_streak),
            "streak_broken": False,
        }

    last_day = last_study_date.date() if isinstance(last_study_date, datetime) else last_study_date
    diff_days = (today - last_day).days

    if diff_days == 0:
        return {
            "streak_count": current_streak,
            "longest_streak": longest_streak,
            "streak_broken": False,
        }

    if diff_days == 1:
        new_streak = current_streak + 1
        return {
            "streak_count": new_streak,
            "longest_streak": max(new_streak, longest_streak),
            "streak_broken": False,
        }

    # 하루 이상 건너뜀 - 스트릭 리셋
    return {
        "streak_count": 1,
        "longest_streak": longest_streak,
        "streak_broken": True,
    }


# ==========================================
# 업적 시스템
# ==========================================

AchievementCategory = str  # 'level' | 'streak' | 'xp' | 'quiz' | 'words' | 'conversation' | 'special' | 'kana'
AchievementType = str


class AchievementDef(TypedDict, total=False):
    type: str
    title: str
    description: str
    emoji: str
    category: str
    threshold: int | None


ACHIEVEMENTS: list[AchievementDef] = [
    # 퀴즈
    {
        "type": "first_quiz",
        "title": "첫 퀴즈 완료!",
        "description": "첫 번째 퀴즈를 완료했어요",
        "emoji": "target",
        "category": "quiz",
        "threshold": 1,
    },
    {
        "type": "quiz_10",
        "title": "퀴즈 10회 달성",
        "description": "퀴즈를 10번 완료했어요",
        "emoji": "file-text",
        "category": "quiz",
        "threshold": 10,
    },
    {
        "type": "quiz_50",
        "title": "퀴즈 50회 달성",
        "description": "퀴즈를 50번 완료했어요",
        "emoji": "library",
        "category": "quiz",
        "threshold": 50,
    },
    {
        "type": "quiz_100",
        "title": "퀴즈 마스터",
        "description": "퀴즈를 100번 완료했어요",
        "emoji": "trophy",
        "category": "quiz",
        "threshold": 100,
    },
    {"type": "perfect_quiz", "title": "퍼펙트!", "description": "퀴즈에서 전부 맞았어요", "emoji": "check-check", "category": "special"},
    # 회화
    {
        "type": "first_conversation",
        "title": "첫 회화 완료!",
        "description": "첫 번째 AI 회화를 완료했어요",
        "emoji": "message-circle",
        "category": "conversation",
        "threshold": 1,
    },
    {
        "type": "conversation_10",
        "title": "회화 10회 달성",
        "description": "AI 회화를 10번 완료했어요",
        "emoji": "messages-square",
        "category": "conversation",
        "threshold": 10,
    },
    {
        "type": "conversation_50",
        "title": "대화의 달인",
        "description": "AI 회화를 50번 완료했어요",
        "emoji": "mic",
        "category": "conversation",
        "threshold": 50,
    },
    # 스트릭
    {
        "type": "streak_3",
        "title": "3일 연속 학습",
        "description": "3일 연속으로 학습했어요",
        "emoji": "flame",
        "category": "streak",
        "threshold": 3,
    },
    {
        "type": "streak_7",
        "title": "일주일 연속 학습",
        "description": "7일 연속으로 학습했어요",
        "emoji": "zap",
        "category": "streak",
        "threshold": 7,
    },
    {
        "type": "streak_30",
        "title": "한 달 연속 학습",
        "description": "30일 연속으로 학습했어요",
        "emoji": "sparkles",
        "category": "streak",
        "threshold": 30,
    },
    {
        "type": "streak_100",
        "title": "100일 연속 학습",
        "description": "100일 연속으로 학습했어요",
        "emoji": "crown",
        "category": "streak",
        "threshold": 100,
    },
    # 단어 학습
    {
        "type": "words_50",
        "title": "단어 50개 학습",
        "description": "총 50개의 단어를 학습했어요",
        "emoji": "book-open",
        "category": "words",
        "threshold": 50,
    },
    {
        "type": "words_100",
        "title": "단어 100개 학습",
        "description": "총 100개의 단어를 학습했어요",
        "emoji": "book-marked",
        "category": "words",
        "threshold": 100,
    },
    # 레벨
    {"type": "level_5", "title": "레벨 5 달성", "description": "레벨 5에 도달했어요", "emoji": "star", "category": "level", "threshold": 5},
    {
        "type": "level_10",
        "title": "레벨 10 달성",
        "description": "레벨 10에 도달했어요",
        "emoji": "moon",
        "category": "level",
        "threshold": 10,
    },
    {
        "type": "level_20",
        "title": "레벨 20 달성",
        "description": "레벨 20에 도달했어요",
        "emoji": "flower-2",
        "category": "level",
        "threshold": 20,
    },
    # XP
    {
        "type": "xp_1000",
        "title": "XP 1,000 달성",
        "description": "총 1,000 XP를 모았어요",
        "emoji": "gem",
        "category": "xp",
        "threshold": 1000,
    },
    {
        "type": "xp_5000",
        "title": "XP 5,000 달성",
        "description": "총 5,000 XP를 모았어요",
        "emoji": "medal",
        "category": "xp",
        "threshold": 5000,
    },
    {
        "type": "xp_10000",
        "title": "XP 10,000 달성",
        "description": "총 10,000 XP를 모았어요",
        "emoji": "award",
        "category": "xp",
        "threshold": 10000,
    },
    # 가나
    {"type": "kana_first_char", "title": "첫 글자!", "description": "첫 번째 가나를 배웠어요", "emoji": "sprout", "category": "kana"},
    {
        "type": "kana_hiragana_complete",
        "title": "ひらがな達人",
        "description": "히라가나를 전부 마스터했어요",
        "emoji": "trophy",
        "category": "kana",
    },
    {
        "type": "kana_katakana_complete",
        "title": "カタカナ達人",
        "description": "가타카나를 전부 마스터했어요",
        "emoji": "trophy",
        "category": "kana",
    },
]


def get_achievement(achievement_type: str) -> AchievementDef | None:
    for a in ACHIEVEMENTS:
        if a.get("type") == achievement_type:
            return a
    return None


class GameEvent(TypedDict):
    type: str  # 'level_up' | 'streak' | 'achievement' | 'xp'
    title: str
    body: str
    emoji: str


# ==========================================
# 캐릭터 해금 체크
# ==========================================


async def check_character_unlocks(
    db: AsyncSession,
    user_id: uuid.UUID,
    user_level: int,
) -> list[GameEvent]:
    """유저 레벨 기반 캐릭터 해금 체크."""
    result = await db.execute(
        select(AiCharacter).where(
            AiCharacter.unlock_condition.isnot(None),
            AiCharacter.is_active.is_(True),
        )
    )
    all_characters = result.scalars().all()

    result = await db.execute(select(UserCharacterUnlock.character_id).where(UserCharacterUnlock.user_id == user_id))
    unlocked_ids = {row for row in result.scalars().all()}

    events: list[GameEvent] = []

    for char in all_characters:
        if char.id in unlocked_ids:
            continue
        if char.unlock_condition is None:
            continue
        try:
            required_level = int(char.unlock_condition)
        except (ValueError, TypeError):
            continue
        if user_level < required_level:
            continue

        unlock = UserCharacterUnlock(user_id=user_id, character_id=char.id)
        db.add(unlock)
        await db.flush()

        events.append(
            {
                "type": "achievement",
                "title": "새 캐릭터 해금!",
                "body": f"{char.name}({char.name_ja})와 대화할 수 있게 되었어요!",
                "emoji": char.avatar_emoji,
            }
        )

    return events


async def check_and_grant_achievements(
    db: AsyncSession,
    user_id: uuid.UUID,
    context: dict[str, Any],
) -> list[GameEvent]:
    """사용자의 현재 상태를 기반으로 새 업적을 확인하고 부여.

    context keys:
        total_xp, new_level, old_level, streak_count,
        quiz_count, conversation_count, is_perfect_quiz,
        total_words_studied, kana_first_char, kana_hiragana_complete,
        kana_katakana_complete
    """
    events: list[GameEvent] = []

    # 기존 업적 조회
    result = await db.execute(select(UserAchievement.achievement_type).where(UserAchievement.user_id == user_id))
    existing_types = {row for row in result.scalars().all()}

    to_grant: list[str] = []

    # 레벨업 이벤트
    new_level = context.get("new_level", 1)
    old_level = context.get("old_level", 1)
    if new_level > old_level:
        events.append(
            {
                "type": "level_up",
                "title": "레벨 업!",
                "body": f"레벨 {new_level}에 도달했어요!",
                "emoji": "party-popper",
            }
        )

    # 카테고리별 컨텍스트 값 매핑
    context_map: dict[str, int | None] = {
        "level": new_level,
        "streak": context.get("streak_count"),
        "xp": context.get("total_xp"),
        "quiz": context.get("quiz_count"),
        "words": context.get("total_words_studied"),
        "conversation": context.get("conversation_count"),
    }

    for achievement in ACHIEVEMENTS:
        category = achievement.get("category")

        if category == "special":
            if achievement.get("type") == "perfect_quiz" and context.get("is_perfect_quiz"):
                to_grant.append(achievement["type"])
            continue

        if category == "kana":
            a_type = achievement.get("type")
            if isinstance(a_type, str) and (
                a_type == "kana_first_char"
                and context.get("kana_first_char")
                or a_type == "kana_hiragana_complete"
                and context.get("kana_hiragana_complete")
                or a_type == "kana_katakana_complete"
                and context.get("kana_katakana_complete")
            ):
                to_grant.append(a_type)
            continue

        value = context_map.get(category) if category is not None else None
        threshold = achievement.get("threshold")
        if value is not None and threshold is not None and value >= threshold:
            to_grant.append(achievement["type"])

    # 새 업적만 필터링하여 부여
    new_achievements = [t for t in to_grant if t not in existing_types]

    for achievement_type in new_achievements:
        definition = get_achievement(achievement_type)
        if not definition:
            continue

        user_achievement = UserAchievement(
            user_id=user_id,
            achievement_type=achievement_type,
        )
        db.add(user_achievement)
        await db.flush()

        events.append(
            {
                "type": "achievement",
                "title": definition["title"],
                "body": definition["description"],
                "emoji": definition["emoji"],
            }
        )

    # 캐릭터 해금 체크
    character_events = await check_character_unlocks(db, user_id, new_level)
    events.extend(character_events)

    return events
