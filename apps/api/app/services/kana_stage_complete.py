from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import KanaCharacter, KanaLearningStage, UserKanaProgress, UserKanaStage
from app.models.enums import KanaType
from app.models.user import User
from app.schemas.kana import KanaStageCompleteRequest
from app.services.gamification import LevelInfo, calculate_level, check_and_grant_achievements, update_streak
from app.services.kana_daily_progress import apply_daily_progress_increment
from app.utils.constants import KANA_REWARDS
from app.utils.date import get_today_kst


class KanaStageCompleteServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class KanaCompletionStatus:
    hiragana_total: int
    hiragana_mastered: int
    katakana_total: int
    katakana_mastered: int

    @property
    def hiragana_complete(self) -> bool:
        return is_kana_type_complete(mastered_count=self.hiragana_mastered, total_count=self.hiragana_total)

    @property
    def katakana_complete(self) -> bool:
        return is_kana_type_complete(mastered_count=self.katakana_mastered, total_count=self.katakana_total)

    @property
    def all_complete(self) -> bool:
        return self.hiragana_complete and self.katakana_complete


@dataclass(slots=True)
class KanaStageCompleteResult:
    success: bool
    xp_earned: int
    level: int
    current_xp: int
    xp_for_next: int
    events: list[dict[str, Any]]
    next_stage_unlocked: bool


async def complete_kana_stage(
    db: AsyncSession,
    user: User,
    body: KanaStageCompleteRequest,
) -> KanaStageCompleteResult:
    stage = await db.get(KanaLearningStage, body.stage_id)
    if not stage:
        raise KanaStageCompleteServiceError(status_code=404, detail="스테이지를 찾을 수 없습니다")

    now = datetime.now(UTC)
    await mark_kana_stage_complete(
        db,
        user_id=user.id,
        stage_id=stage.id,
        quiz_score=body.quiz_score,
        completed_at=now,
    )
    next_stage_unlocked = await unlock_next_kana_stage(db, user_id=user.id, stage=stage)

    xp_earned = KANA_REWARDS.STAGE_COMPLETE_XP
    old_level = user.level
    user.experience_points += xp_earned
    level_info = calculate_level(user.experience_points)
    user.level = level_info["level"]

    today = get_today_kst()
    streak_info = update_streak(user.last_study_date, user.streak_count, user.longest_streak, today)
    user.streak_count = streak_info["streak_count"]
    user.longest_streak = streak_info["longest_streak"]
    user.last_study_date = now

    await apply_daily_progress_increment(db, user_id=user.id, today=today, xp_earned=xp_earned)

    completion_status = await get_kana_completion_status(db, user_id=user.id)
    events = await grant_kana_stage_achievements(
        db,
        user=user,
        old_level=old_level,
        completion_status=completion_status,
    )

    if completion_status.all_complete:
        user.show_kana = False

    await db.commit()

    return build_kana_stage_complete_result(
        xp_earned=xp_earned,
        level_info=level_info,
        events=events,
        next_stage_unlocked=next_stage_unlocked,
    )


async def mark_kana_stage_complete(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    stage_id: uuid.UUID,
    quiz_score: int | None,
    completed_at: datetime,
) -> None:
    stmt = pg_insert(UserKanaStage).values(
        user_id=user_id,
        stage_id=stage_id,
        is_unlocked=True,
        is_completed=True,
        quiz_score=quiz_score,
        completed_at=completed_at,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "stage_id"],
        set_={"is_completed": True, "quiz_score": quiz_score, "completed_at": completed_at},
    )
    await db.execute(stmt)


async def unlock_next_kana_stage(db: AsyncSession, *, user_id: uuid.UUID, stage: KanaLearningStage) -> bool:
    next_stage_result = await db.execute(
        select(KanaLearningStage).where(
            KanaLearningStage.kana_type == stage.kana_type,
            KanaLearningStage.stage_number == stage.stage_number + 1,
        )
    )
    next_stage = next_stage_result.scalar_one_or_none()
    if not next_stage:
        return False

    unlock_stmt = pg_insert(UserKanaStage).values(
        user_id=user_id,
        stage_id=next_stage.id,
        is_unlocked=True,
    )
    unlock_stmt = unlock_stmt.on_conflict_do_update(
        index_elements=["user_id", "stage_id"],
        set_={"is_unlocked": True},
    )
    await db.execute(unlock_stmt)
    return True


async def get_kana_completion_status(db: AsyncSession, *, user_id: uuid.UUID) -> KanaCompletionStatus:
    kana_total_result = await db.execute(select(KanaCharacter.kana_type, func.count(KanaCharacter.id)).group_by(KanaCharacter.kana_type))
    kana_totals = {row[0]: row[1] for row in kana_total_result.all()}

    kana_mastered_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter, KanaCharacter.id == UserKanaProgress.kana_id)
        .where(UserKanaProgress.user_id == user_id, UserKanaProgress.mastered.is_(True))
        .group_by(KanaCharacter.kana_type)
    )
    kana_mastered_counts = {row[0]: row[1] for row in kana_mastered_result.all()}

    return KanaCompletionStatus(
        hiragana_total=kana_totals.get(KanaType.HIRAGANA, 0),
        hiragana_mastered=kana_mastered_counts.get(KanaType.HIRAGANA, 0),
        katakana_total=kana_totals.get(KanaType.KATAKANA, 0),
        katakana_mastered=kana_mastered_counts.get(KanaType.KATAKANA, 0),
    )


async def grant_kana_stage_achievements(
    db: AsyncSession,
    *,
    user: User,
    old_level: int,
    completion_status: KanaCompletionStatus,
) -> list[dict[str, Any]]:
    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": user.level,
            "old_level": old_level,
            "streak_count": user.streak_count,
            "kana_first_char": True,
            "kana_hiragana_complete": completion_status.hiragana_complete,
            "kana_katakana_complete": completion_status.katakana_complete,
        },
    )
    return [dict(event) for event in events]


def is_kana_type_complete(*, mastered_count: int, total_count: int) -> bool:
    return mastered_count >= total_count and total_count > 0


def build_kana_stage_complete_result(
    *,
    xp_earned: int,
    level_info: LevelInfo,
    events: list[dict[str, Any]],
    next_stage_unlocked: bool,
) -> KanaStageCompleteResult:
    return KanaStageCompleteResult(
        success=True,
        xp_earned=xp_earned,
        level=level_info["level"],
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
        events=events,
        next_stage_unlocked=next_stage_unlocked,
    )
