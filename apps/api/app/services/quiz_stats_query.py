from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, QuizSession, UserGrammarProgress, UserVocabProgress, Vocabulary
from app.models.user import User

VOCABULARY_STATS_TYPES = {"VOCABULARY", "KANJI", "LISTENING"}


@dataclass(slots=True)
class QuizStatsResult:
    total_quizzes: int
    total_correct: int
    total_questions: int
    accuracy: float


@dataclass(slots=True)
class ContentQuizStatsResult:
    total_count: int
    studied_count: int
    progress: int


async def get_quiz_stats_data(
    db: AsyncSession,
    user: User,
    *,
    level: str | None,
    quiz_type: str | None,
) -> ContentQuizStatsResult | QuizStatsResult:
    if level and quiz_type:
        if quiz_type in VOCABULARY_STATS_TYPES:
            return await _get_vocabulary_content_stats(db, user, level=level)
        return await _get_grammar_content_stats(db, user, level=level)

    return await _get_overall_quiz_stats(db, user)


async def _get_vocabulary_content_stats(
    db: AsyncSession,
    user: User,
    *,
    level: str,
) -> ContentQuizStatsResult:
    total_result = await db.execute(select(func.count(Vocabulary.id)).where(Vocabulary.jlpt_level == level))
    total_count = total_result.scalar() or 0

    studied_result = await db.execute(
        select(func.count(UserVocabProgress.id))
        .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(
            UserVocabProgress.user_id == user.id,
            Vocabulary.jlpt_level == level,
        )
    )
    studied_count = studied_result.scalar() or 0

    return _build_content_stats(total_count=total_count, studied_count=studied_count)


async def _get_grammar_content_stats(
    db: AsyncSession,
    user: User,
    *,
    level: str,
) -> ContentQuizStatsResult:
    total_result = await db.execute(select(func.count(Grammar.id)).where(Grammar.jlpt_level == level))
    total_count = total_result.scalar() or 0

    studied_result = await db.execute(
        select(func.count(UserGrammarProgress.id))
        .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
        .where(
            UserGrammarProgress.user_id == user.id,
            Grammar.jlpt_level == level,
        )
    )
    studied_count = studied_result.scalar() or 0

    return _build_content_stats(total_count=total_count, studied_count=studied_count)


async def _get_overall_quiz_stats(
    db: AsyncSession,
    user: User,
) -> QuizStatsResult:
    total_result = await db.execute(
        select(func.count(QuizSession.id)).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.isnot(None),
        )
    )
    totals_result = await db.execute(
        select(
            func.sum(QuizSession.correct_count),
            func.sum(QuizSession.total_questions),
        ).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.isnot(None),
        )
    )
    row = totals_result.one()
    total_correct = row[0] or 0
    total_questions = row[1] or 0

    return QuizStatsResult(
        total_quizzes=total_result.scalar() or 0,
        total_correct=total_correct,
        total_questions=total_questions,
        accuracy=(total_correct / total_questions * 100) if total_questions > 0 else 0,
    )


def _build_content_stats(
    *,
    total_count: int,
    studied_count: int,
) -> ContentQuizStatsResult:
    return ContentQuizStatsResult(
        total_count=total_count,
        studied_count=studied_count,
        progress=round(studied_count / total_count * 100) if total_count > 0 else 0,
    )
