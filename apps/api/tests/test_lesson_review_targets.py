"""Assessment targets must be explicit and independent of display position."""

from copy import deepcopy
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from app.db.session import get_db
from app.models.lesson import Lesson, LessonItemLink
from app.schemas.lesson import AnswerSubmission, LessonContent
from app.services.lesson_command import (
    SRS_MAPPING_FAILURE_DETAIL,
    LessonServiceError,
    _map_questions_to_links,
    submit_lesson_attempt,
)


def _lesson() -> Lesson:
    words = [uuid4() for _ in range(6)]
    grammar_id = uuid4()
    return Lesson(
        id=uuid4(),
        item_links=[
            *[LessonItemLink(item_type="WORD", vocabulary_id=item_id, item_order=index + 1) for index, item_id in enumerate(words)],
            LessonItemLink(item_type="GRAMMAR", grammar_id=grammar_id, item_order=7),
        ],
    )


def test_explicit_targets_are_independent_of_question_type_order_and_link_position() -> None:
    lesson = _lesson()
    student, grammar = lesson.item_links[3], lesson.item_links[6]
    questions = [
        {"order": 2, "type": "VOCAB_MCQ", "vocabulary_id": str(student.vocabulary_id).upper()},
        {"order": 3, "type": "CONTEXT_CLOZE", "grammar_id": str(grammar.grammar_id)},
        {"order": 4, "type": "CONTEXT_CLOZE", "grammar_id": str(grammar.grammar_id)},
        {"order": 5, "type": "SENTENCE_REORDER", "grammar_id": str(grammar.grammar_id)},
        # A word-recognition question can assess a grammar item, and vice versa.
        {"order": 12, "type": "VOCAB_MCQ", "grammar_id": str(grammar.grammar_id)},
        {"order": 14, "type": "CONTEXT_CLOZE", "vocabulary_id": str(student.vocabulary_id)},
    ]
    lesson.item_links.reverse()

    mapped = _map_questions_to_links(lesson, questions)

    assert mapped[2] is student
    assert all(mapped[order] is grammar for order in (3, 4, 5, 12))
    assert mapped[14] is student


@pytest.mark.parametrize(
    "metadata",
    [
        {},
        {"vocabulary_id": "not-a-uuid"},
        {"vocabulary_id": ""},
        {"vocabulary_id": None},
        {"vocabulary_id": 1},
        {"vocabulary_id": True},
        {"vocabulary_id": str(uuid4())},
        {"vocabulary_id": str(uuid4()), "grammar_id": str(uuid4())},
        {"vocabulary_id": str(uuid4()), "grammar_id": None},
        {"srs_skip_reason": ""},
        {"srs_skip_reason": "  "},
        {"srs_skip_reason": None},
        {"srs_skip_reason": 1},
        {"srs_skip_reason": "복합 문장 검수", "vocabulary_id": str(uuid4())},
        {"vocabulary_order": 7},
    ],
    ids=[
        "missing",
        "malformed",
        "empty",
        "null",
        "integer",
        "boolean",
        "outside-lesson",
        "both-types",
        "both-fields-with-null",
        "empty-skip",
        "blank-skip",
        "null-skip",
        "integer-skip",
        "skip-and-target",
        "unresolved-seed-order",
    ],
)
async def test_invalid_target_fails_before_registration_or_any_progress_writes(metadata: dict, mock_user) -> None:
    lesson = _lesson()
    questions = [
        {"order": 1, "type": "VOCAB_MCQ", "correct_answer": "a", "vocabulary_id": str(lesson.item_links[0].vocabulary_id)},
        {"order": 2, "type": "VOCAB_MCQ", "correct_answer": "b", **metadata},
    ]
    lesson.content_jsonb = {"questions": questions}
    original = deepcopy(lesson.content_jsonb)
    loaded = MagicMock()
    loaded.scalar_one_or_none.return_value = lesson
    db = AsyncMock()
    db.execute.return_value = loaded

    with (
        patch("app.services.lesson_command.register_items_from_lesson", new_callable=AsyncMock) as register,
        patch("app.services.lesson_command.process_answer", new_callable=AsyncMock) as process,
        pytest.raises(LessonServiceError) as error,
    ):
        await submit_lesson_attempt(
            db,
            mock_user,
            lesson_id=lesson.id,
            answers=[AnswerSubmission(order=1, selected_answer="a"), AnswerSubmission(order=2, selected_answer="b")],
        )

    assert (error.value.status_code, error.value.detail) == (409, SRS_MAPPING_FAILURE_DETAIL)
    assert lesson.content_jsonb == original
    register.assert_not_awaited()
    process.assert_not_awaited()
    db.begin_nested.assert_not_called()
    db.add.assert_not_called()
    db.flush.assert_not_awaited()
    db.commit.assert_not_awaited()


def test_uuid_of_wrong_item_type_and_duplicate_links_are_rejected() -> None:
    lesson = _lesson()
    grammar_id = lesson.item_links[-1].grammar_id
    with pytest.raises(LessonServiceError):
        _map_questions_to_links(lesson, [{"order": 1, "vocabulary_id": str(grammar_id)}])
    link = lesson.item_links[0]
    lesson.item_links.append(LessonItemLink(item_type="WORD", vocabulary_id=link.vocabulary_id, item_order=8))
    with pytest.raises(LessonServiceError):
        _map_questions_to_links(lesson, [{"order": 1, "vocabulary_id": str(link.vocabulary_id)}])


def test_explicit_reviewed_exclusion_is_not_inferred_from_missing_metadata() -> None:
    lesson = _lesson()
    assert (
        _map_questions_to_links(lesson, [{"order": 1, "srs_skip_reason": "두 고정 인사 표현을 함께 평가하여 단일 복습 항목이 없음"}]) == {}
    )
    with pytest.raises(LessonServiceError):
        _map_questions_to_links(lesson, [{"order": 1}])


async def test_invalid_mapping_uses_existing_http_error_envelope(client) -> None:
    from app.main import app

    lesson = _lesson()
    lesson.content_jsonb = {"questions": [{"order": 1, "type": "VOCAB_MCQ", "correct_answer": "a"}]}
    result = MagicMock()
    result.scalar_one_or_none.return_value = lesson
    db = AsyncMock()
    db.execute.return_value = result

    async def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    response = await client.post(f"/api/v1/lessons/{lesson.id}/submit", json={"answers": [{"order": 1, "selectedAnswer": "a"}]})

    assert response.status_code == 409
    assert response.json() == {"error": {"code": "SYSTEM_ERROR", "message": SRS_MAPPING_FAILURE_DETAIL, "details": None}}
    db.commit.assert_not_awaited()


def test_internal_target_metadata_does_not_change_client_question_schema() -> None:
    content = LessonContent.model_validate(
        {
            "reading": {"script": []},
            "questions": [
                {"order": 1, "type": "VOCAB_MCQ", "prompt": "학생", "vocabulary_id": str(uuid4())},
                {"order": 2, "type": "SENTENCE_REORDER", "prompt": "인사", "srs_skip_reason": "여러 인사 표현을 함께 평가함"},
            ],
        }
    )
    questions = content.model_dump(by_alias=True)["questions"]
    assert all("vocabularyId" not in question and "srsSkipReason" not in question for question in questions)
