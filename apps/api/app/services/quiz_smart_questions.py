from __future__ import annotations

import random
import uuid
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.distractor import generate_distractors
from app.services.quiz_question_builder import QuestionPayload
from app.services.quiz_smart_item_queries import (
    load_grammar_meanings,
    load_grammar_retry_items,
    load_grammar_review_items,
    load_grammar_studied_ids,
    load_new_grammar_items,
    load_new_vocab_items,
    load_vocab_meanings,
    load_vocab_retry_items,
    load_vocab_review_items,
    load_vocab_studied_ids,
)
from app.services.quiz_smart_item_selection import build_exclude_ids, calculate_new_count_needed, dedupe_by_meaning, merge_smart_items
from app.services.quiz_smart_question_payloads import build_smart_grammar_questions, build_smart_vocab_question


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
    review_items = await load_vocab_review_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["review"], now=now)
    retry_items = await load_vocab_retry_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["retry"], now=now)

    studied_ids = await load_vocab_studied_ids(db, user_id=user_id)
    exclude_ids = build_exclude_ids(studied_ids, review_items, retry_items)

    new_count_needed = calculate_new_count_needed(distribution, review_count=len(review_items), retry_count=len(retry_items))
    new_items = await load_new_vocab_items(db, jlpt_level=jlpt_level, count=new_count_needed, exclude_ids=exclude_ids)
    all_items = dedupe_by_meaning(merge_smart_items(review_items, retry_items, new_items))

    fallback_meanings = await load_vocab_meanings(db, jlpt_level)
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
    review_items = await load_grammar_review_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["review"], now=now)
    retry_items = await load_grammar_retry_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["retry"], now=now)

    studied_ids = await load_grammar_studied_ids(db, user_id=user_id)
    exclude_ids = build_exclude_ids(studied_ids, review_items, retry_items)

    new_count_needed = calculate_new_count_needed(distribution, review_count=len(review_items), retry_count=len(retry_items))
    new_items = await load_new_grammar_items(db, jlpt_level=jlpt_level, count=new_count_needed, exclude_ids=exclude_ids)
    all_items = dedupe_by_meaning(merge_smart_items(review_items, retry_items, new_items))

    all_meanings = await load_grammar_meanings(db, jlpt_level)
    return build_smart_grammar_questions(all_items, all_meanings=all_meanings, shuffle=random.shuffle)
