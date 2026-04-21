from __future__ import annotations

import uuid
from collections.abc import Awaitable, Callable, Iterable, Mapping, MutableSequence
from typing import Any, Protocol

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.quiz_question_builder import QuestionPayload, build_grammar_question, build_options, build_vocab_question
from app.utils.constants import QUIZ_CONFIG

type Shuffle = Callable[[MutableSequence[Any]], None]


class SmartVocabQuestionSource(Protocol):
    id: uuid.UUID
    word: str
    reading: str
    meaning_ko: str


class SmartGrammarQuestionSource(Protocol):
    id: uuid.UUID
    pattern: str
    meaning_ko: str


class DistractorGenerator(Protocol):
    def __call__(
        self,
        db: AsyncSession,
        *,
        correct_item_id: uuid.UUID,
        item_type: str,
        jlpt_level: str,
        count: int,
        user_id: uuid.UUID,
    ) -> Awaitable[Iterable[Mapping[str, Any]]]: ...


async def build_smart_vocab_question(
    db: AsyncSession,
    vocab: SmartVocabQuestionSource,
    *,
    jlpt_level: str,
    user_id: uuid.UUID,
    fallback_meanings: Iterable[str],
    distractor_generator: DistractorGenerator,
    shuffle: Shuffle,
) -> QuestionPayload:
    distractors = await distractor_generator(
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
        text = distractor["text"]
        options.append({"id": str(uuid.uuid4()), "text": text})
        used_texts.add(text)

    if len(options) - 1 < QUIZ_CONFIG.WRONG_OPTIONS_COUNT:
        for meaning in fallback_meanings:
            if meaning not in used_texts:
                options.append({"id": str(uuid.uuid4()), "text": meaning})
                used_texts.add(meaning)
                if len(options) - 1 >= QUIZ_CONFIG.WRONG_OPTIONS_COUNT:
                    break

    shuffle(options)
    return build_vocab_question(vocab, "VOCABULARY", options, correct_id)


def build_smart_grammar_questions(
    grammar_items: Iterable[SmartGrammarQuestionSource],
    *,
    all_meanings: Iterable[str],
    shuffle: Shuffle,
) -> list[QuestionPayload]:
    meanings = list(all_meanings)
    return [build_smart_grammar_question(grammar, all_meanings=meanings, shuffle=shuffle) for grammar in grammar_items]


def build_smart_grammar_question(
    grammar: SmartGrammarQuestionSource,
    *,
    all_meanings: Iterable[str],
    shuffle: Shuffle,
) -> QuestionPayload:
    wrong_texts = [meaning for meaning in all_meanings if meaning != grammar.meaning_ko]
    shuffle(wrong_texts)
    options, correct_id = build_options(grammar.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
    return build_grammar_question(grammar, "GRAMMAR", options, correct_id)
