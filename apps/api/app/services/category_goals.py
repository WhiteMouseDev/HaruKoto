from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, time, timedelta
from typing import Any

from sqlalchemy import Text, and_, cast, func, or_, select
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizAnswer, QuizSession
from app.models.enums import QuizType
from app.models.gamification import DailyProgress
from app.models.user import User
from app.schemas.stats import CategoryGoalProgress, DailyCategoryGoals, GoalCategory
from app.services.study_activity import has_study_activity
from app.utils.constants import DAILY_CATEGORY_GOALS_KEY, MAX_DAILY_GOAL, MIN_DAILY_GOAL
from app.utils.date import KST

DEFAULT_CATEGORY_GOAL = 10
CATEGORY_QUIZ_TYPES: dict[GoalCategory, QuizType] = {
    "VOCABULARY": QuizType.VOCABULARY,
    "GRAMMAR": QuizType.GRAMMAR,
    "SENTENCE": QuizType.SENTENCE_ARRANGE,
}
GOAL_QUIZ_TYPES = tuple(CATEGORY_QUIZ_TYPES.values())
CATEGORIZED_CLOZE_TYPES = (QuizType.VOCABULARY, QuizType.GRAMMAR)
_SETTING_KEYS = {QuizType.GRAMMAR: "grammar", QuizType.SENTENCE_ARRANGE: "sentence"}


async def get_goal_answered_counts(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    day: date,
    quiz_type: QuizType | None = None,
) -> dict[QuizType, int]:
    """Count distinct saved answers within one KST day, grouped by goal type."""
    start = datetime.combine(day, time.min, tzinfo=KST).astimezone(UTC)
    end = start + timedelta(days=1)
    # Epoch extraction treats UTC-naive timestamps as nominal UTC and aware
    # timestamps as instants, independent of PostgreSQL's session timezone.
    answered_epoch = func.extract("epoch", QuizAnswer.answered_at)
    mode = QuizSession.questions_data["mode"].astext
    snapshot = cast(func.coalesce(QuizSession.questions_data["questions"], QuizSession.questions_data), JSONB)
    # Native cloze can belong to a word or grammar quiz. Verify the saved
    # question as well as the submitted type, including older bare arrays.
    cloze_question = func.jsonb_build_object(cast("id", Text), cast(QuizAnswer.question_id, Text), cast("type", Text), cast("CLOZE", Text))
    categorized_cloze = and_(
        QuizSession.quiz_type.in_(CATEGORIZED_CLOZE_TYPES),
        QuizAnswer.question_type == QuizType.CLOZE,
        snapshot.contains(func.jsonb_build_array(cloze_question)),
    )
    query = (
        select(QuizSession.quiz_type, func.count(QuizAnswer.question_id.distinct()))
        .join(QuizSession, QuizSession.id == QuizAnswer.session_id)
        .where(
            QuizSession.user_id == user_id,
            or_(QuizAnswer.question_type == QuizSession.quiz_type, categorized_cloze),
            answered_epoch >= start.timestamp(),
            answered_epoch < end.timestamp(),
        )
        .group_by(QuizSession.quiz_type)
    )
    if quiz_type is None:
        query = query.where(QuizSession.quiz_type.in_(GOAL_QUIZ_TYPES))
    else:
        query = query.where(QuizSession.quiz_type == quiz_type)
    if quiz_type in (None, QuizType.SENTENCE_ARRANGE):
        # An older sentence-arrange snapshot may have no mode. A known matching
        # mode can use the same enum and is not a sentence-arrangement question.
        query = query.where(or_(QuizSession.quiz_type != QuizType.SENTENCE_ARRANGE, mode.is_(None), mode == "arrange"))
    result = await db.execute(query)
    return {row[0]: int(row[1]) for row in result.all()}


def _private_settings(app_settings: dict[str, Any] | None) -> dict[str, Any]:
    value = (app_settings or {}).get(DAILY_CATEGORY_GOALS_KEY)
    return value if isinstance(value, dict) else {}


def goal_target(user: User, quiz_type: QuizType) -> int:
    if quiz_type == QuizType.VOCABULARY:
        # Older web/profile clients allow positive goals outside the mobile editor's range.
        word_goal = user.daily_goal
        return word_goal if type(word_goal) is int and word_goal > 0 else DEFAULT_CATEGORY_GOAL
    category_goal = _private_settings(user.app_settings).get(_SETTING_KEYS[quiz_type])
    if type(category_goal) is int and MIN_DAILY_GOAL <= category_goal <= MAX_DAILY_GOAL:
        return category_goal
    return DEFAULT_CATEGORY_GOAL


def set_goal_target(user: User, *, quiz_type: QuizType, target: int) -> None:
    if quiz_type == QuizType.VOCABULARY:
        user.daily_goal = target
        return
    user.app_settings = {
        **(user.app_settings or {}),
        DAILY_CATEGORY_GOALS_KEY: {**_private_settings(user.app_settings), _SETTING_KEYS[quiz_type]: target},
    }


def _earned_months(app_settings: dict[str, Any] | None) -> dict[str, Any]:
    months = _private_settings(app_settings).get("earnedByMonth")
    return months if isinstance(months, dict) else {}


def achievement_days(app_settings: dict[str, Any] | None, *, month: date) -> set[int]:
    values = _earned_months(app_settings).get(month.strftime("%Y-%m"))
    return {value for value in values if type(value) is int and 1 <= value <= 31} if isinstance(values, list) else set()


async def award_goal_if_reached(db: AsyncSession, user: User, *, day: date, quiz_type: QuizType) -> None:
    """Record at most one trophy per day. Caller holds the existing user write lock."""
    earned = achievement_days(user.app_settings, month=day)
    if day.day in earned:
        return
    counts = await get_goal_answered_counts(db, user_id=user.id, day=day, quiz_type=quiz_type)
    if counts.get(quiz_type, 0) >= goal_target(user, quiz_type):
        user.app_settings = {
            **(user.app_settings or {}),
            DAILY_CATEGORY_GOALS_KEY: {
                **_private_settings(user.app_settings),
                "earnedByMonth": {
                    **_earned_months(user.app_settings),
                    day.strftime("%Y-%m"): sorted(earned | {day.day}),
                },
            },
        }


async def award_goal_after_target_change(db: AsyncSession, user: User, *, day: date, quiz_type: QuizType) -> None:
    progress = await db.scalar(select(DailyProgress).where(DailyProgress.user_id == user.id, DailyProgress.date == day))
    if has_study_activity(progress):
        await award_goal_if_reached(db, user, day=day, quiz_type=quiz_type)


async def get_daily_category_goals(db: AsyncSession, user: User, *, day: date) -> DailyCategoryGoals:
    counts = await get_goal_answered_counts(db, user_id=user.id, day=day)

    def progress(quiz_type: QuizType) -> CategoryGoalProgress:
        return CategoryGoalProgress(target=goal_target(user, quiz_type), answered_count=counts.get(quiz_type, 0))

    return DailyCategoryGoals(
        date=day,
        vocabulary=progress(QuizType.VOCABULARY),
        grammar=progress(QuizType.GRAMMAR),
        sentence=progress(QuizType.SENTENCE_ARRANGE),
    )
