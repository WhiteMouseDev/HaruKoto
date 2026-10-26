from __future__ import annotations

import uuid
from copy import deepcopy
from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest

from app.models import QuizSession
from app.models.enums import JlptLevel, QuizType
from app.schemas.quiz import QuizQuestion
from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_session_query import ResumeQuizResult
from app.services.quiz_wrong_review import _validated_questions


def _source() -> QuizSession:
    return QuizSession(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        quiz_type=QuizType.GRAMMAR,
        jlpt_level=JlptLevel.N5,
        total_questions=1,
        completed_at=datetime.now(UTC),
        questions_data=[
            {
                "id": str(uuid.uuid4()),
                "type": "GRAMMAR",
                "question": "です",
                "options": [{"id": "correct", "text": "~입니다"}, {"id": "wrong", "text": "~없다"}],
                "correctOptionId": "correct",
            }
        ],
    )


@pytest.mark.parametrize(
    "damage",
    [
        "non-list",
        "bad-id",
        "duplicate-question",
        "wrong-type",
        "empty-question",
        "non-options",
        "one-option",
        "duplicate-option",
        "bad-text",
        "bad-correct",
        "bad-hint",
    ],
)
def test_invalid_snapshot_cannot_become_a_scored_wrong_review(damage: str) -> None:
    source = _source()
    questions = deepcopy(source.questions_data)
    assert isinstance(questions, list)
    question = questions[0]
    if damage == "non-list":
        source.questions_data = {"questions": None}
    elif damage == "bad-id":
        question["id"] = "invalid-id"
    elif damage == "duplicate-question":
        questions.append(deepcopy(question))
        source.total_questions = 2
    elif damage == "wrong-type":
        question["type"] = "VOCABULARY"
    elif damage == "empty-question":
        question["question"] = " "
    elif damage == "non-options":
        question["options"] = {}
    elif damage == "one-option":
        question["options"] = question["options"][:1]
    elif damage == "duplicate-option":
        question["options"][1]["id"] = "correct"
    elif damage == "bad-text":
        question["options"][1]["text"] = None
    elif damage == "bad-correct":
        question["correctOptionId"] = "not-an-option"
    elif damage == "bad-hint":
        question["hint"] = {"invalid": True}
    if damage != "non-list":
        source.questions_data = questions

    with pytest.raises(QuizQueryServiceError) as error:
        _validated_questions(source)

    assert error.value.status_code == 409


@pytest.mark.parametrize("mode", ["matching", "cloze", "arrange", "typing", ["smart"]])
def test_unsupported_or_malformed_mode_does_not_fall_back_to_general_review(mode: object) -> None:
    source = _source()
    source.questions_data = {"mode": mode, "questions": source.questions_data}

    with pytest.raises(QuizQueryServiceError) as error:
        _validated_questions(source)

    assert error.value.status_code == 400


@pytest.mark.parametrize("question_type", ["CLOZE", "SENTENCE_ARRANGE", "TYPING", "MATCHING", "KANA"])
def test_known_special_question_payload_without_legacy_mode_is_explicitly_unsupported(question_type: str) -> None:
    source = _source()
    assert isinstance(source.questions_data, list)
    source.questions_data[0]["type"] = question_type

    with pytest.raises(QuizQueryServiceError) as error:
        _validated_questions(source)

    assert error.value.status_code == 400


@pytest.mark.asyncio
async def test_wrong_review_route_uses_source_uuid_and_existing_resume_response(client, monkeypatch: pytest.MonkeyPatch) -> None:
    source_id, review_id = uuid.uuid4(), uuid.uuid4()
    question_id = uuid.uuid4()
    service = AsyncMock(
        return_value=ResumeQuizResult(
            session_id=str(review_id),
            questions=[QuizQuestion(question_id=str(question_id), question_text="です", options=[])],
            answered_question_ids=[str(question_id)],
            total_questions=1,
            correct_count=1,
            quiz_type="GRAMMAR",
        )
    )
    monkeypatch.setattr("app.routers.quiz.start_wrong_answer_review", service)

    response = await client.post("/api/v1/quiz/wrong-answer-review/start", json={"sourceSessionId": str(source_id)})

    assert response.status_code == 200
    payload = response.json()
    assert set(payload) == {"sessionId", "questions", "answeredQuestionIds", "totalQuestions", "correctCount", "quizType"}
    assert payload["sessionId"] == str(review_id)
    assert payload["answeredQuestionIds"] == [str(question_id)]
    assert payload["correctCount"] == 1
    assert payload["quizType"] == "GRAMMAR"
    assert service.await_args.args[2].source_session_id == source_id


@pytest.mark.asyncio
async def test_wrong_review_route_rejects_invalid_source_before_calling_service(client, monkeypatch: pytest.MonkeyPatch) -> None:
    service = AsyncMock()
    monkeypatch.setattr("app.routers.quiz.start_wrong_answer_review", service)

    response = await client.post("/api/v1/quiz/wrong-answer-review/start", json={"sourceSessionId": "invalid"})

    assert response.status_code == 422
    service.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("status,code", [(400, "VALIDATION_ERROR"), (404, "RESOURCE_NOT_FOUND"), (409, "SYSTEM_ERROR")])
async def test_wrong_review_route_preserves_existing_error_contract(
    client, monkeypatch: pytest.MonkeyPatch, status: int, code: str
) -> None:
    monkeypatch.setattr(
        "app.routers.quiz.start_wrong_answer_review",
        AsyncMock(side_effect=QuizQueryServiceError(status_code=status, detail="복습할 수 없습니다")),
    )

    response = await client.post("/api/v1/quiz/wrong-answer-review/start", json={"sourceSessionId": str(uuid.uuid4())})

    assert response.status_code == status
    assert response.json() == {"error": {"code": code, "message": "복습할 수 없습니다", "details": None}}


@pytest.mark.asyncio
async def test_wrong_review_requires_authentication_before_accessing_source(client, monkeypatch: pytest.MonkeyPatch) -> None:
    from app.dependencies import get_current_user
    from app.main import app

    app.dependency_overrides.pop(get_current_user)
    service = AsyncMock()
    monkeypatch.setattr("app.routers.quiz.start_wrong_answer_review", service)

    response = await client.post("/api/v1/quiz/wrong-answer-review/start", json={"sourceSessionId": str(uuid.uuid4())})

    assert response.status_code == 401
    service.assert_not_awaited()
