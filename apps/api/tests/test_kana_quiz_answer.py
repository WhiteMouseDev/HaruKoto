from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.schemas.kana import KanaQuizAnswerRequest
from app.services.kana_quiz_answer import (
    KanaQuizAnswerServiceError,
    find_kana_quiz_question,
    resolve_correct_option_id,
    submit_kana_quiz_answer,
)


def test_find_kana_quiz_question_filters_non_dict_payloads():
    question_id = uuid.uuid4()
    raw_questions = [
        "invalid",
        {
            "id": str(question_id),
            "correctOptionId": "correct",
        },
    ]

    assert find_kana_quiz_question(raw_questions, question_id) == {
        "id": str(question_id),
        "correctOptionId": "correct",
    }


def test_resolve_correct_option_id_defaults_non_string_values():
    assert resolve_correct_option_id({"correctOptionId": None}) == ""
    assert resolve_correct_option_id({"correctOptionId": "correct"}) == "correct"


@pytest.mark.asyncio
async def test_submit_kana_quiz_answer_updates_progress_and_session_for_correct_answer():
    user = SimpleNamespace(id=uuid.uuid4())
    question_id = uuid.uuid4()
    session = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user.id,
        questions_data=[
            {
                "id": str(question_id),
                "correctOptionId": "correct",
            }
        ],
        correct_count=0,
    )
    db = AsyncMock()
    db.get = AsyncMock(return_value=session)
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    body = KanaQuizAnswerRequest(
        session_id=session.id,
        question_id=question_id,
        selected_option_id="correct",
    )

    result = await submit_kana_quiz_answer(db, user, body)

    assert result.is_correct is True
    assert result.correct_option_id == "correct"
    assert session.correct_count == 1
    db.execute.assert_awaited_once()
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_submit_kana_quiz_answer_keeps_count_for_wrong_answer():
    user = SimpleNamespace(id=uuid.uuid4())
    question_id = uuid.uuid4()
    session = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user.id,
        questions_data=[
            {
                "id": str(question_id),
                "correctOptionId": "correct",
            }
        ],
        correct_count=2,
    )
    db = AsyncMock()
    db.get = AsyncMock(return_value=session)
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    body = KanaQuizAnswerRequest(
        session_id=session.id,
        question_id=question_id,
        selected_option_id="wrong",
    )

    result = await submit_kana_quiz_answer(db, user, body)

    assert result.is_correct is False
    assert result.correct_option_id == "correct"
    assert session.correct_count == 2


@pytest.mark.asyncio
async def test_submit_kana_quiz_answer_rejects_missing_session():
    user = SimpleNamespace(id=uuid.uuid4())
    db = AsyncMock()
    db.get = AsyncMock(return_value=None)
    body = KanaQuizAnswerRequest(
        session_id=uuid.uuid4(),
        question_id=uuid.uuid4(),
        selected_option_id="correct",
    )

    with pytest.raises(KanaQuizAnswerServiceError) as exc_info:
        await submit_kana_quiz_answer(db, user, body)

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "세션을 찾을 수 없습니다"


@pytest.mark.asyncio
async def test_submit_kana_quiz_answer_rejects_missing_question():
    user = SimpleNamespace(id=uuid.uuid4())
    session = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user.id,
        questions_data=[],
        correct_count=0,
    )
    db = AsyncMock()
    db.get = AsyncMock(return_value=session)
    body = KanaQuizAnswerRequest(
        session_id=session.id,
        question_id=uuid.uuid4(),
        selected_option_id="correct",
    )

    with pytest.raises(KanaQuizAnswerServiceError) as exc_info:
        await submit_kana_quiz_answer(db, user, body)

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "질문을 찾을 수 없습니다"
