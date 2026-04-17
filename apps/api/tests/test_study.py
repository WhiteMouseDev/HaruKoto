import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.db.session import get_db


@pytest.mark.asyncio
async def test_get_learned_words(client, mock_user, test_user_id):
    """Test GET /api/v1/study/learned-words returns paginated learned entries."""
    from app.main import app

    mock_progress = MagicMock()
    mock_progress.id = uuid.uuid4()
    mock_progress.correct_count = 7
    mock_progress.incorrect_count = 2
    mock_progress.streak = 3
    mock_progress.mastered = False
    mock_progress.last_reviewed_at = None

    mock_vocab = MagicMock()
    mock_vocab.id = uuid.uuid4()
    mock_vocab.word = "食べる"
    mock_vocab.reading = "たべる"
    mock_vocab.meaning_ko = "먹다"
    mock_vocab.jlpt_level = "N5"
    mock_vocab.example_sentence = "ごはんを食べる。"
    mock_vocab.example_translation = "밥을 먹다."

    rows_result = MagicMock()
    rows_result.all.return_value = [(mock_progress, mock_vocab)]

    total_result = MagicMock()
    total_result.scalar.return_value = 1

    total_learned_result = MagicMock()
    total_learned_result.scalar.return_value = 4

    mastered_result = MagicMock()
    mastered_result.scalar.return_value = 1

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(
        side_effect=[
            total_result,
            rows_result,
            total_learned_result,
            mastered_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/study/learned-words")
    assert response.status_code == 200

    data = response.json()
    assert data["total"] == 1
    assert data["page"] == 1
    assert data["totalPages"] == 1
    assert data["summary"] == {
        "totalLearned": 4,
        "mastered": 1,
        "learning": 3,
    }
    assert data["entries"] == [
        {
            "id": str(mock_progress.id),
            "vocabularyId": str(mock_vocab.id),
            "word": "食べる",
            "reading": "たべる",
            "meaningKo": "먹다",
            "jlptLevel": "N5",
            "exampleSentence": "ごはんを食べる。",
            "exampleTranslation": "밥을 먹다.",
            "correctCount": 7,
            "incorrectCount": 2,
            "streak": 3,
            "mastered": False,
            "lastReviewedAt": None,
        }
    ]


@pytest.mark.asyncio
async def test_get_study_wrong_answers(client, mock_user, test_user_id):
    """Test GET /api/v1/study/wrong-answers returns paginated wrong answer entries."""
    from app.main import app

    mock_progress = MagicMock()
    mock_progress.id = uuid.uuid4()
    mock_progress.correct_count = 2
    mock_progress.incorrect_count = 5
    mock_progress.mastered = True
    mock_progress.last_reviewed_at = None

    mock_vocab = MagicMock()
    mock_vocab.id = uuid.uuid4()
    mock_vocab.word = "飲む"
    mock_vocab.reading = "のむ"
    mock_vocab.meaning_ko = "마시다"
    mock_vocab.jlpt_level = "N4"
    mock_vocab.example_sentence = "水を飲む。"
    mock_vocab.example_translation = "물을 마시다."

    rows_result = MagicMock()
    rows_result.all.return_value = [(mock_progress, mock_vocab)]

    total_result = MagicMock()
    total_result.scalar.return_value = 1

    total_wrong_result = MagicMock()
    total_wrong_result.scalar.return_value = 6

    mastered_wrong_result = MagicMock()
    mastered_wrong_result.scalar.return_value = 2

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(
        side_effect=[
            total_result,
            rows_result,
            total_wrong_result,
            mastered_wrong_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/study/wrong-answers")
    assert response.status_code == 200

    data = response.json()
    assert data["total"] == 1
    assert data["page"] == 1
    assert data["totalPages"] == 1
    assert data["summary"] == {
        "totalWrong": 6,
        "mastered": 2,
        "remaining": 4,
    }
    assert data["entries"] == [
        {
            "id": str(mock_progress.id),
            "vocabularyId": str(mock_vocab.id),
            "word": "飲む",
            "reading": "のむ",
            "meaningKo": "마시다",
            "jlptLevel": "N4",
            "exampleSentence": "水を飲む。",
            "exampleTranslation": "물을 마시다.",
            "correctCount": 2,
            "incorrectCount": 5,
            "mastered": True,
            "lastReviewedAt": None,
        }
    ]


@pytest.mark.asyncio
async def test_get_stages(client, mock_user, test_user_id):
    """Test GET /api/v1/study/stages returns typed stage entries with progress."""
    from app.main import app

    stage_one_id = uuid.uuid4()
    stage_two_id = uuid.uuid4()

    stage_one = MagicMock()
    stage_one.id = stage_one_id
    stage_one.category = "VOCABULARY"
    stage_one.jlpt_level = "N5"
    stage_one.stage_number = 1
    stage_one.title = "기초 단어"
    stage_one.description = "N5 핵심 단어"
    stage_one.content_ids = [str(uuid.uuid4()), str(uuid.uuid4())]
    stage_one.unlock_after = None

    stage_two = MagicMock()
    stage_two.id = stage_two_id
    stage_two.category = "VOCABULARY"
    stage_two.jlpt_level = "N5"
    stage_two.stage_number = 2
    stage_two.title = "확장 단어"
    stage_two.description = None
    stage_two.content_ids = [str(uuid.uuid4())]
    stage_two.unlock_after = stage_one_id

    stages_scalars = MagicMock()
    stages_scalars.all.return_value = [stage_one, stage_two]
    stages_result = MagicMock()
    stages_result.scalars.return_value = stages_scalars

    stage_progress = MagicMock()
    stage_progress.stage_id = stage_one_id
    stage_progress.best_score = 95
    stage_progress.attempts = 3
    stage_progress.completed = True
    stage_progress.completed_at = None
    stage_progress.last_attempted_at = None

    progress_scalars = MagicMock()
    progress_scalars.all.return_value = [stage_progress]
    progress_result = MagicMock()
    progress_result.scalars.return_value = progress_scalars

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(
        side_effect=[
            stages_result,
            progress_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get(
        "/api/v1/study/stages",
        params={"category": "VOCABULARY", "jlptLevel": "N5"},
    )
    assert response.status_code == 200

    assert response.json() == [
        {
            "id": str(stage_one_id),
            "category": "VOCABULARY",
            "jlptLevel": "N5",
            "stageNumber": 1,
            "title": "기초 단어",
            "description": "N5 핵심 단어",
            "contentCount": 2,
            "isLocked": False,
            "userProgress": {
                "bestScore": 95,
                "attempts": 3,
                "completed": True,
                "completedAt": None,
                "lastAttemptedAt": None,
            },
        },
        {
            "id": str(stage_two_id),
            "category": "VOCABULARY",
            "jlptLevel": "N5",
            "stageNumber": 2,
            "title": "확장 단어",
            "description": None,
            "contentCount": 1,
            "isLocked": False,
            "userProgress": None,
        },
    ]


@pytest.mark.asyncio
async def test_get_capabilities(client, mock_user, test_user_id):
    """Test GET /api/v1/study/capabilities returns stable capability keys."""
    from app.main import app

    def count_result(value: int) -> MagicMock:
        return MagicMock(scalar_one=MagicMock(return_value=value))

    stage_result = MagicMock()
    stage_result.all.return_value = [
        ("VOCABULARY", 4),
        ("GRAMMAR", 2),
    ]

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(
        side_effect=[
            count_result(12),
            count_result(5),
            count_result(0),
            count_result(3),
            count_result(7),
            count_result(1),
            count_result(2),
            stage_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get(
        "/api/v1/study/capabilities",
        params={"jlptLevel": "N4"},
    )
    assert response.status_code == 200

    assert response.json() == {
        "requestedJlptLevel": "N4",
        "effectiveJlptLevel": "N4",
        "quiz": {
            "VOCABULARY": True,
            "GRAMMAR": True,
            "KANJI": False,
            "LISTENING": False,
            "KANA": True,
            "CLOZE": False,
            "SENTENCE_ARRANGE": True,
        },
        "smart": {
            "VOCABULARY": {
                "available": True,
                "hasPool": True,
            },
            "GRAMMAR": {
                "available": True,
                "hasPool": True,
            },
        },
        "lesson": True,
        "stage": {
            "VOCABULARY": True,
            "GRAMMAR": True,
            "SENTENCE": False,
        },
    }
