from __future__ import annotations

import random
import uuid
from typing import Any, Protocol

from app.schemas.quiz import QuizOption

OptionPayload = dict[str, str]
QuestionPayload = dict[str, Any]


class VocabularyQuestionSource(Protocol):
    @property
    def id(self) -> object: ...

    @property
    def word(self) -> str: ...

    @property
    def reading(self) -> str: ...

    @property
    def meaning_ko(self) -> str: ...


class GrammarQuestionSource(Protocol):
    @property
    def id(self) -> object: ...

    @property
    def pattern(self) -> str: ...

    @property
    def meaning_ko(self) -> str: ...


class ClozeQuestionSource(Protocol):
    @property
    def id(self) -> object: ...

    @property
    def sentence(self) -> str: ...

    @property
    def translation(self) -> str: ...

    @property
    def correct_answer(self) -> str: ...

    @property
    def options(self) -> Any: ...

    @property
    def explanation(self) -> str: ...


class SentenceArrangeQuestionSource(Protocol):
    @property
    def id(self) -> object: ...

    @property
    def korean_sentence(self) -> str: ...

    @property
    def japanese_sentence(self) -> str: ...

    @property
    def tokens(self) -> Any: ...

    @property
    def explanation(self) -> str: ...


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


def build_cloze_question(item: ClozeQuestionSource) -> QuestionPayload:
    correct_id = str(uuid.uuid4())
    options: list[dict[str, Any]] = []
    for option_text in item.options if isinstance(item.options, list) else []:
        option_id = correct_id if option_text == item.correct_answer else str(uuid.uuid4())
        options.append({"id": option_id, "text": option_text})
    return {
        "id": str(item.id),
        "type": "CLOZE",
        "question": item.sentence,
        "translation": item.translation,
        "options": options,
        "correctOptionId": correct_id,
        "explanation": item.explanation,
    }


def build_sentence_arrange_question(item: SentenceArrangeQuestionSource) -> QuestionPayload:
    return {
        "id": str(item.id),
        "type": "SENTENCE_ARRANGE",
        "question": item.korean_sentence,
        "japaneseSentence": item.japanese_sentence,
        "tokens": [token["text"] if isinstance(token, dict) else token for token in (item.tokens or [])],
        "explanation": item.explanation,
        "correctOptionId": "",
        "options": [],
    }


def _build_option_payload(option_id: str, text: str) -> OptionPayload:
    option = QuizOption(id=option_id, text=text)
    return {"id": option.id, "text": option.text}
