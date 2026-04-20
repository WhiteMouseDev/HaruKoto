from __future__ import annotations

import random
import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    ClozeQuestion,
    Grammar,
    SentenceArrangeQuestion,
    UserGrammarProgress,
    UserVocabProgress,
    Vocabulary,
)
from app.services.quiz_question_builder import (
    QuestionPayload,
    build_cloze_question,
    build_grammar_question,
    build_options,
    build_sentence_arrange_question,
    build_vocab_question,
)
from app.utils.constants import QUIZ_CONFIG

VOCAB_QUIZ_TYPES = ("VOCABULARY", "KANJI", "LISTENING")


async def load_cloze_questions(
    db: AsyncSession,
    *,
    jlpt_level: str,
    count: int,
    stage_content_ids: list[uuid.UUID],
) -> list[QuestionPayload]:
    query = select(ClozeQuestion).where(ClozeQuestion.jlpt_level == jlpt_level)
    if stage_content_ids:
        query = query.where(ClozeQuestion.id.in_(stage_content_ids))
    result = await db.execute(query.order_by(func.random()).limit(count))
    return [build_cloze_question(item) for item in result.scalars().all()]


async def load_sentence_arrange_questions(
    db: AsyncSession,
    *,
    jlpt_level: str,
    count: int,
    stage_content_ids: list[uuid.UUID],
) -> list[QuestionPayload]:
    query = select(SentenceArrangeQuestion).where(SentenceArrangeQuestion.jlpt_level == jlpt_level)
    if stage_content_ids:
        query = query.where(SentenceArrangeQuestion.id.in_(stage_content_ids))
    result = await db.execute(query.order_by(func.random()).limit(count))
    return [build_sentence_arrange_question(item) for item in result.scalars().all()]


async def load_review_questions(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    quiz_type: str,
    jlpt_level: str,
    count: int,
    stage_content_ids: list[uuid.UUID],
    now: datetime | None = None,
) -> list[QuestionPayload]:
    review_time = now or datetime.now(UTC)
    if quiz_type in VOCAB_QUIZ_TYPES:
        vocab_query = (
            select(Vocabulary)
            .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
            .where(
                UserVocabProgress.user_id == user_id,
                Vocabulary.jlpt_level == jlpt_level,
                UserVocabProgress.next_review_at <= review_time,
            )
            .order_by(UserVocabProgress.next_review_at)
        )
        if stage_content_ids:
            vocab_query = vocab_query.where(Vocabulary.id.in_(stage_content_ids))
        vocab_result = await db.execute(vocab_query.limit(count))
        vocab_items = list(vocab_result.scalars().all())
        meanings = await _load_vocab_meanings(db, jlpt_level)
        return [_build_vocab_payload(vocab, quiz_type, meanings, shuffle_wrong_texts=False) for vocab in vocab_items]

    grammar_query = (
        select(Grammar)
        .join(UserGrammarProgress, UserGrammarProgress.grammar_id == Grammar.id)
        .where(
            UserGrammarProgress.user_id == user_id,
            Grammar.jlpt_level == jlpt_level,
            UserGrammarProgress.next_review_at <= review_time,
        )
    )
    if stage_content_ids:
        grammar_query = grammar_query.where(Grammar.id.in_(stage_content_ids))
    grammar_result = await db.execute(grammar_query.limit(count))
    grammar_items = list(grammar_result.scalars().all())
    meanings = await _load_grammar_meanings(db, jlpt_level)
    return [_build_grammar_payload(grammar, quiz_type, meanings, shuffle_wrong_texts=False) for grammar in grammar_items]


async def load_normal_questions(
    db: AsyncSession,
    *,
    quiz_type: str,
    jlpt_level: str,
    count: int,
    stage_content_ids: list[uuid.UUID],
) -> list[QuestionPayload]:
    if quiz_type in VOCAB_QUIZ_TYPES:
        vocab_query = select(Vocabulary)
        vocab_query = (
            vocab_query.where(Vocabulary.id.in_(stage_content_ids))
            if stage_content_ids
            else vocab_query.where(Vocabulary.jlpt_level == jlpt_level)
        )
        vocab_result = await db.execute(vocab_query.order_by(func.random()).limit(count))
        vocab_items = list(vocab_result.scalars().all())
        meanings = await _load_vocab_meanings(db, jlpt_level)
        return [_build_vocab_payload(vocab, quiz_type, meanings, shuffle_wrong_texts=True) for vocab in vocab_items]

    if quiz_type == "GRAMMAR":
        grammar_query = select(Grammar)
        grammar_query = (
            grammar_query.where(Grammar.id.in_(stage_content_ids))
            if stage_content_ids
            else grammar_query.where(Grammar.jlpt_level == jlpt_level)
        )
        grammar_result = await db.execute(grammar_query.order_by(func.random()).limit(count))
        grammar_items = list(grammar_result.scalars().all())
        meanings = await _load_grammar_meanings(db, jlpt_level)
        return [_build_grammar_payload(grammar, quiz_type, meanings, shuffle_wrong_texts=True) for grammar in grammar_items]

    return []


async def _load_vocab_meanings(db: AsyncSession, jlpt_level: str) -> list[str]:
    result = await db.execute(select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50))
    return list(result.scalars().all())


async def _load_grammar_meanings(db: AsyncSession, jlpt_level: str) -> list[str]:
    result = await db.execute(select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50))
    return list(result.scalars().all())


def _build_vocab_payload(
    vocab: Vocabulary,
    quiz_type: str,
    meanings: list[str],
    *,
    shuffle_wrong_texts: bool,
) -> QuestionPayload:
    wrong_texts = [meaning for meaning in meanings if meaning != vocab.meaning_ko]
    if shuffle_wrong_texts:
        random.shuffle(wrong_texts)
    options, correct_id = build_options(vocab.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
    return build_vocab_question(vocab, quiz_type, options, correct_id)


def _build_grammar_payload(
    grammar: Grammar,
    quiz_type: str,
    meanings: list[str],
    *,
    shuffle_wrong_texts: bool,
) -> QuestionPayload:
    wrong_texts = [meaning for meaning in meanings if meaning != grammar.meaning_ko]
    if shuffle_wrong_texts:
        random.shuffle(wrong_texts)
    options, correct_id = build_options(grammar.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
    return build_grammar_question(grammar, quiz_type, options, correct_id)
