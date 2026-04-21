from __future__ import annotations

import random
import uuid
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, UserGrammarProgress, UserVocabProgress, Vocabulary
from app.services.distractor import generate_distractors
from app.services.quiz_question_builder import QuestionPayload
from app.services.quiz_smart_item_selection import build_exclude_ids, calculate_new_count_needed, dedupe_by_meaning, merge_smart_items
from app.services.quiz_smart_question_payloads import build_smart_grammar_questions, build_smart_vocab_question
from app.utils.constants import SRS_CONFIG


async def load_smart_questions(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    category: str,
    jlpt_level: str,
    distribution: dict[str, int],
    now: datetime,
) -> list[QuestionPayload]:
    if category == "VOCABULARY":
        questions = await _load_smart_vocab_questions(
            db,
            user_id=user_id,
            jlpt_level=jlpt_level,
            distribution=distribution,
            now=now,
        )
    else:
        questions = await _load_smart_grammar_questions(
            db,
            user_id=user_id,
            jlpt_level=jlpt_level,
            distribution=distribution,
            now=now,
        )

    random.shuffle(questions)
    return questions


async def _load_smart_vocab_questions(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    jlpt_level: str,
    distribution: dict[str, int],
    now: datetime,
) -> list[QuestionPayload]:
    review_items = await _load_vocab_review_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["review"], now=now)
    retry_items = await _load_vocab_retry_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["retry"], now=now)

    studied_ids_result = await db.execute(select(UserVocabProgress.vocabulary_id).where(UserVocabProgress.user_id == user_id))
    studied_ids = set(studied_ids_result.scalars().all())
    exclude_ids = build_exclude_ids(studied_ids, review_items, retry_items)

    new_count_needed = calculate_new_count_needed(distribution, review_count=len(review_items), retry_count=len(retry_items))
    new_items = await _load_new_vocab_items(db, jlpt_level=jlpt_level, count=new_count_needed, exclude_ids=exclude_ids)
    all_items = dedupe_by_meaning(merge_smart_items(review_items, retry_items, new_items))

    fallback_meanings = await _load_vocab_meanings(db, jlpt_level)
    questions: list[QuestionPayload] = []
    for vocab in all_items:
        questions.append(
            await build_smart_vocab_question(
                db,
                vocab,
                jlpt_level=jlpt_level,
                user_id=user_id,
                fallback_meanings=fallback_meanings,
                distractor_generator=generate_distractors,
                shuffle=random.shuffle,
            )
        )
    return questions


async def _load_smart_grammar_questions(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    jlpt_level: str,
    distribution: dict[str, int],
    now: datetime,
) -> list[QuestionPayload]:
    review_items = await _load_grammar_review_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["review"], now=now)
    retry_items = await _load_grammar_retry_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["retry"], now=now)

    studied_ids_result = await db.execute(select(UserGrammarProgress.grammar_id).where(UserGrammarProgress.user_id == user_id))
    studied_ids = set(studied_ids_result.scalars().all())
    exclude_ids = build_exclude_ids(studied_ids, review_items, retry_items)

    new_count_needed = calculate_new_count_needed(distribution, review_count=len(review_items), retry_count=len(retry_items))
    new_items = await _load_new_grammar_items(db, jlpt_level=jlpt_level, count=new_count_needed, exclude_ids=exclude_ids)
    all_items = dedupe_by_meaning(merge_smart_items(review_items, retry_items, new_items))

    all_meanings = await _load_grammar_meanings(db, jlpt_level)
    return build_smart_grammar_questions(all_items, all_meanings=all_meanings, shuffle=random.shuffle)


async def _load_vocab_review_items(
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


async def _load_vocab_retry_items(
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


async def _load_new_vocab_items(
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


async def _load_grammar_review_items(
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


async def _load_grammar_retry_items(
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


async def _load_new_grammar_items(
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


async def _load_vocab_meanings(db: AsyncSession, jlpt_level: str) -> list[str]:
    result = await db.execute(select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50))
    return list(result.scalars().all())


async def _load_grammar_meanings(db: AsyncSession, jlpt_level: str) -> list[str]:
    result = await db.execute(select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50))
    return list(result.scalars().all())
