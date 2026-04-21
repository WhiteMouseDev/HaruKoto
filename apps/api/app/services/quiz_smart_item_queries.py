from __future__ import annotations

import uuid
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, UserGrammarProgress, UserVocabProgress, Vocabulary
from app.utils.constants import SRS_CONFIG


async def load_vocab_review_items(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    jlpt_level: str,
    count: int,
    now: datetime,
) -> list[Vocabulary]:
    if count <= 0:
        return []
    result = await db.execute(
        select(Vocabulary)
        .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(
            UserVocabProgress.user_id == user_id,
            Vocabulary.jlpt_level == jlpt_level,
            UserVocabProgress.next_review_at <= now,
            UserVocabProgress.interval > 0,
        )
        .order_by(UserVocabProgress.next_review_at)
        .limit(count)
    )
    return list(result.scalars().all())


async def load_vocab_retry_items(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    jlpt_level: str,
    count: int,
    now: datetime,
) -> list[Vocabulary]:
    if count <= 0:
        return []
    result = await db.execute(
        select(Vocabulary)
        .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(
            UserVocabProgress.user_id == user_id,
            Vocabulary.jlpt_level == jlpt_level,
            UserVocabProgress.interval == 0,
            UserVocabProgress.incorrect_count > 0,
            UserVocabProgress.last_reviewed_at <= now - timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES),
        )
        .order_by(UserVocabProgress.last_reviewed_at)
        .limit(count)
    )
    return list(result.scalars().all())


async def load_vocab_studied_ids(db: AsyncSession, *, user_id: uuid.UUID) -> set[uuid.UUID]:
    result = await db.execute(select(UserVocabProgress.vocabulary_id).where(UserVocabProgress.user_id == user_id))
    return set(result.scalars().all())


async def load_new_vocab_items(
    db: AsyncSession,
    *,
    jlpt_level: str,
    count: int,
    exclude_ids: set[uuid.UUID],
) -> list[Vocabulary]:
    if count <= 0:
        return []
    query = select(Vocabulary).where(Vocabulary.jlpt_level == jlpt_level)
    if exclude_ids:
        query = query.where(Vocabulary.id.notin_(exclude_ids))
    result = await db.execute(query.order_by(Vocabulary.id).limit(count))
    return list(result.scalars().all())


async def load_vocab_meanings(db: AsyncSession, jlpt_level: str) -> list[str]:
    result = await db.execute(select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50))
    return list(result.scalars().all())


async def load_grammar_review_items(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    jlpt_level: str,
    count: int,
    now: datetime,
) -> list[Grammar]:
    if count <= 0:
        return []
    result = await db.execute(
        select(Grammar)
        .join(UserGrammarProgress, UserGrammarProgress.grammar_id == Grammar.id)
        .where(
            UserGrammarProgress.user_id == user_id,
            Grammar.jlpt_level == jlpt_level,
            UserGrammarProgress.next_review_at <= now,
            UserGrammarProgress.interval > 0,
        )
        .order_by(UserGrammarProgress.next_review_at)
        .limit(count)
    )
    return list(result.scalars().all())


async def load_grammar_retry_items(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    jlpt_level: str,
    count: int,
    now: datetime,
) -> list[Grammar]:
    if count <= 0:
        return []
    result = await db.execute(
        select(Grammar)
        .join(UserGrammarProgress, UserGrammarProgress.grammar_id == Grammar.id)
        .where(
            UserGrammarProgress.user_id == user_id,
            Grammar.jlpt_level == jlpt_level,
            UserGrammarProgress.interval == 0,
            UserGrammarProgress.incorrect_count > 0,
            UserGrammarProgress.last_reviewed_at <= now - timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES),
        )
        .order_by(UserGrammarProgress.last_reviewed_at)
        .limit(count)
    )
    return list(result.scalars().all())


async def load_grammar_studied_ids(db: AsyncSession, *, user_id: uuid.UUID) -> set[uuid.UUID]:
    result = await db.execute(select(UserGrammarProgress.grammar_id).where(UserGrammarProgress.user_id == user_id))
    return set(result.scalars().all())


async def load_new_grammar_items(
    db: AsyncSession,
    *,
    jlpt_level: str,
    count: int,
    exclude_ids: set[uuid.UUID],
) -> list[Grammar]:
    if count <= 0:
        return []
    query = select(Grammar).where(Grammar.jlpt_level == jlpt_level)
    if exclude_ids:
        query = query.where(Grammar.id.notin_(exclude_ids))
    result = await db.execute(query.order_by(Grammar.id).limit(count))
    return list(result.scalars().all())


async def load_grammar_meanings(db: AsyncSession, jlpt_level: str) -> list[str]:
    result = await db.execute(select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50))
    return list(result.scalars().all())
