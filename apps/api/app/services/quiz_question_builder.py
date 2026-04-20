from __future__ import annotations

import random
import uuid
from typing import Any, Protocol

from app.schemas.quiz import QuizOption

OptionPayload = dict[str, str]
QuestionPayload = dict[str, Any]


class VocabularyQuestionSource(Protocol):
    id: object
    word: str
    reading: str
    meaning_ko: str


class GrammarQuestionSource(Protocol):
    id: object
    pattern: str
    meaning_ko: str


def build_options(correct_text: str, wrong_texts: list[str]) -> tuple[list[OptionPayload], str]:
    correct_id = str(uuid.uuid4())
    options = [_build_option_payload(correct_id, correct_text)]
    for wrong_text in wrong_texts:
        options.append(_build_option_payload(str(uuid.uuid4()), wrong_text))
    random.shuffle(options)
    return options, correct_id


def build_vocab_question(
    vocab: VocabularyQuestionSource,
    quiz_type: str,
    options: list[OptionPayload],
    correct_id: str,
) -> QuestionPayload:
    return {
        "id": str(vocab.id),
        "type": quiz_type,
        "question": vocab.word,
        "reading": vocab.reading,
        "questionSubText": vocab.reading,
        "options": options,
        "correctOptionId": correct_id,
        "word": vocab.word,
        "meaningKo": vocab.meaning_ko,
    }


def build_grammar_question(
    grammar: GrammarQuestionSource,
    quiz_type: str,
    options: list[OptionPayload],
    correct_id: str,
) -> QuestionPayload:
    return {
        "id": str(grammar.id),
        "type": quiz_type,
        "question": grammar.pattern,
        "options": options,
        "correctOptionId": correct_id,
        "pattern": grammar.pattern,
        "meaningKo": grammar.meaning_ko,
    }


def _build_option_payload(option_id: str, text: str) -> OptionPayload:
    option = QuizOption(id=option_id, text=text)
    return {"id": option.id, "text": option.text}
