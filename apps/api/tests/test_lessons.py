import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.db.session import get_db


class _AsyncNullContext:
    async def __aenter__(self):
        return None

    async def __aexit__(self, exc_type, exc, tb):
        return False


@pytest.mark.asyncio
async def test_get_chapters(client, mock_user):
    """Test GET /api/v1/lessons/chapters returns chapter summaries with progress."""
    from app.main import app

    chapter_id = uuid.uuid4()
    lesson_one_id = uuid.uuid4()
    lesson_two_id = uuid.uuid4()

    lesson_one = MagicMock()
    lesson_one.id = lesson_one_id
    lesson_one.lesson_no = 10
    lesson_one.chapter_lesson_no = 2
    lesson_one.title = "인사 응용"
    lesson_one.topic = "응용"
    lesson_one.estimated_minutes = 12
    lesson_one.is_published = True

    lesson_two = MagicMock()
    lesson_two.id = lesson_two_id
    lesson_two.lesson_no = 9
    lesson_two.chapter_lesson_no = 1
    lesson_two.title = "인사 기초"
    lesson_two.topic = "기초"
    lesson_two.estimated_minutes = 8
    lesson_two.is_published = True

    chapter = MagicMock()
    chapter.id = chapter_id
    chapter.jlpt_level = "N5"
    chapter.part_no = 1
    chapter.chapter_no = 1
    chapter.title = "첫 인사"
    chapter.topic = "일상"
    chapter.lessons = [lesson_one, lesson_two]

    chapter_scalars = MagicMock()
    chapter_scalars.unique.return_value.all.return_value = [chapter]
    chapter_result = MagicMock()
    chapter_result.scalars.return_value = chapter_scalars

    progress = MagicMock()
    progress.lesson_id = lesson_two_id
    progress.status = "COMPLETED"
    progress.score_correct = 4
    progress.score_total = 5

    progress_scalars = MagicMock()
    progress_scalars.all.return_value = [progress]
    progress_result = MagicMock()
    progress_result.scalars.return_value = progress_scalars

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(side_effect=[chapter_result, progress_result])

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/lessons/chapters", params={"jlptLevel": "N5"})
    assert response.status_code == 200

    assert response.json() == {
        "chapters": [
            {
                "id": str(chapter_id),
                "jlptLevel": "N5",
                "partNo": 1,
                "chapterNo": 1,
                "title": "첫 인사",
                "topic": "일상",
                "completedLessons": 1,
                "totalLessons": 2,
                "lessons": [
                    {
                        "id": str(lesson_two_id),
                        "lessonNo": 9,
                        "chapterLessonNo": 1,
                        "title": "인사 기초",
                        "topic": "기초",
                        "estimatedMinutes": 8,
                        "status": "COMPLETED",
                        "scoreCorrect": 4,
                        "scoreTotal": 5,
                    },
                    {
                        "id": str(lesson_one_id),
                        "lessonNo": 10,
                        "chapterLessonNo": 2,
                        "title": "인사 응용",
                        "topic": "응용",
                        "estimatedMinutes": 12,
                        "status": "NOT_STARTED",
                        "scoreCorrect": 0,
                        "scoreTotal": 0,
                    },
                ],
            }
        ]
    }


