from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Grammar, Vocabulary
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.models.user import User


@dataclass(slots=True)
class ReviewSummaryData:
    word_due: int
    grammar_due: int
    total_due: int
    word_new: int
    grammar_new: int


def _effective_level(jlpt_level: str) -> str:
    return "N5" if jlpt_level == "ABSOLUTE_ZERO" else jlpt_level


async def get_review_summary_data(
    db: AsyncSession,
    user: User,
    *,
    jlpt_level: str,
) -> ReviewSummaryData:
    effective_level = _effective_level(jlpt_level)
    now = datetime.now(UTC)
    due_states = ("RELEARNING", "LEARNING", "REVIEW", "PROVISIONAL")

    word_due = (
        await db.execute(
            select(func.count())
            .select_from(UserVocabProgress)
            .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
            .where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.state.in_(due_states),
                UserVocabProgress.next_review_at <= now,
                Vocabulary.jlpt_level == effective_level,
            )
        )
    ).scalar() or 0

    grammar_due = (
        await db.execute(
            select(func.count())
            .select_from(UserGrammarProgress)
            .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
            .where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.state.in_(due_states),
                UserGrammarProgress.next_review_at <= now,
                Grammar.jlpt_level == effective_level,
            )
        )
    ).scalar() or 0

    word_unseen = (
        await db.execute(
            select(func.count())
            .select_from(UserVocabProgress)
            .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
            .where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.state == "UNSEEN",
                Vocabulary.jlpt_level == effective_level,
            )
        )
    ).scalar() or 0

    existing_vocab_ids = select(UserVocabProgress.vocabulary_id).where(UserVocabProgress.user_id == user.id).scalar_subquery()
    word_no_record = (
        await db.execute(
            select(func.count())
            .select_from(Vocabulary)
            .where(
                Vocabulary.jlpt_level == effective_level,
                Vocabulary.id.notin_(existing_vocab_ids),
            )
        )
    ).scalar() or 0

    grammar_unseen = (
        await db.execute(
            select(func.count())
            .select_from(UserGrammarProgress)
            .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
            .where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.state == "UNSEEN",
                Grammar.jlpt_level == effective_level,
            )
        )
    ).scalar() or 0

    existing_grammar_ids = select(UserGrammarProgress.grammar_id).where(UserGrammarProgress.user_id == user.id).scalar_subquery()
    grammar_no_record = (
        await db.execute(
            select(func.count())
            .select_from(Grammar)
            .where(
                Grammar.jlpt_level == effective_level,
                Grammar.id.notin_(existing_grammar_ids),
            )
        )
    ).scalar() or 0

    return ReviewSummaryData(
        word_due=word_due,
        grammar_due=grammar_due,
        total_due=word_due + grammar_due,
        word_new=word_unseen + word_no_record,
        grammar_new=grammar_unseen + grammar_no_record,
    )
