from __future__ import annotations

import random
import uuid
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, Vocabulary
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
from app.services.quiz_smart_item_session import SmartItemLoaders, load_selected_smart_items
from app.services.quiz_smart_question_payloads import build_smart_grammar_questions, build_smart_vocab_question

VOCAB_ITEM_LOADERS = SmartItemLoaders[Vocabulary](
    load_review_items=load_vocab_review_items,
    load_retry_items=load_vocab_retry_items,
    load_studied_ids=load_vocab_studied_ids,
    load_new_items=load_new_vocab_items,
)

GRAMMAR_ITEM_LOADERS = SmartItemLoaders[Grammar](
    load_review_items=load_grammar_review_items,
    load_retry_items=load_grammar_retry_items,
    load_studied_ids=load_grammar_studied_ids,
    load_new_items=load_new_grammar_items,
)


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
    all_items = await load_selected_smart_items(
        db,
        user_id=user_id,
        jlpt_level=jlpt_level,
        distribution=distribution,
        now=now,
        loaders=VOCAB_ITEM_LOADERS,
    )

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
    all_items = await load_selected_smart_items(
        db,
        user_id=user_id,
        jlpt_level=jlpt_level,
        distribution=distribution,
        now=now,
        loaders=GRAMMAR_ITEM_LOADERS,
    )

    all_meanings = await load_grammar_meanings(db, jlpt_level)
    return build_smart_grammar_questions(all_items, all_meanings=all_meanings, shuffle=random.shuffle)