@pytest.mark.asyncio
async def test_get_review_summary(client, mock_user):
    """Test GET /api/v1/lessons/review/summary returns due and new counts."""
    from app.main import app

    def scalar_result(value: int) -> MagicMock:
        return MagicMock(scalar=MagicMock(return_value=value))

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(
        side_effect=[
            scalar_result(3),
            scalar_result(2),
            scalar_result(4),
            scalar_result(5),
            scalar_result(1),
            scalar_result(6),
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/lessons/review/summary", params={"jlptLevel": "N5"})
    assert response.status_code == 200
    assert response.json() == {
        "wordDue": 3,
        "grammarDue": 2,
        "totalDue": 5,
        "wordNew": 9,
        "grammarNew": 7,
    }


@pytest.mark.asyncio
async def test_get_lesson_detail(client, mock_user):
    """Test GET /api/v1/lessons/{lesson_id} strips answer keys and returns linked items."""
    from app.main import app

    lesson_id = uuid.uuid4()
    vocab_id = uuid.uuid4()
    grammar_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.id = lesson_id
    lesson.lesson_no = 11
    lesson.chapter_lesson_no = 2
    lesson.title = "카페 주문"
    lesson.topic = "카페"
    lesson.estimated_minutes = 15
    lesson.is_published = True
    lesson.content_jsonb = {
        "reading": {
            "type": "dialogue",
            "scene": "cafe",
            "script": [
                {
                    "speaker": "A",
                    "voice_id": "voice-a",
                    "text": "커피 한 잔 주세요.",
                    "translation": "커피 한 잔 주세요.",
                }
            ],
            "highlights": ["コーヒー"],
            "audio_url": None,
        },
        "questions": [
            {
                "order": 1,
                "type": "VOCAB_MCQ",
                "prompt": "コーヒー",
                "options": [{"id": "a", "text": "커피"}],
                "correct_answer": "a",
                "explanation": "커피를 뜻합니다.",
            },
            {
                "order": 2,
                "type": "SENTENCE_REORDER",
                "prompt": "문장을 순서대로 배열하세요.",
                "tokens": ["です", "学生", "私", "は"],
                "correct_order": ["私", "は", "学生", "です"],
            },
        ],
    }

    vocab_link = MagicMock()
    vocab_link.item_type = "WORD"
    vocab_link.vocabulary_id = vocab_id
    vocab_link.grammar_id = None
    vocab_link.item_order = 1

    grammar_link = MagicMock()
    grammar_link.item_type = "GRAMMAR"
    grammar_link.vocabulary_id = None
    grammar_link.grammar_id = grammar_id
    grammar_link.item_order = 2

    lesson.item_links = [grammar_link, vocab_link]

    lesson_result = MagicMock()
    lesson_result.scalar_one_or_none.return_value = lesson

    vocab = MagicMock()
    vocab.id = vocab_id
    vocab.word = "コーヒー"
    vocab.reading = "コーヒー"
    vocab.meaning_ko = "커피"
    vocab.part_of_speech = "NOUN"

    vocab_scalars = MagicMock()
    vocab_scalars.all.return_value = [vocab]
    vocab_result = MagicMock()
    vocab_result.scalars.return_value = vocab_scalars

    grammar = MagicMock()
    grammar.id = grammar_id
    grammar.pattern = "〜ください"
    grammar.meaning_ko = "~주세요"
    grammar.explanation = "정중한 요청 표현"

    grammar_scalars = MagicMock()
    grammar_scalars.all.return_value = [grammar]
    grammar_result = MagicMock()
    grammar_result.scalars.return_value = grammar_scalars

    progress = MagicMock()
    progress.status = "IN_PROGRESS"
    progress.attempts = 1
    progress.score_correct = 0
    progress.score_total = 0
    progress.started_at = datetime.now(UTC)
    progress.completed_at = None
    progress.srs_registered_at = None

    progress_result = MagicMock()
    progress_result.scalar_one_or_none.return_value = progress

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(
        side_effect=[
            lesson_result,
            vocab_result,
            grammar_result,
            progress_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get(f"/api/v1/lessons/{lesson_id}")
    assert response.status_code == 200

    data = response.json()
    assert data["id"] == str(lesson_id)
    assert data["vocabItems"] == [
        {
            "id": str(vocab_id),
            "word": "コーヒー",
            "reading": "コーヒー",
            "meaningKo": "커피",
            "partOfSpeech": "NOUN",
        }
    ]
    assert data["grammarItems"] == [
        {
            "id": str(grammar_id),
            "pattern": "〜ください",
            "meaningKo": "~주세요",
            "explanation": "정중한 요청 표현",
        }
    ]
    assert data["content"]["questions"][0]["correctAnswer"] is None
    assert data["content"]["questions"][1]["correctOrder"] is None
    assert data["progress"]["status"] == "IN_PROGRESS"


@pytest.mark.asyncio
async def test_start_lesson(client, mock_user):
    """Test POST /api/v1/lessons/{lesson_id}/start returns in-progress status."""
    from app.main import app

    lesson_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.is_published = True

    progress = MagicMock()
    progress.status = "IN_PROGRESS"
    progress.attempts = 0
    progress.score_correct = 0
    progress.score_total = 0
    progress.started_at = datetime.now(UTC)
    progress.completed_at = None
    progress.srs_registered_at = None

    progress_result = MagicMock()
    progress_result.scalar_one_or_none.return_value = progress

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=lesson)
    mock_session.execute = AsyncMock(return_value=progress_result)
    mock_session.commit = AsyncMock()
    mock_session.refresh = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(f"/api/v1/lessons/{lesson_id}/start")
    assert response.status_code == 200
    assert response.json()["status"] == "IN_PROGRESS"


@pytest.mark.asyncio
@patch("app.services.lesson_command.register_items_from_lesson", new_callable=AsyncMock)
@patch("app.services.lesson_command.process_answer", new_callable=AsyncMock)
async def test_submit_lesson(mock_process_answer, mock_register_items, client, mock_user):
    """Test POST /api/v1/lessons/{lesson_id}/submit returns graded results and progress."""
    from app.main import app

    lesson_id = uuid.uuid4()
    vocab_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.id = lesson_id
    lesson.content_jsonb = {
        "questions": [
            {
                "order": 1,
                "type": "VOCAB_MCQ",
                "correct_answer": "a",
                "explanation": "정답 설명",
            }
        ]
    }

    vocab_link = MagicMock()
    vocab_link.item_type = "WORD"
    vocab_link.vocabulary_id = vocab_id
    vocab_link.grammar_id = None
    vocab_link.item_order = 1
    lesson.item_links = [vocab_link]

    lesson_result = MagicMock()
    lesson_result.scalar_one_or_none.return_value = lesson

    progress = MagicMock()
    progress.attempts = 0
    progress.score_correct = 0
    progress.score_total = 0
    progress.status = "IN_PROGRESS"
    progress.srs_registered_at = None
    progress.completed_at = None

    progress_result = MagicMock()
    progress_result.scalar_one_or_none.return_value = progress

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(side_effect=[lesson_result, progress_result])
    mock_session.begin_nested = MagicMock(return_value=_AsyncNullContext())
    mock_session.commit = AsyncMock()

    mock_process_answer.return_value = {
        "state_before": "LEARNING",
        "state_after": "REVIEW",
        "next_review_at": "2026-04-18T00:00:00+00:00",
        "is_provisional_phase": False,
    }
    mock_register_items.return_value = 1

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        f"/api/v1/lessons/{lesson_id}/submit",
        json={
            "answers": [
                {
                    "order": 1,
                    "selectedAnswer": "a",
                    "responseMs": 1200,
                }
            ]
        },
    )
    assert response.status_code == 200
    assert response.json() == {
        "scoreCorrect": 1,
        "scoreTotal": 1,
        "results": [
            {
                "order": 1,
                "isCorrect": True,
                "correctAnswer": "a",
                "correctOrder": None,
                "explanation": "정답 설명",
                "stateBefore": "LEARNING",
                "stateAfter": "REVIEW",
                "nextReviewAt": "2026-04-18T00:00:00+00:00",
                "isProvisionalPhase": False,
            }
        ],
        "status": "COMPLETED",
        "srsItemsRegistered": 1,
    }
    assert progress.srs_registered_at is not None


@pytest.mark.asyncio
@patch("app.services.lesson_command.register_items_from_lesson", new_callable=AsyncMock)
@patch("app.services.lesson_command.process_answer", new_callable=AsyncMock)
async def test_submit_lesson_returns_500_when_srs_answer_processing_fails(
    mock_process_answer,
    mock_register_items,
    client,
    mock_user,
):
    """Test POST /api/v1/lessons/{lesson_id}/submit does not complete if SRS answer processing fails."""
    from app.main import app

    lesson_id = uuid.uuid4()
    vocab_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.id = lesson_id
    lesson.content_jsonb = {
        "questions": [
            {
                "order": 1,
                "type": "VOCAB_MCQ",
                "correct_answer": "a",
                "explanation": "정답 설명",
            }
        ]
    }

    vocab_link = MagicMock()
    vocab_link.item_type = "WORD"
    vocab_link.vocabulary_id = vocab_id
    vocab_link.grammar_id = None
    vocab_link.item_order = 1
    lesson.item_links = [vocab_link]

    lesson_result = MagicMock()
    lesson_result.scalar_one_or_none.return_value = lesson

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(return_value=lesson_result)
    mock_session.begin_nested = MagicMock(return_value=_AsyncNullContext())
    mock_session.commit = AsyncMock()

    mock_register_items.return_value = 1
    mock_process_answer.side_effect = RuntimeError("srs down")

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        f"/api/v1/lessons/{lesson_id}/submit",
        json={
            "answers": [
                {
                    "order": 1,
                    "selectedAnswer": "a",
                    "responseMs": 1200,
                }
            ]
        },
    )

    assert response.status_code == 500
    assert response.json() == {
        "error": {
            "code": "SYSTEM_ERROR",
            "message": "레슨 복습 상태 업데이트에 실패했습니다. 잠시 후 다시 시도해주세요",
            "details": None,
        }
    }
    mock_register_items.assert_called_once()
    mock_session.commit.assert_not_called()


@pytest.mark.asyncio
@patch("app.services.lesson_command.register_items_from_lesson", new_callable=AsyncMock)
@patch("app.services.lesson_command.process_answer", new_callable=AsyncMock)
async def test_submit_lesson_marks_srs_registered_when_items_already_exist(
    mock_process_answer,
    mock_register_items,
    client,
    mock_user,
):
    """Test POST /api/v1/lessons/{lesson_id}/submit records SRS linkage even when no new rows are created."""
    from app.main import app

    lesson_id = uuid.uuid4()
    vocab_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.id = lesson_id
    lesson.content_jsonb = {
        "questions": [
            {
                "order": 1,
                "type": "VOCAB_MCQ",
                "correct_answer": "a",
                "explanation": "정답 설명",
            }
        ]
    }

    vocab_link = MagicMock()
    vocab_link.item_type = "WORD"
    vocab_link.vocabulary_id = vocab_id
    vocab_link.grammar_id = None
    vocab_link.item_order = 1
    lesson.item_links = [vocab_link]

    lesson_result = MagicMock()
    lesson_result.scalar_one_or_none.return_value = lesson

    progress = MagicMock()
    progress.attempts = 1
    progress.score_correct = 0
    progress.score_total = 0
    progress.status = "IN_PROGRESS"
    progress.srs_registered_at = None
    progress.completed_at = None

    progress_result = MagicMock()
    progress_result.scalar_one_or_none.return_value = progress

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(side_effect=[lesson_result, progress_result])
    mock_session.begin_nested = MagicMock(return_value=_AsyncNullContext())
    mock_session.commit = AsyncMock()

    mock_register_items.return_value = 0
    mock_process_answer.return_value = {
        "state_before": "LEARNING",
        "state_after": "REVIEW",
        "next_review_at": "2026-04-18T00:00:00+00:00",
        "is_provisional_phase": False,
    }

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        f"/api/v1/lessons/{lesson_id}/submit",
        json={
            "answers": [
                {
                    "order": 1,
                    "selectedAnswer": "a",
                    "responseMs": 1200,
                }
            ]
        },
    )

    assert response.status_code == 200
    assert response.json()["srsItemsRegistered"] == 0
    assert progress.status == "COMPLETED"
    assert progress.srs_registered_at is not None


