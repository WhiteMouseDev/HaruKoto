"""Completion recovery rewards and genuine study-day recognition are independent.

Readers and actual activity writers stay compatible when the source gate is OFF.
Only creating a new non-credited completion day is gated; never erase a decision.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, datetime

from app.models import DailyProgress
from app.services.study_activity import has_study_activity
from app.utils.date import study_date_kst

STUDY_DAY_CREDIT_SEPARATION_ENABLED = True


@dataclass(frozen=True, slots=True)
class QuizCompletionStudyDay:
    credited: bool
    update_streak: bool


def resolve_quiz_completion_study_day(
    progress: DailyProgress | None,
    *,
    first_answer_times: Iterable[datetime],
    completed_at: datetime,
) -> QuizCompletionStudyDay:
    completion_time = completed_at.replace(tzinfo=UTC) if completed_at.utcoffset() is None else completed_at
    today = study_date_kst(completion_time)
    normalized_answers = (value.replace(tzinfo=UTC) if value.utcoffset() is None else value for value in first_answer_times)
    answered_today = any(value <= completion_time and study_date_kst(value) == today for value in normalized_answers)
    if answered_today:
        return QuizCompletionStudyDay(credited=True, update_streak=True)
    # Compatible rollback must honor a stored FALSE, even with positive rewards.
    if getattr(progress, "study_day_credited", None) is False:
        return QuizCompletionStudyDay(credited=False, update_streak=False)
    if not STUDY_DAY_CREDIT_SEPARATION_ENABLED:
        return QuizCompletionStudyDay(credited=True, update_streak=True)
    return QuizCompletionStudyDay(credited=has_study_activity(progress), update_streak=False)
