from __future__ import annotations

import random
import uuid
from collections.abc import Iterable
from datetime import datetime, timedelta
from typing import Protocol

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, UserGrammarProgress, UserVocabProgress, Vocabulary
from app.services.distractor import generate_distractors
from app.services.quiz_question_builder import QuestionPayload, build_grammar_question, build_options, build_vocab_question
from app.utils.constants import QUIZ_CONFIG, SRS_CONFIG


class SmartContentItem(Protocol):
    id: uuid.UUID
    meaning_ko: str


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
    exclude_ids = _build_exclude_ids(studied_ids, review_items, retry_items)

    new_count_needed = _calculate_new_count_needed(distribution, review_count=len(review_items), retry_count=len(retry_items))
    new_items = await _load_new_vocab_items(db, jlpt_level=jlpt_level, count=new_count_needed, exclude_ids=exclude_ids)
    all_items = _dedupe_by_meaning(_merge_smart_items(review_items, retry_items, new_items))

    fallback_meanings = await _load_vocab_meanings(db, jlpt_level)
    questions: list[QuestionPayload] = []
    for vocab in all_items:
        questions.append(
            await _build_smart_vocab_question(
                db,
                vocab,
                jlpt_level=jlpt_level,
                user_id=user_id,
                fallback_meanings=fallback_meanings,
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
    exclude_ids = _build_exclude_ids(studied_ids, review_items, retry_items)

    new_count_needed = _calculate_new_count_needed(distribution, review_count=len(review_items), retry_count=len(retry_items))
    new_items = await _load_new_grammar_items(db, jlpt_level=jlpt_level, count=new_count_needed, exclude_ids=exclude_ids)
    all_items = _dedupe_by_meaning(_merge_smart_items(review_items, retry_items, new_items))

    all_meanings = await _load_grammar_meanings(db, jlpt_level)
    questions: list[QuestionPayload] = []
    for grammar in all_items:
        wrong_texts = [meaning for meaning in all_meanings if meaning != grammar.meaning_ko]
        random.shuffle(wrong_texts)
        options, correct_id = build_options(grammar.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
        questions.append(build_grammar_question(grammar, "GRAMMAR", options, correct_id))
    return questions


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


async def _build_smart_vocab_question(
    db: AsyncSession,
    vocab: Vocabulary,
    *,
    jlpt_level: str,
    user_id: uuid.UUID,
    fallback_meanings: list[str],
) -> QuestionPayload:
    distractors = await generate_distractors(
        db,
        correct_item_id=vocab.id,
        item_type="WORD",
        jlpt_level=jlpt_level,
        count=QUIZ_CONFIG.WRONG_OPTIONS_COUNT,
        user_id=user_id,
    )

    correct_id = str(uuid.uuid4())
    options = [{"id": correct_id, "text": vocab.meaning_ko}]
    used_texts = {vocab.meaning_ko}
    for distractor in distractors:
        options.append({"id": str(uuid.uuid4()), "text": distractor["text"]})
        used_texts.add(distractor["text"])

    if len(options) - 1 < QUIZ_CONFIG.WRONG_OPTIONS_COUNT:
        for meaning in fallback_meanings:
            if meaning not in used_texts:
                options.append({"id": str(uuid.uuid4()), "text": meaning})
                used_texts.add(meaning)
                if len(options) - 1 >= QUIZ_CONFIG.WRONG_OPTIONS_COUNT:
                    break
    random.shuffle(options)
    return build_vocab_question(vocab, "VOCABULARY", options, correct_id)


def _calculate_new_count_needed(distribution: dict[str, int], *, review_count: int, retry_count: int) -> int:
    review_shortfall = distribution["review"] - review_count
    retry_shortfall = distribution["retry"] - retry_count
    return distribution["new"] + review_shortfall + retry_shortfall


def _build_exclude_ids(
    studied_ids: Iterable[uuid.UUID],
    review_items: Iterable[SmartContentItem],
    retry_items: Iterable[SmartContentItem],
) -> set[uuid.UUID]:
    return set(studied_ids) | {item.id for item in review_items} | {item.id for item in retry_items}


def _merge_smart_items[SmartItem: SmartContentItem](
    review_items: Iterable[SmartItem],
    retry_items: Iterable[SmartItem],
    new_items: Iterable[SmartItem],
) -> list[SmartItem]:
    return [*review_items, *retry_items, *new_items]


def _dedupe_by_meaning[SmartItem: SmartContentItem](items: Iterable[SmartItem]) -> list[SmartItem]:
    deduped: list[SmartItem] = []
    seen_meanings: set[str] = set()
    for item in items:
        if item.meaning_ko in seen_meanings:
            continue
        seen_meanings.add(item.meaning_ko)
        deduped.append(item)
    return deduped