@pytest.mark.asyncio
@patch("app.services.lesson_command.register_items_from_lesson", new_callable=AsyncMock)
@patch("app.services.lesson_command.process_answer", new_callable=AsyncMock)
async def test_submit_lesson_returns_500_when_srs_registration_fails(
    mock_process_answer,
    mock_register_items,
    client,
    mock_user,
):
    """Test POST /api/v1/lessons/{lesson_id}/submit does not complete if SRS registration fails."""
    from app.main import app

    lesson_id = uuid.uuid4()
    vocab_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.id = lesson_id
    lesson.content_jsonb = {
        "questions": [
            {
                "order": 1,
                "type": "VOCAB_MCQ",
                "correct_answer": "a",
                "explanation": "정답 설명",
            }
        ]
    }

    vocab_link = MagicMock()
    vocab_link.item_type = "WORD"
    vocab_link.vocabulary_id = vocab_id
    vocab_link.grammar_id = None
    vocab_link.item_order = 1
    lesson.item_links = [vocab_link]

    lesson_result = MagicMock()
    lesson_result.scalar_one_or_none.return_value = lesson

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(return_value=lesson_result)
    mock_session.begin_nested = MagicMock(return_value=_AsyncNullContext())
    mock_session.commit = AsyncMock()

    mock_process_answer.return_value = {
        "state_before": "LEARNING",
        "state_after": "REVIEW",
        "next_review_at": "2026-04-18T00:00:00+00:00",
        "is_provisional_phase": False,
    }
    mock_register_items.side_effect = RuntimeError("registration down")

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        f"/api/v1/lessons/{lesson_id}/submit",
        json={
            "answers": [
                {
                    "order": 1,
                    "selectedAnswer": "a",
                    "responseMs": 1200,
                }
            ]
        },
    )

    assert response.status_code == 500
    assert response.json() == {
        "error": {
            "code": "SYSTEM_ERROR",
            "message": "레슨 복습 카드 등록에 실패했습니다. 잠시 후 다시 시도해주세요",
            "details": None,
        }
    }
    mock_session.commit.assert_not_called()
    mock_process_answer.assert_not_called()


