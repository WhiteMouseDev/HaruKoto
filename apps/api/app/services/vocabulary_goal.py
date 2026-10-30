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
    """Count distinct saved vocabulary answers for one KST learning day."""
    start = datetime.combine(day, time.min, tzinfo=KST).astimezone(UTC)
    end = start + timedelta(days=1)
    # PostgreSQL epoch extraction treats legacy UTC-naive timestamps as nominal
    # UTC and aware timestamps as instants, independent of the session timezone.
    # Keep the session join/user filter so existing user/session indexes apply.
    answered_epoch = func.extract("epoch", QuizAnswer.answered_at)
    result = await db.execute(
        select(func.count(QuizAnswer.question_id.distinct()))
        .join(QuizSession, QuizSession.id == QuizAnswer.session_id)
        .where(
            QuizSession.user_id == user_id,
            QuizSession.quiz_type == QuizType.VOCABULARY,
            QuizAnswer.question_type == QuizType.VOCABULARY,
            answered_epoch >= start.timestamp(),
            answered_epoch < end.timestamp(),
        )
    )
    return VocabularyGoal(date=day, answered_count=result.scalar() or 0)
