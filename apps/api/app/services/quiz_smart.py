from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, QuizAnswer, QuizSession, UserGrammarProgress, UserVocabProgress, Vocabulary
from app.models.user import User
from app.services.quiz_policy import calculate_smart_distribution
from app.utils.constants import SMART_QUIZ, SRS_CONFIG
from app.utils.date import get_today_kst


@dataclass(slots=True)
class SmartPoolStats:
    total: int
    studied: int
    mastered: int
    new_ready: int
    review_due: int
    retry_due: int


@dataclass(slots=True)
class SmartPreviewData:
    pool_stats: SmartPoolStats
    distribution: dict[str, int]
    daily_goal: int
    today_completed: int


async def load_smart_pool_stats(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    category: str,
    jlpt_level: str,
    now: datetime | None = None,
) -> SmartPoolStats:
    current_time = now or datetime.now(UTC)

    if category == "VOCABULARY":
        studied_ids_result = await db.execute(select(UserVocabProgress.vocabulary_id).where(UserVocabProgress.user_id == user_id))
        studied_ids = set(studied_ids_result.scalars().all())

        total_result = await db.execute(select(func.count(Vocabulary.id)).where(Vocabulary.jlpt_level == jlpt_level))
        total = total_result.scalar() or 0

        review_result = await db.execute(
            select(func.count(UserVocabProgress.id))
            .join(Vocabulary, Vocabulary.id == UserVocabProgress.vocabulary_id)
            .where(
                UserVocabProgress.user_id == user_id,
                Vocabulary.jlpt_level == jlpt_level,
                UserVocabProgress.next_review_at <= current_time,
                UserVocabProgress.interval > 0,
            )
        )
        review_due = review_result.scalar() or 0

        retry_result = await db.execute(
            select(func.count(UserVocabProgress.id))
            .join(Vocabulary, Vocabulary.id == UserVocabProgress.vocabulary_id)
            .where(
                UserVocabProgress.user_id == user_id,
                Vocabulary.jlpt_level == jlpt_level,
                UserVocabProgress.interval == 0,
                UserVocabProgress.incorrect_count > 0,
                UserVocabProgress.last_reviewed_at <= current_time - timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES),
            )
        )
        retry_due = retry_result.scalar() or 0

        studied_result = await db.execute(
            select(func.count(UserVocabProgress.id))
            .join(Vocabulary, Vocabulary.id == UserVocabProgress.vocabulary_id)
            .where(UserVocabProgress.user_id == user_id, Vocabulary.jlpt_level == jlpt_level)
        )
        studied = studied_result.scalar() or 0

        mastered_result = await db.execute(
            select(func.count(UserVocabProgress.id))
            .join(Vocabulary, Vocabulary.id == UserVocabProgress.vocabulary_id)
            .where(
                UserVocabProgress.user_id == user_id,
                Vocabulary.jlpt_level == jlpt_level,
                UserVocabProgress.mastered.is_(True),
            )
        )
        mastered = mastered_result.scalar() or 0
        new_ready = max(0, total - len(studied_ids))
    else:
        studied_ids_result = await db.execute(select(UserGrammarProgress.grammar_id).where(UserGrammarProgress.user_id == user_id))
        studied_ids = set(studied_ids_result.scalars().all())

        total_result = await db.execute(select(func.count(Grammar.id)).where(Grammar.jlpt_level == jlpt_level))
        total = total_result.scalar() or 0

        review_result = await db.execute(
            select(func.count(UserGrammarProgress.id))
            .join(Grammar, Grammar.id == UserGrammarProgress.grammar_id)
            .where(
                UserGrammarProgress.user_id == user_id,
                Grammar.jlpt_level == jlpt_level,
                UserGrammarProgress.next_review_at <= current_time,
                UserGrammarProgress.interval > 0,
            )
        )
        review_due = review_result.scalar() or 0

        retry_result = await db.execute(
            select(func.count(UserGrammarProgress.id))
            .join(Grammar, Grammar.id == UserGrammarProgress.grammar_id)
            .where(
                UserGrammarProgress.user_id == user_id,
                Grammar.jlpt_level == jlpt_level,
                UserGrammarProgress.interval == 0,
                UserGrammarProgress.incorrect_count > 0,
                UserGrammarProgress.last_reviewed_at <= current_time - timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES),
            )
        )
        retry_due = retry_result.scalar() or 0

        studied_result = await db.execute(
            select(func.count(UserGrammarProgress.id))
            .join(Grammar, Grammar.id == UserGrammarProgress.grammar_id)
            .where(UserGrammarProgress.user_id == user_id, Grammar.jlpt_level == jlpt_level)
        )
        studied = studied_result.scalar() or 0

        mastered_result = await db.execute(
            select(func.count(UserGrammarProgress.id))
            .join(Grammar, Grammar.id == UserGrammarProgress.grammar_id)
            .where(
                UserGrammarProgress.user_id == user_id,
                Grammar.jlpt_level == jlpt_level,
                UserGrammarProgress.mastered.is_(True),
            )
        )
        mastered = mastered_result.scalar() or 0
        new_ready = max(0, total - len(studied_ids))

    return SmartPoolStats(
        total=total,
        studied=studied,
        mastered=mastered,
        new_ready=new_ready,
        review_due=review_due,
        retry_due=retry_due,
    )


async def load_today_completed_count(db: AsyncSession, *, user_id: uuid.UUID) -> int:
    today = get_today_kst()
    today_result = await db.execute(
        select(func.count(QuizAnswer.id))
        .join(QuizSession, QuizSession.id == QuizAnswer.session_id)
        .where(
            QuizSession.user_id == user_id,
            QuizAnswer.answered_at >= today,
        )
    )
    return today_result.scalar() or 0


async def build_smart_preview_data(
    db: AsyncSession,
    user: User,
    *,
    category: str,
    jlpt_level: str,
) -> SmartPreviewData:
    pool_stats = await load_smart_pool_stats(
        db,
        user_id=user.id,
        category=category,
        jlpt_level=jlpt_level,
    )
    today_completed = await load_today_completed_count(db, user_id=user.id)

    raw_goal = getattr(user, "daily_goal", None) or SMART_QUIZ.DAILY_GOAL
    daily_goal = max(1, raw_goal)
    remaining = max(1, daily_goal - today_completed)
    distribution = calculate_smart_distribution(remaining, pool_stats.review_due, pool_stats.retry_due)

    return SmartPreviewData(
        pool_stats=pool_stats,
        distribution=distribution,
        daily_goal=daily_goal,
        today_completed=today_completed,
    )
