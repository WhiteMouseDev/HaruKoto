from copy import deepcopy
from datetime import UTC, datetime
from unittest.mock import ANY, AsyncMock, call
from uuid import uuid4

import pytest

from app.db.session import get_db
from app.models.lesson import Lesson

UPDATED_AT = datetime(2026, 11, 27, 1, 30, tzinfo=UTC)
VERSION = "2026-11-27T01:30:00+00:00"


@pytest.fixture
def feedback_lesson():
    return Lesson(
        id=uuid4(),
        is_published=True,
        updated_at=UPDATED_AT,
        content_jsonb={
            "reading": {"script": []},
            "questions": [
                {
                    "order": 2,
                    "type": "VOCAB_MCQ",
                    "prompt": "切符",
                    "options": [{"id": "a", "text": "표"}, {"id": "b", "text": "가방"}],
                    "correct_answer": "a",
                    "explanation": "切符는 표라는 뜻이에요.",
                },
                {
                    "order": 7,
                    "type": "CONTEXT_CLOZE",
                    "prompt": "切符を＿＿。",
                    "options": [{"id": "a", "text": "買います"}],
                    "correct_answer": "a",
                },
                {"order": 11, "type": "SENTENCE_REORDER", "prompt": "배열", "tokens": ["切符", "です"]},
            ],
        },
    )


@pytest.fixture
def feedback_session(client, feedback_lesson):
    from app.main import app

    db = AsyncMock()
    db.scalar.return_value = feedback_lesson

    async def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    return db


@pytest.mark.parametrize(
    ("order", "option", "correct", "explanation"),
    [(2, "b", False, "切符는 표라는 뜻이에요."), (7, "a", True, None)],
)
async def test_feedback_grades_only_requested_recognition_question_without_writes(
    client, mock_user, feedback_lesson, feedback_session, order, option, correct, explanation
):
    original = deepcopy(feedback_lesson.content_jsonb)
    response = await client.post(
        f"/api/v1/lessons/{feedback_lesson.id}/questions/{order}/feedback",
        json={"expectedUserId": str(mock_user.id), "feedbackVersion": VERSION, "selectedAnswer": option},
    )

    assert response.status_code == 200
    assert response.headers["Cache-Control"] == "private, no-store"
    assert response.json() == {
        "feedbackVersion": VERSION,
        "questionOrder": order,
        "selectedAnswer": option,
        "correctAnswer": "a",
        "isCorrect": correct,
        "explanation": explanation,
    }
    assert "lessons.is_published IS true" in str(feedback_session.scalar.await_args.args[0])
    assert feedback_session.mock_calls == [call.scalar(ANY)]
    assert feedback_lesson.content_jsonb == original


@pytest.mark.parametrize(
    ("order", "change", "status"),
    [(2, "owner", 403), (2, "absent", 404), (3, "none", 404), (2, "stale", 409), (2, "invalid", 400), (11, "none", 400), (0, "none", 422)],
)
async def test_feedback_rejects_wrong_owner_stale_or_invalid_request_without_grades(
    client, mock_user, feedback_lesson, feedback_session, order, change, status
):
    body = {"expectedUserId": str(mock_user.id), "feedbackVersion": VERSION, "selectedAnswer": "a"}
    if change == "owner":
        body["expectedUserId"] = str(uuid4())
    elif change == "absent":
        feedback_session.scalar.return_value = None
    elif change == "stale":
        body["feedbackVersion"] = "2026-11-26T01:30:00+00:00"
    elif change == "invalid":
        body["selectedAnswer"] = "z"

    response = await client.post(f"/api/v1/lessons/{feedback_lesson.id}/questions/{order}/feedback", json=body)

    assert response.status_code == status
    assert response.headers["Cache-Control"] == "private, no-store"
    assert "correctAnswer" not in response.json()
    assert feedback_session.mock_calls == ([] if status in {403, 422} else [call.scalar(ANY)])
