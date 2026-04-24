import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.db.session import get_db
from app.models import Conversation
from app.models.enums import ConversationType


@pytest.fixture
def mock_conversation(test_user_id):
    conv = MagicMock(spec=Conversation)
    conv.id = uuid.uuid4()
    conv.user_id = test_user_id
    conv.messages = [
        {"role": "system", "content": "system prompt"},
        {"role": "assistant", "content": "こんにちは"},
    ]
    conv.message_count = 1
    conv.ended_at = None
    conv.feedback_summary = None
    conv.created_at = datetime.now(UTC)
    conv.type = ConversationType.TEXT
    conv.scenario_id = None
    conv.character_id = None
    return conv


@pytest.mark.asyncio
@patch("app.services.chat_session.rate_limit")
@patch("app.services.chat_session.check_ai_limit")
@patch("app.services.chat_session.generate_chat_response")
async def test_start_chat_success(mock_generate, mock_ai_limit, mock_rate_limit, client, mock_user):
    """Test POST /api/v1/chat/start successfully starts a conversation."""
    from app.main import app

    mock_ai_limit.return_value = {"allowed": True}
    mock_rate_limit.return_value = MagicMock(success=True, remaining=10, reset=0)
    mock_generate.return_value = {
        "messageJa": "こんにちは！",
        "messageKo": "안녕하세요!",
        "hint": "인사를 해보세요",
    }

    mock_session = AsyncMock()
    mock_session.flush = AsyncMock()

    # Make db.add capture the conversation so we can set its id
    added_objects = []

    def capture_add(obj):
        obj.id = uuid.uuid4()
        added_objects.append(obj)

    mock_session.add = capture_add

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/chat/start",
        json={"type": "TEXT"},
    )
    assert response.status_code == 200

    data = response.json()
    assert "conversationId" in data
    assert data["firstMessage"]["messageJa"] == "こんにちは！"
    assert data["firstMessage"]["messageKo"] == "안녕하세요!"


@pytest.mark.asyncio
@patch("app.services.chat_session.generate_chat_response")
async def test_send_message_success(mock_generate, client, mock_user, mock_conversation, test_user_id):
    """Test POST /api/v1/chat/message sends a message and returns AI response."""
    from app.main import app

    mock_generate.return_value = {
        "messageJa": "元気ですか？",
        "messageKo": "잘 지내세요?",
        "feedback": [{"type": "grammar", "text": "좋아요"}],
        "hint": None,
        "newVocabulary": None,
    }

    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_conversation
    mock_session.execute = AsyncMock(return_value=mock_result)
    mock_session.flush = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/chat/message",
        json={
            "conversationId": str(mock_conversation.id),
            "message": "こんにちは",
        },
    )
    assert response.status_code == 200

    data = response.json()
    assert data["messageJa"] == "元気ですか？"
    assert data["messageKo"] == "잘 지내세요?"
    assert data["feedback"] == [{"type": "grammar", "text": "좋아요"}]


@pytest.mark.asyncio
async def test_send_message_conversation_not_found(client, mock_user, test_user_id):
    """Test POST /api/v1/chat/message returns 404 when conversation not found."""
    from app.main import app

    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_session.execute = AsyncMock(return_value=mock_result)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/chat/message",
        json={
            "conversationId": str(uuid.uuid4()),
            "message": "こんにちは",
        },
    )
    assert response.status_code == 404
    assert response.json()["error"]["message"] == "대화를 찾을 수 없습니다"


@pytest.mark.asyncio
@patch("app.services.conversation_rewards.REWARDS", MagicMock(CONVERSATION_COMPLETE_XP=20))
@patch("app.services.conversation_rewards.check_and_grant_achievements")
@patch("app.services.conversation_rewards.track_ai_usage")
@patch("app.services.chat_session.generate_feedback_summary")
async def test_end_chat_success(mock_feedback, mock_track, mock_achievements, client, mock_user, mock_conversation, test_user_id):
    """Test POST /api/v1/chat/end ends conversation and awards XP."""
    from app.main import app

    mock_feedback.return_value = {"overallScore": 85, "summary": "잘했어요!"}
    mock_track.return_value = None
    mock_achievements.return_value = [{"title": "첫 대화", "body": "첫 AI 대화를 완료했어요!"}]

    mock_session = AsyncMock()

    # First execute: select conversation
    mock_conv_result = MagicMock()
    mock_conv_result.scalar_one_or_none.return_value = mock_conversation

    # Second execute: update User XP
    mock_update_result = MagicMock()

    # Third execute: db.refresh(user) - need to handle this
    mock_session.refresh = AsyncMock()

    # Fourth execute: insert DailyProgress (upsert)
    mock_daily_result = MagicMock()

    # Fifth execute: count conversations
    mock_count_result = MagicMock()
    mock_count_result.scalar.return_value = 1

    mock_session.execute = AsyncMock(
        side_effect=[
            mock_conv_result,
            mock_update_result,
            mock_daily_result,
            mock_count_result,
        ]
    )
    mock_session.commit = AsyncMock()
    mock_session.add = MagicMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/chat/end",
        json={"conversationId": str(mock_conversation.id)},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["success"] is True
    assert data["feedbackSummary"] is not None
    assert data["xpEarned"] > 0
    assert len(data["events"]) == 1


