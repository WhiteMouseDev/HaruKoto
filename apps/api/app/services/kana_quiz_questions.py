from __future__ import annotations

import random
import uuid
from collections.abc import Sequence
from typing import Any, Protocol

OptionPayload = dict[str, str]
QuestionPayload = dict[str, Any]


class KanaQuizCharacterSource(Protocol):
    @property
    def id(self) -> object: ...

    @property
    def character(self) -> str: ...

    @property
    def romaji(self) -> str: ...


def build_kana_quiz_questions(
    characters: Sequence[KanaQuizCharacterSource],
    *,
    count: int,
    quiz_mode: str,
) -> list[QuestionPayload]:
    quiz_chars = list(characters)
    random.shuffle(quiz_chars)

    return [_build_question_payload(char, characters, quiz_mode) for char in quiz_chars[:count]]


def strip_kana_quiz_answers(questions: Sequence[QuestionPayload]) -> list[QuestionPayload]:
    return [
        {
            "id": question["id"],
            "question": question["question"],
            "options": question["options"],
        }
        for question in questions
    ]


def _build_question_payload(
    char: KanaQuizCharacterSource,
    characters: Sequence[KanaQuizCharacterSource],
    quiz_mode: str,
) -> QuestionPayload:
    wrong_pool = [candidate for candidate in characters if candidate.id != char.id]
    random.shuffle(wrong_pool)

    question_text, correct_text, wrong_texts = _select_question_texts(char, wrong_pool[:3], quiz_mode)
    options, correct_id = _build_options(correct_text, wrong_texts)

    return {
        "id": str(char.id),
        "question": question_text,
        "options": options,
        "correctOptionId": correct_id,
    }


def _select_question_texts(
    char: KanaQuizCharacterSource,
    wrong_pool: Sequence[KanaQuizCharacterSource],
    quiz_mode: str,
) -> tuple[str, str, list[str]]:
    if quiz_mode == "sound_matching":
        return char.romaji, char.character, [wrong.character for wrong in wrong_pool]

    return char.character, char.romaji, [wrong.romaji for wrong in wrong_pool]


def _build_options(correct_text: str, wrong_texts: Sequence[str]) -> tuple[list[OptionPayload], str]:
    correct_id = str(uuid.uuid4())
    options = [{"id": correct_id, "text": correct_text}]
    for wrong_text in wrong_texts:
        options.append({"id": str(uuid.uuid4()), "text": wrong_text})
    random.shuffle(options)
    return options, correct_id
