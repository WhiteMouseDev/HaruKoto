import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.db.session import get_db
from app.models.enums import KanaType


@pytest.fixture
def mock_kana_char():
    char = MagicMock()
    char.id = uuid.uuid4()
    char.kana_type = KanaType.HIRAGANA
    char.character = "あ"
    char.romaji = "a"
    char.pronunciation = "a"
    char.row = "a"
    char.column = 1
    char.stroke_count = 3
    char.stroke_order = ["1", "2", "3"]
    char.audio_url = None
    char.example_word = "あめ"
    char.example_reading = "ame"
    char.example_meaning = "비"
    char.category = "basic"
    char.order = 1
    return char


@pytest.fixture
def mock_kana_stage():
    stage = MagicMock()
    stage.id = uuid.uuid4()
    stage.kana_type = KanaType.HIRAGANA
    stage.stage_number = 1
    stage.title = "기본 모음"
    stage.description = "あいうえお를 배워봅시다"
    stage.characters = ["あ", "い", "う", "え", "お"]
    stage.order = 1
    return stage


@pytest.mark.asyncio
async def test_get_kana_characters(client, mock_kana_char):
    """Test GET /api/v1/kana/characters returns kana character list."""
    from app.main import app

    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = [mock_kana_char]
    mock_session.execute = AsyncMock(return_value=mock_result)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/kana/characters")
    assert response.status_code == 200

    data = response.json()
    assert len(data) == 1
    assert data[0]["character"] == "あ"
    assert data[0]["romaji"] == "a"
    assert data[0]["kanaType"] == "HIRAGANA"


@pytest.mark.asyncio
async def test_get_kana_stages(client, mock_user, mock_kana_stage):
    """Test GET /api/v1/kana/stages returns learning stages with user progress."""
    from app.main import app

    mock_session = AsyncMock()

    # First execute: select stages
    mock_stages_result = MagicMock()
    mock_stages_result.scalars.return_value.all.return_value = [mock_kana_stage]

    # Second execute: select user stage progress
    mock_progress_result = MagicMock()
    mock_progress_result.scalars.return_value.all.return_value = []

    mock_session.execute = AsyncMock(side_effect=[mock_stages_result, mock_progress_result])

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/kana/stages")
    assert response.status_code == 200

    data = response.json()
    assert len(data) == 1
    assert data[0]["stageNumber"] == 1
    assert data[0]["title"] == "기본 모음"
    # Stage 1 should be unlocked by default
    assert data[0]["isUnlocked"] is True
    assert data[0]["isCompleted"] is False


@pytest.mark.asyncio
async def test_start_kana_quiz(client, mock_user, mock_kana_char, mock_kana_stage):
    """Test POST /api/v1/kana/quiz/start creates a kana quiz session."""
    from app.main import app

    mock_session = AsyncMock()

    # First execute: select stages
    mock_stages_result = MagicMock()
    mock_stages_result.scalars.return_value.all.return_value = [mock_kana_stage]

    # Second execute: select characters
    char2 = MagicMock()
    char2.id = uuid.uuid4()
    char2.character = "い"
    char2.romaji = "i"

    mock_chars_result = MagicMock()
    mock_chars_result.scalars.return_value.all.return_value = [mock_kana_char, char2]

    mock_session.execute = AsyncMock(side_effect=[mock_stages_result, mock_chars_result])
    mock_session.add = MagicMock()
    mock_session.commit = AsyncMock()

    async def mock_refresh(obj):
        obj.id = uuid.uuid4()

    mock_session.refresh = mock_refresh

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/kana/quiz/start",
        json={
            "kanaType": "HIRAGANA",
            "stageNumber": 1,
            "quizMode": "recognition",
            "count": 2,
        },
    )
    assert response.status_code == 200

    data = response.json()
    assert "sessionId" in data
    assert data["totalQuestions"] >= 1
    assert len(data["questions"]) >= 1


@pytest.mark.asyncio
async def test_answer_kana_quiz(client, mock_user, test_user_id):
    """Test POST /api/v1/kana/quiz/answer checks answer correctness."""
    from app.main import app

    question_id = uuid.uuid4()
    session_id = uuid.uuid4()

    mock_quiz = MagicMock()
    mock_quiz.id = session_id
    mock_quiz.user_id = test_user_id
    mock_quiz.questions_data = [
        {
            "id": str(question_id),
            "question": "あ",
            "options": [
                {"id": "opt-correct", "text": "a"},
                {"id": "opt-wrong", "text": "i"},
            ],
            "correctOptionId": "opt-correct",
        }
    ]
    mock_quiz.correct_count = 0

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_quiz)
    mock_session.execute = AsyncMock(return_value=MagicMock())
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/kana/quiz/answer",
        json={
            "sessionId": str(session_id),
            "questionId": str(question_id),
            "selectedOptionId": "opt-correct",
        },
    )
    assert response.status_code == 200

    data = response.json()
    assert data["isCorrect"] is True
    assert data["correctOptionId"] == "opt-correct"


@pytest.mark.asyncio
async def test_update_kana_progress(client, mock_user, test_user_id):
    """Test POST /api/v1/kana/progress records learning progress."""
    from app.main import app

    mock_session = AsyncMock()
    mock_session.execute = AsyncMock(return_value=MagicMock())
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    kana_id = str(uuid.uuid4())
    response = await client.post(
        "/api/v1/kana/progress",
        json={"kanaId": kana_id},
    )
    assert response.status_code == 200
    assert response.json()["ok"] is True


@pytest.mark.asyncio
async def test_update_kana_progress_missing_kana_id(client, mock_user):
    """Test POST /api/v1/kana/progress returns 422 when kanaId is missing."""
    response = await client.post(
        "/api/v1/kana/progress",
        json={},
    )
    assert response.status_code == 422
