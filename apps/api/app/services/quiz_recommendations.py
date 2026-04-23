from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, UserGrammarProgress, UserVocabProgress, Vocabulary
from app.models.user import User


@dataclass(slots=True)
class RecommendationsResult:
    review_due_count: int
    new_words_count: int
    wrong_count: int
    last_reviewed_at: str | None


type RecommendationProgressModel = type[UserVocabProgress] | type[UserGrammarProgress]
type RecommendationContentModel = type[Vocabulary] | type[Grammar]


@dataclass(frozen=True, slots=True)
class RecommendationQueryScope:
    progress_model: RecommendationProgressModel
    content_model: RecommendationContentModel


VOCABULARY_RECOMMENDATION_SCOPE = RecommendationQueryScope(
    progress_model=UserVocabProgress,
    content_model=Vocabulary,
)
GRAMMAR_RECOMMENDATION_SCOPE = RecommendationQueryScope(
    progress_model=UserGrammarProgress,
    content_model=Grammar,
)


async def get_recommendations_data(
    db: AsyncSession,
    user: User,
    *,
    category: str | None,
) -> RecommendationsResult:
    now = datetime.now(UTC)

    if category == "VOCABULARY":
        return await _get_category_recommendations(
            db,
            user,
            scope=VOCABULARY_RECOMMENDATION_SCOPE,
            now=now,
        )

    if category == "GRAMMAR":
        return await _get_category_recommendations(
            db,
            user,
            scope=GRAMMAR_RECOMMENDATION_SCOPE,
            now=now,
        )

    if category == "SENTENCE":
        return RecommendationsResult(
            review_due_count=0,
            new_words_count=0,
            wrong_count=0,
            last_reviewed_at=None,
        )

    due_vocab_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.next_review_at <= now,
        )
    )
    due_grammar_result = await db.execute(
        select(func.count(UserGrammarProgress.id)).where(
            UserGrammarProgress.user_id == user.id,
            UserGrammarProgress.next_review_at <= now,
        )
    )
    vocab_due = due_vocab_result.scalar() or 0
    grammar_due = due_grammar_result.scalar() or 0

    studied_count_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
        )
    )
    studied_count = studied_count_result.scalar() or 0
    total_vocab_result = await db.execute(select(func.count(Vocabulary.id)))
    total_vocab = total_vocab_result.scalar() or 0
    new_words_count = max(0, total_vocab - studied_count)

    wrong_count_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.incorrect_count > 0,
        )
    )
    wrong_count = wrong_count_result.scalar() or 0

    last_reviewed_result = await db.execute(
        select(func.max(UserVocabProgress.last_reviewed_at)).where(
            UserVocabProgress.user_id == user.id,
        )
    )
    last_reviewed = last_reviewed_result.scalar()

    return RecommendationsResult(
        review_due_count=vocab_due + grammar_due,
        new_words_count=new_words_count,
        wrong_count=wrong_count,
        last_reviewed_at=last_reviewed.isoformat() if last_reviewed else None,
    )


async def _get_category_recommendations(
    db: AsyncSession,
    user: User,
    *,
    scope: RecommendationQueryScope,
    now: datetime,
) -> RecommendationsResult:
    progress_model = scope.progress_model
    content_model = scope.content_model

    due_result = await db.execute(
        select(func.count(progress_model.id)).where(
            progress_model.user_id == user.id,
            progress_model.next_review_at <= now,
        )
    )
    review_due = due_result.scalar() or 0

    studied_count_result = await db.execute(
        select(func.count(progress_model.id)).where(
            progress_model.user_id == user.id,
        )
    )
    studied_count = studied_count_result.scalar() or 0

    total_result = await db.execute(select(func.count(content_model.id)))
    total = total_result.scalar() or 0
    new_count = max(0, total - studied_count)

    wrong_result = await db.execute(
        select(func.count(progress_model.id)).where(
            progress_model.user_id == user.id,
            progress_model.incorrect_count > 0,
        )
    )
    wrong_count = wrong_result.scalar() or 0

    last_reviewed_result = await db.execute(
        select(func.max(progress_model.last_reviewed_at)).where(
            progress_model.user_id == user.id,
        )
    )
    last_reviewed = last_reviewed_result.scalar()

    return RecommendationsResult(
        review_due_count=review_due,
        new_words_count=new_count,
        wrong_count=wrong_count,
        last_reviewed_at=last_reviewed.isoformat() if last_reviewed else None,
    )
