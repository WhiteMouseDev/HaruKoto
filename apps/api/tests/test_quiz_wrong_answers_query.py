from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_wrong_answers_query import get_wrong_answers_data

USER_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


class _ScalarRows:
    def __init__(self, rows: list[object]) -> None:
        self._rows = rows

    def all(self) -> list[object]:
        return self._rows


class _DbResult:
    def __init__(self, *, scalar_rows: list[object]) -> None:
        self._scalar_rows = scalar_rows

    def scalars(self) -> _ScalarRows:
        return _ScalarRows(self._scalar_rows)


def _user() -> SimpleNamespace:
    return SimpleNamespace(id=USER_ID)


@pytest.mark.asyncio
async def test_get_wrong_answers_data_enriches_vocab_questions() -> None:
    question_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    session = SimpleNamespace(
        id=uuid.UUID("22222222-2222-2222-2222-222222222222"),
        user_id=USER_ID,
        questions_data=[
            {
                "id": str(question_id),
                "type": "VOCABULARY",
                "word": "食べる",
                "meaningKo": "먹다",
            }
        ],
    )
    wrong_answer = SimpleNamespace(question_id=question_id, is_correct=False)
    vocab = SimpleNamespace(
        id=question_id,
        reading="たべる",
        example_sentence="ごはんを食べる。",
        example_translation="밥을 먹다.",
    )
    db = SimpleNamespace(
        get=AsyncMock(return_value=session),
        execute=AsyncMock(
            side_effect=[
                _DbResult(scalar_rows=[wrong_answer]),
                _DbResult(scalar_rows=[vocab]),
            ]
        ),
    )

    results = await get_wrong_answers_data(db, _user(), session_id=str(session.id))

    assert len(results) == 1
    assert results[0].question_id == str(question_id)
    assert results[0].word == "食べる"
    assert results[0].reading == "たべる"
    assert results[0].meaning_ko == "먹다"
    assert results[0].example_sentence == "ごはんを食べる。"
    assert results[0].example_translation == "밥을 먹다."


@pytest.mark.asyncio
async def test_get_wrong_answers_data_skips_vocab_lookup_for_non_vocab_questions() -> None:
    question_id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    session = SimpleNamespace(
        id=uuid.UUID("22222222-2222-2222-2222-222222222222"),
        user_id=USER_ID,
        questions_data=[
            {
                "id": str(question_id),
                "type": "GRAMMAR",
                "word": "てもいい",
                "reading": "てもいい",
                "meaningKo": "~해도 된다",
            }
        ],
    )
    wrong_answer = SimpleNamespace(question_id=question_id, is_correct=False)
    db = SimpleNamespace(
        get=AsyncMock(return_value=session),
        execute=AsyncMock(return_value=_DbResult(scalar_rows=[wrong_answer])),
    )

    results = await get_wrong_answers_data(db, _user(), session_id=str(session.id))

    assert len(results) == 1
    assert results[0].question_id == str(question_id)
    assert results[0].word == "てもいい"
    assert results[0].reading == "てもいい"
    assert results[0].meaning_ko == "~해도 된다"
    assert db.execute.await_count == 1


@pytest.mark.asyncio
async def test_wrong_answer_display_uses_first_answer_and_snapshot_order_without_foreign_rows() -> None:
    first_id, second_id, outside_id = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    session = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=USER_ID,
        questions_data={
            "mode": "smart",
            "questions": [
                {"id": str(second_id), "type": "GRAMMAR", "pattern": "てもいい", "meaningKo": "~해도 된다"},
                {"id": str(first_id), "type": "GRAMMAR", "question": "ている", "meaningKo": "~하고 있다"},
            ],
        },
    )
    db = SimpleNamespace(
        get=AsyncMock(return_value=session),
        execute=AsyncMock(
            return_value=_DbResult(
                scalar_rows=[
                    SimpleNamespace(question_id=first_id, is_correct=True),
                    SimpleNamespace(question_id=second_id, is_correct=False),
                    SimpleNamespace(question_id=first_id, is_correct=False),
                    SimpleNamespace(question_id=second_id, is_correct=True),
                    SimpleNamespace(question_id=outside_id, is_correct=False),
                ]
            )
        ),
    )

    results = await get_wrong_answers_data(db, _user(), session_id=str(session.id))

    assert [(item.question_id, item.word, item.meaning_ko) for item in results] == [(str(second_id), "てもいい", "~해도 된다")]
    query = db.execute.await_args.args[0]
    assert "quiz_answers.answered_at" in str(query) and "ORDER BY" in str(query)
    assert db.execute.await_count == 1


@pytest.mark.asyncio
async def test_legacy_wrong_answer_can_display_question_text_without_guessing_other_content() -> None:
    question_id = uuid.uuid4()
    session = SimpleNamespace(
        id=uuid.uuid4(), user_id=USER_ID, questions_data=[{"id": str(question_id), "type": "GRAMMAR", "question": "です"}]
    )
    db = SimpleNamespace(
        get=AsyncMock(return_value=session),
        execute=AsyncMock(return_value=_DbResult(scalar_rows=[SimpleNamespace(question_id=question_id, is_correct=False)])),
    )

    results = await get_wrong_answers_data(db, _user(), session_id=str(session.id))

    assert results[0].word == "です"
    assert results[0].meaning_ko is None
    assert db.execute.await_count == 1


@pytest.mark.asyncio
async def test_get_wrong_answers_data_rejects_missing_or_foreign_session() -> None:
    db = SimpleNamespace(get=AsyncMock(return_value=None))

    with pytest.raises(QuizQueryServiceError) as exc_info:
        await get_wrong_answers_data(db, _user(), session_id=str(uuid.uuid4()))

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "세션을 찾을 수 없습니다"
