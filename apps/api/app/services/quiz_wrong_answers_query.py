from __future__ import annotations

import contextlib
import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizAnswer, QuizSession, Vocabulary
from app.models.user import User
from app.services.quiz_query import QuizQueryServiceError
from app.services.quiz_session import extract_questions_data

VOCABULARY_QUESTION_TYPES = {"VOCABULARY", "KANJI", "LISTENING"}


@dataclass(slots=True)
class WrongAnswerResult:
    question_id: str
    word: str | None
    reading: str | None
    meaning_ko: str | None
    example_sentence: str | None
    example_translation: str | None


async def get_wrong_answers_data(
    db: AsyncSession,
    user: User,
    *,
    session_id: str,
) -> list[WrongAnswerResult]:
    session = await db.get(QuizSession, session_id)
    if not session or session.user_id != user.id:
        raise QuizQueryServiceError(status_code=404, detail="세션을 찾을 수 없습니다")

    wrong_answers = await _load_wrong_answers(db, session=session)
    questions_data = extract_questions_data(session.questions_data)
    question_map = {question["id"]: question for question in questions_data}
    vocab_map = await _load_wrong_answer_vocab_map(
        db,
        wrong_answers=wrong_answers,
        question_map=question_map,
    )

    return [
        _build_wrong_answer_result(
            wrong_answer=wrong_answer,
            question=question_map.get(str(wrong_answer.question_id), {}),
            vocab_entry=vocab_map.get(str(wrong_answer.question_id)),
        )
        for wrong_answer in wrong_answers
    ]


async def _load_wrong_answers(
    db: AsyncSession,
    *,
    session: QuizSession,
) -> list[QuizAnswer]:
    wrong_result = await db.execute(
        select(QuizAnswer).where(
            QuizAnswer.session_id == session.id,
            QuizAnswer.is_correct.is_(False),
        )
    )
    return list(wrong_result.scalars().all())


async def _load_wrong_answer_vocab_map(
    db: AsyncSession,
    *,
    wrong_answers: list[QuizAnswer],
    question_map: dict[str, dict[str, object]],
) -> dict[str, Vocabulary]:
    wrong_vocab_ids = _collect_wrong_vocab_ids(
        wrong_answers=wrong_answers,
        question_map=question_map,
    )
    if not wrong_vocab_ids:
        return {}

    vocab_result = await db.execute(select(Vocabulary).where(Vocabulary.id.in_(wrong_vocab_ids)))
    return {str(vocab_item.id): vocab_item for vocab_item in vocab_result.scalars().all()}


def _collect_wrong_vocab_ids(
    *,
    wrong_answers: list[QuizAnswer],
    question_map: dict[str, dict[str, object]],
) -> list[uuid.UUID]:
    wrong_vocab_ids: list[uuid.UUID] = []
    for wrong_answer in wrong_answers:
        question = question_map.get(str(wrong_answer.question_id))
        if question and question.get("type") in VOCABULARY_QUESTION_TYPES:
            with contextlib.suppress(ValueError):
                wrong_vocab_ids.append(uuid.UUID(str(wrong_answer.question_id)))
    return wrong_vocab_ids


def _build_wrong_answer_result(
    *,
    wrong_answer: QuizAnswer,
    question: dict[str, object],
    vocab_entry: Vocabulary | None,
) -> WrongAnswerResult:
    question_id = str(wrong_answer.question_id)
    return WrongAnswerResult(
        question_id=question_id,
        word=_string_or_none(question.get("word")),
        reading=_string_or_none(question.get("reading")) or (vocab_entry.reading if vocab_entry else None),
        meaning_ko=_string_or_none(question.get("meaningKo")),
        example_sentence=vocab_entry.example_sentence if vocab_entry else None,
        example_translation=vocab_entry.example_translation if vocab_entry else None,
    )


def _string_or_none(value: object) -> str | None:
    return value if isinstance(value, str) else None
