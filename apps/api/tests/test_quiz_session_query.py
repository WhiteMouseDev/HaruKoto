from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta, timezone
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
async def test_get_incomplete_quiz_session_returns_none_without_writing() -> None:
    db = SimpleNamespace(execute=AsyncMock(return_value=_ScalarsResult([])), commit=AsyncMock())
    assert await get_incomplete_quiz_session(db, _user()) is None
    db.commit.assert_not_awaited()


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


@pytest.mark.asyncio
@pytest.mark.parametrize("stored_timezone", [None, UTC, timezone(timedelta(hours=9))], ids=["legacy-naive-utc", "utc", "kst"])
@pytest.mark.parametrize(
    "age",
    [
        timedelta(hours=24, microseconds=-1),
        timedelta(hours=24),
        timedelta(hours=24, microseconds=1),
        timedelta(days=3),
        timedelta(days=7),
        timedelta(days=30),
    ],
)
async def test_incomplete_session_preserves_old_sessions_and_timestamp_wire_format(stored_timezone, age) -> None:
    started_at = datetime(2026, 11, 3, 3, tzinfo=UTC) - age
    started_at = started_at.replace(tzinfo=None) if stored_timezone is None else started_at.astimezone(stored_timezone)
    session = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=USER_ID,
        quiz_type="VOCABULARY",
        jlpt_level="N5",
        total_questions=10,
        correct_count=1,
        started_at=started_at,
        completed_at=None,
        questions_data=None,
    )
    answer = SimpleNamespace(session_id=session.id, question_id=uuid.uuid4())
    db = SimpleNamespace(execute=AsyncMock(side_effect=[_ScalarsResult([session]), _ScalarsResult([answer])]), commit=AsyncMock())
    result = await get_incomplete_quiz_session(db, _user())
    assert result is not None
    assert result.id == str(session.id)
    assert result.started_at == started_at.isoformat()
    assert result.answered_count == 1
    assert session.completed_at is None
    assert session.started_at is started_at
    db.commit.assert_not_awaited()
