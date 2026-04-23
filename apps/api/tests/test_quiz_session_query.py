from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.schemas.quiz import QuizResumeRequest
from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_session_query import get_incomplete_quiz_session, resume_quiz_session

USER_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


class _ScalarRows:
    def __init__(self, rows: list[object]) -> None:
        self._rows = rows

    def all(self) -> list[object]:
        return self._rows


class _ScalarResult:
    def __init__(self, value: object) -> None:
        self._value = value

    def scalar(self) -> object:
        return self._value


class _ScalarsResult:
    def __init__(self, rows: list[object]) -> None:
        self._rows = rows

    def scalars(self) -> _ScalarRows:
        return _ScalarRows(self._rows)


def _user() -> SimpleNamespace:
    return SimpleNamespace(id=USER_ID)


@pytest.mark.asyncio
async def test_get_incomplete_quiz_session_completes_empty_session_and_returns_valid_session() -> None:
    empty_session = SimpleNamespace(
        id=uuid.UUID("11111111-1111-1111-1111-111111111111"),
        user_id=USER_ID,
        quiz_type="VOCABULARY",
        jlpt_level="N5",
        total_questions=10,
        correct_count=0,
        started_at=datetime.now(UTC),
        completed_at=None,
    )
    valid_session = SimpleNamespace(
        id=uuid.UUID("22222222-2222-2222-2222-222222222222"),
        user_id=USER_ID,
        quiz_type="GRAMMAR",
        jlpt_level="N4",
        total_questions=8,
        correct_count=2,
        started_at=datetime.now(UTC),
        completed_at=None,
    )
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _ScalarsResult([empty_session, valid_session]),
                _ScalarResult(0),
                _ScalarResult(3),
            ]
        ),
        commit=AsyncMock(),
    )

    result = await get_incomplete_quiz_session(db, _user())

    assert result is not None
    assert result.id == str(valid_session.id)
    assert result.quiz_type == "GRAMMAR"
    assert result.jlpt_level == "N4"
    assert result.total_questions == 8
    assert result.answered_count == 3
    assert result.correct_count == 2
    assert empty_session.completed_at is not None
    assert valid_session.completed_at is None
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_get_incomplete_quiz_session_completes_stale_sessions_and_returns_none() -> None:
    stale_session = SimpleNamespace(
        id=uuid.UUID("11111111-1111-1111-1111-111111111111"),
        user_id=USER_ID,
        quiz_type="VOCABULARY",
        jlpt_level="N5",
        total_questions=10,
        correct_count=1,
        started_at=datetime.now(UTC) - timedelta(hours=25),
        completed_at=None,
    )
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _ScalarsResult([stale_session]),
                _ScalarResult(2),
            ]
        ),
        commit=AsyncMock(),
    )

    result = await get_incomplete_quiz_session(db, _user())

    assert result is None
    assert stale_session.completed_at is not None
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_resume_quiz_session_returns_response_questions_and_answered_ids() -> None:
    session_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    question_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
    session = SimpleNamespace(
        id=session_id,
        user_id=USER_ID,
        completed_at=None,
        questions_data=[
            {
                "id": str(question_id),
                "question": "食べる",
                "questionSubText": "たべる",
                "options": [
                    {"id": "correct", "text": "먹다"},
                    {"id": "wrong", "text": "마시다"},
                ],
                "correctOptionId": "correct",
            }
        ],
        total_questions=1,
        correct_count=1,
        quiz_type="VOCABULARY",
    )
    db = SimpleNamespace(
        get=AsyncMock(return_value=session),
        execute=AsyncMock(return_value=_ScalarsResult([question_id])),
    )

    result = await resume_quiz_session(
        db,
        _user(),
        QuizResumeRequest(session_id=session_id),
    )

    assert result.session_id == str(session_id)
    assert result.answered_question_ids == [str(question_id)]
    assert result.total_questions == 1
    assert result.correct_count == 1
    assert result.quiz_type == "VOCABULARY"
    assert result.questions[0].question_id == str(question_id)
    assert result.questions[0].correct_option_id == "correct"


@pytest.mark.asyncio
async def test_resume_quiz_session_rejects_completed_session() -> None:
    session = SimpleNamespace(
        id=uuid.UUID("11111111-1111-1111-1111-111111111111"),
        user_id=USER_ID,
        completed_at=datetime.now(UTC),
    )
    db = SimpleNamespace(get=AsyncMock(return_value=session))

    with pytest.raises(QuizQueryServiceError) as exc_info:
        await resume_quiz_session(
            db,
            _user(),
            QuizResumeRequest(session_id=session.id),
        )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "이미 완료된 세션입니다"
