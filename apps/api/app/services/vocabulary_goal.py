from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizAnswer, QuizSession
from app.models.enums import QuizType
from app.schemas.stats import VocabularyGoal
from app.utils.date import KST


async def get_vocabulary_goal(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    day: date,
) -> VocabularyGoal:
    counts = await get_vocabulary_answered_counts(db, user_id=user_id, start_day=day, end_day=day)
    return VocabularyGoal(date=day, answered_count=counts.get(day, 0))


async def get_vocabulary_answered_counts(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    start_day: date,
    end_day: date,
) -> dict[date, int]:
    """One bounded query for daily unique saved words; never record attendance.

    The nominal epoch convention exactly matches get_vocabulary_goal for both
    legacy UTC-naive TIMESTAMP and aware timestamps. Numeric day buckets avoid
    session-timezone casts and to_timestamp floating-point boundary rounding.
    """
    if not 0 <= (end_day - start_day).days < 7:
        raise ValueError("Vocabulary history must contain between one and seven days")
    start = datetime.combine(start_day, time.min, tzinfo=KST).astimezone(UTC)
    end = datetime.combine(end_day + timedelta(days=1), time.min, tzinfo=KST).astimezone(UTC)
    answered_epoch = func.extract("epoch", QuizAnswer.answered_at)
    day_bucket = func.floor((answered_epoch + 9 * 60 * 60) / (24 * 60 * 60)).label("day_bucket")
    result = await db.execute(
        select(day_bucket, func.count(QuizAnswer.question_id.distinct()))
        .join(QuizSession, QuizSession.id == QuizAnswer.session_id)
        .where(
            QuizSession.user_id == user_id,
            QuizSession.quiz_type == QuizType.VOCABULARY,
            QuizAnswer.question_type == QuizType.VOCABULARY,
            answered_epoch >= start.timestamp(),
            answered_epoch < end.timestamp(),
        )
        .group_by(day_bucket)
    )
    epoch_day = date(1970, 1, 1)
    return {epoch_day + timedelta(days=int(row[0])): int(row[1]) for row in result.all()}