@pytest.mark.asyncio
async def test_submit_lesson_rejects_partial_answers(client, mock_user):
    """Test POST /api/v1/lessons/{lesson_id}/submit rejects incomplete answer sets."""
    from app.main import app

    lesson_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.id = lesson_id
    lesson.content_jsonb = {
        "questions": [
            {"order": 1, "type": "VOCAB_MCQ", "correct_answer": "a"},
            {"order": 2, "type": "CONTEXT_CLOZE", "correct_answer": "b"},
        ]
    }
    lesson.item_links = []

    lesson_result = MagicMock()
    lesson_result.scalar_one_or_none.return_value = lesson

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(return_value=lesson_result)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        f"/api/v1/lessons/{lesson_id}/submit",
        json={
            "answers": [
                {
                    "order": 1,
                    "selectedAnswer": "a",
                    "responseMs": 800,
                }
            ]
        },
    )

    assert response.status_code == 400
    assert response.json() == {
        "error": {
            "code": "VALIDATION_ERROR",
            "message": "모든 레슨 문항에 답변해야 제출할 수 있습니다",
            "details": None,
        }
    }
    mock_session.commit.assert_not_called()


@pytest.mark.asyncio
async def test_submit_lesson_rejects_duplicate_orders(client, mock_user):
    """Test POST /api/v1/lessons/{lesson_id}/submit rejects duplicate answers."""
    from app.main import app

    lesson_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.id = lesson_id
    lesson.content_jsonb = {
        "questions": [
            {"order": 1, "type": "VOCAB_MCQ", "correct_answer": "a"},
            {"order": 2, "type": "CONTEXT_CLOZE", "correct_answer": "b"},
        ]
    }
    lesson.item_links = []

    lesson_result = MagicMock()
    lesson_result.scalar_one_or_none.return_value = lesson

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(return_value=lesson_result)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        f"/api/v1/lessons/{lesson_id}/submit",
        json={
            "answers": [
                {"order": 1, "selectedAnswer": "a", "responseMs": 800},
                {"order": 1, "selectedAnswer": "a", "responseMs": 900},
            ]
        },
    )

    assert response.status_code == 400
    assert response.json() == {
        "error": {
            "code": "VALIDATION_ERROR",
            "message": "중복된 문항 답변은 제출할 수 없습니다",
            "details": None,
        }
    }
    mock_session.commit.assert_not_called()


@pytest.mark.asyncio
async def test_submit_lesson_rejects_invalid_payload_for_question_type(client, mock_user):
    """Test POST /api/v1/lessons/{lesson_id}/submit validates per-question answer shape."""
    from app.main import app

    lesson_id = uuid.uuid4()

    lesson = MagicMock()
    lesson.id = lesson_id
    lesson.content_jsonb = {
        "questions": [
            {
                "order": 1,
                "type": "SENTENCE_REORDER",
                "correct_order": ["私", "は", "学生", "です"],
            }
        ]
    }
    lesson.item_links = []

    lesson_result = MagicMock()
    lesson_result.scalar_one_or_none.return_value = lesson

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(return_value=lesson_result)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        f"/api/v1/lessons/{lesson_id}/submit",
        json={
            "answers": [
                {
                    "order": 1,
                    "selectedAnswer": "a",
                    "responseMs": 1200,
                }
            ]
        },
    )

    assert response.status_code == 400
    assert response.json() == {
        "error": {
            "code": "VALIDATION_ERROR",
            "message": "1번 문항의 배열 답안이 필요합니다",
            "details": None,
        }
    }
    mock_session.commit.assert_not_called()
