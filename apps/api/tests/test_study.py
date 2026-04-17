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
