from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizSession
from app.models.user import User
from app.schemas.kana import KanaQuizCompleteRequest
from app.services.gamification import LevelInfo, calculate_level, check_and_grant_achievements, update_streak
from app.services.kana_daily_progress import apply_daily_progress_increment
from app.utils.constants import KANA_REWARDS
from app.utils.date import get_today_kst


class KanaQuizCompleteServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class KanaQuizCompleteResult:
    accuracy: int
    xp_earned: int
    level: int
    current_xp: int
    xp_for_next: int
    events: list[dict[str, Any]]


async def complete_kana_quiz_session(
    db: AsyncSession,
    user: User,
    body: KanaQuizCompleteRequest,
) -> KanaQuizCompleteResult:
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise KanaQuizCompleteServiceError(status_code=404, detail="세션을 찾을 수 없습니다")

    correct_count = session.correct_count or 0
    accuracy = calculate_kana_quiz_accuracy(correct_count=correct_count, total_questions=session.total_questions or 0)
    xp_earned = resolve_kana_quiz_xp(accuracy)
    old_level = user.level
    user.experience_points += xp_earned
    level_info = calculate_level(user.experience_points)
    user.level = level_info["level"]

    now = datetime.now(UTC)
    today = get_today_kst()
    streak_info = update_streak(user.last_study_date, user.streak_count, user.longest_streak, today)
    user.streak_count = streak_info["streak_count"]
    user.longest_streak = streak_info["longest_streak"]
    user.last_study_date = now

    await apply_daily_progress_increment(
        db,
        user_id=user.id,
        today=today,
        xp_earned=xp_earned,
        kana_learned=correct_count,
    )
    events = await grant_kana_quiz_achievements(db, user=user, old_level=old_level)
    session.completed_at = now
    await db.commit()

    return build_kana_quiz_complete_result(
        accuracy=accuracy,
        xp_earned=xp_earned,
        level_info=level_info,
        events=events,
    )


def calculate_kana_quiz_accuracy(*, correct_count: int, total_questions: int) -> int:
    return round(correct_count / total_questions * 100) if total_questions > 0 else 0


def resolve_kana_quiz_xp(accuracy: int) -> int:
    return KANA_REWARDS.QUIZ_PERFECT_XP if accuracy == 100 else KANA_REWARDS.QUIZ_PASS_XP


async def grant_kana_quiz_achievements(
    db: AsyncSession,
    *,
    user: User,
    old_level: int,
) -> list[dict[str, Any]]:
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
    return [dict(event) for event in events]


def build_kana_quiz_complete_result(
    *,
    accuracy: int,
    xp_earned: int,
    level_info: LevelInfo,
    events: list[dict[str, Any]],
) -> KanaQuizCompleteResult:
    return KanaQuizCompleteResult(
        accuracy=accuracy,
        xp_earned=xp_earned,
        level=level_info["level"],
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
        events=events,
    )