@pytest.mark.asyncio
async def test_end_chat_already_ended(client, mock_user, mock_conversation, test_user_id):
    """Test POST /api/v1/chat/end returns success with 0 XP for already ended conversation."""
    from app.main import app

    mock_conversation.ended_at = datetime.now(UTC)
    mock_conversation.feedback_summary = {"overallScore": 80}

    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_conversation
    mock_session.execute = AsyncMock(return_value=mock_result)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/chat/end",
        json={"conversationId": str(mock_conversation.id)},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["success"] is True
    assert data["xpEarned"] == 0
    assert data["events"] == []


@pytest.mark.asyncio
@patch("app.services.chat_voice.rate_limit")
@patch("app.services.chat_voice.generate_tts")
async def test_tts_success(mock_tts, mock_rate_limit, client, mock_user):
    """Test POST /api/v1/chat/tts returns audio bytes."""
    mock_rate_limit.return_value = MagicMock(success=True, remaining=10, reset=0)
    mock_tts.return_value = MagicMock(audio=b"\x00\x01\x02\x03", provider="gemini", model="test")

    response = await client.post(
        "/api/v1/chat/tts",
        json={"text": "こんにちは"},
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "audio/mpeg"
    assert response.content == b"\x00\x01\x02\x03"
    mock_tts.assert_awaited_once_with("こんにちは", voice="Kore")


@pytest.mark.asyncio
@patch("app.services.chat_voice.transcribe_audio")
async def test_transcribe_success(mock_transcribe, client, mock_user):
    """Test POST /api/v1/chat/voice/transcribe returns transcription."""
    mock_transcribe.return_value = "こんにちは"

    response = await client.post(
        "/api/v1/chat/voice/transcribe",
        files={"file": ("audio.webm", b"\x00" * 100, "audio/webm")},
    )
    assert response.status_code == 200
    assert response.json()["transcription"] == "こんにちは"


@pytest.mark.asyncio
async def test_transcribe_file_too_large(client, mock_user):
    """Test POST /api/v1/chat/voice/transcribe rejects files over 4.5MB."""
    large_audio = b"\x00" * 5_000_000  # 5MB > 4.5MB limit

    response = await client.post(
        "/api/v1/chat/voice/transcribe",
        files={"file": ("audio.webm", large_audio, "audio/webm")},
    )
    assert response.status_code == 400
    assert "4.5MB" in response.json()["error"]["message"]


@pytest.mark.asyncio
@patch("app.services.chat_voice.generate_live_token")
@patch("app.services.chat_voice.check_ai_limit")
@patch("app.services.chat_voice.rate_limit")
async def test_live_token_success(mock_rate_limit, mock_ai_limit, mock_generate_token, client, mock_user):
    """Test POST /api/v1/chat/live-token returns Live API token data."""
    mock_rate_limit.return_value = MagicMock(success=True, remaining=10, reset=0)
    mock_ai_limit.return_value = {"allowed": True}
    mock_generate_token.return_value = {
        "token": "test-token",
        "wsUri": "wss://example.test/live",
        "model": "models/test",
    }

    response = await client.post("/api/v1/chat/live-token", json={})

    assert response.status_code == 200
    assert response.json() == {
        "token": "test-token",
        "wsUri": "wss://example.test/live",
        "model": "models/test",
    }


@pytest.mark.asyncio
@patch("app.services.conversation_rewards.REWARDS", MagicMock(CONVERSATION_COMPLETE_XP=20))
@patch("app.services.conversation_rewards.check_and_grant_achievements")
@patch("app.services.conversation_rewards.track_ai_usage")
@patch("app.services.chat_voice.generate_live_feedback")
async def test_live_feedback_creates_voice_conversation(
    mock_feedback,
    mock_track,
    mock_achievements,
    client,
    mock_user,
):
    """Test POST /api/v1/chat/live-feedback stores a voice conversation and awards XP."""
    from app.main import app

    mock_feedback.return_value = {"overallScore": 90, "summary": "좋아요"}
    mock_track.return_value = None
    mock_achievements.return_value = []

    added_conversations = []

    def capture_add(obj):
        if isinstance(obj, Conversation):
            obj.id = uuid.uuid4()
            added_conversations.append(obj)

    mock_count_result = MagicMock()
    mock_count_result.scalar.return_value = 1

    mock_session = AsyncMock()
    mock_session.add = MagicMock(side_effect=capture_add)
    mock_session.flush = AsyncMock()
    mock_session.refresh = AsyncMock()
    mock_session.execute = AsyncMock(side_effect=[MagicMock(), MagicMock(), mock_count_result])
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/chat/live-feedback",
        json={
            "durationSeconds": 120,
            "transcript": [
                {"role": "user", "text": "こんにちは"},
                {"role": "assistant", "text": "こんにちは！"},
            ],
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["feedbackSummary"] == {"overallScore": 90, "summary": "좋아요"}
    assert data["xpEarned"] == 20
    assert data["events"] == []
    assert len(added_conversations) == 1
    assert added_conversations[0].type == ConversationType.VOICE


@pytest.mark.asyncio
@patch("app.services.chat_voice.grant_conversation_completion_rewards")
@patch("app.services.chat_voice.generate_live_feedback")
async def test_live_feedback_returns_500_when_commit_fails(
    mock_feedback,
    mock_rewards,
    client,
    mock_user,
):
    from app.main import app

    mock_feedback.return_value = {"overallScore": 90, "summary": "좋아요"}
    mock_rewards.return_value = MagicMock(xp_earned=20, events=[])

    added_conversations = []

    def capture_add(obj):
        if isinstance(obj, Conversation):
            obj.id = uuid.uuid4()
            added_conversations.append(obj)

    mock_session = MagicMock()
    mock_session.add = MagicMock(side_effect=capture_add)
    mock_session.flush = AsyncMock()
    mock_session.commit = AsyncMock(side_effect=RuntimeError("commit failed"))
    mock_session.rollback = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/chat/live-feedback",
        json={
            "durationSeconds": 120,
            "transcript": [
                {"role": "user", "text": "こんにちは"},
                {"role": "assistant", "text": "こんにちは！"},
            ],
        },
    )

    assert response.status_code == 500
    assert response.json()["error"]["message"] == "라이브 피드백 저장에 실패했습니다"
    assert len(added_conversations) == 1
    mock_session.rollback.assert_awaited_once()


@pytest.mark.asyncio
@patch("app.services.chat_voice.grant_conversation_completion_rewards")
@patch("app.services.chat_voice.generate_live_feedback")
async def test_live_feedback_returns_500_when_fallback_save_fails(
    mock_feedback,
    mock_rewards,
    client,
    mock_user,
):
    from app.main import app

    mock_feedback.return_value = {"overallScore": 90, "summary": "좋아요"}
    mock_rewards.side_effect = RuntimeError("gamification failed")

    added_conversations = []

    def capture_add(obj):
        if isinstance(obj, Conversation):
            obj.id = uuid.uuid4()
            added_conversations.append(obj)

    mock_session = MagicMock()
    mock_session.add = MagicMock(side_effect=capture_add)
    mock_session.flush = AsyncMock()
    mock_session.commit = AsyncMock(side_effect=RuntimeError("fallback commit failed"))
    mock_session.rollback = AsyncMock()
    mock_session.__contains__.return_value = False

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/chat/live-feedback",
        json={
            "durationSeconds": 120,
            "transcript": [
                {"role": "user", "text": "こんにちは"},
                {"role": "assistant", "text": "こんにちは！"},
            ],
        },
    )

    assert response.status_code == 500
    assert response.json()["error"]["message"] == "라이브 피드백 저장에 실패했습니다"
    assert len(added_conversations) == 2
    assert added_conversations[0] is added_conversations[1]
    assert mock_session.rollback.await_count == 2
