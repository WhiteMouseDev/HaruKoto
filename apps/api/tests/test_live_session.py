import asyncio
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from pydantic import ValidationError

from app.models import AiCharacter, Conversation, ConversationScenario
from app.models.enums import ConversationType
from app.schemas.chat import LiveFeedbackRequest, LiveSessionRequest, LiveTokenRequest
from app.schemas.wordbook import WordbookCreateRequest
from app.services.chat_live_session import create_live_session, validate_live_context
from app.services.chat_voice import create_live_token
from app.services.chat_voice_errors import ChatVoiceServiceError
from app.services.conversation_rewards import _count_completed_conversations


@pytest.fixture
def session(mock_user):
    return Conversation(
        id=uuid.uuid4(), user_id=mock_user.id, type=ConversationType.VOICE, scenario_id=None, character_id=None, messages=[], ended_at=None
    )


@pytest.mark.asyncio
async def test_repeated_create_returns_the_same_session_even_after_completion(mock_user, session):
    session.ended_at = datetime.now(UTC)
    db = AsyncMock()
    db.get.return_value = session
    with patch("app.services.chat_live_session.check_ai_limit", new_callable=AsyncMock) as limits:
        result = await create_live_session(db, mock_user, LiveSessionRequest(conversationId=session.id))
    assert result.conversation_id == session.id
    assert result.ended_at == session.ended_at
    limits.assert_not_awaited()
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("field", ["scenario_id", "character_id"])
async def test_same_id_cannot_change_context(mock_user, session, field):
    db = AsyncMock()
    db.get.return_value = session
    with pytest.raises(ChatVoiceServiceError) as error:
        await create_live_session(db, mock_user, LiveSessionRequest(conversation_id=session.id, **{field: uuid.uuid4()}))
    assert error.value.status_code == 409
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_other_users_session_is_not_exposed(mock_user, session):
    session.user_id = uuid.uuid4()
    db = AsyncMock()
    db.get.return_value = session
    with pytest.raises(ChatVoiceServiceError) as error:
        await create_live_session(db, mock_user, LiveSessionRequest(conversationId=session.id))
    assert error.value.status_code == 404
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_locked_character_cannot_start_voice_session(mock_user):
    character = AiCharacter(id=uuid.uuid4(), is_active=True, is_default=False)
    db = AsyncMock()
    db.get.return_value = character
    db.scalar.return_value = None
    with pytest.raises(ChatVoiceServiceError) as error:
        await validate_live_context(db, mock_user.id, scenario_id=None, character_id=character.id)
    assert error.value.status_code == 403


@pytest.mark.asyncio
async def test_unlocked_character_can_start_voice_session(mock_user):
    character = AiCharacter(id=uuid.uuid4(), is_active=True, is_default=False)
    db = AsyncMock()
    db.get.return_value = character
    db.scalar.return_value = uuid.uuid4()
    assert await validate_live_context(db, mock_user.id, scenario_id=None, character_id=character.id) is None


@pytest.mark.asyncio
async def test_token_uses_persisted_context_and_echoes_session_id(mock_user, session):
    scenario = ConversationScenario(
        id=uuid.uuid4(), title="호텔", situation="체크인", your_role="투숙객", ai_role="직원", key_expressions=[], is_active=True
    )
    session.scenario_id = scenario.id
    db = AsyncMock()
    db.get.return_value = scenario
    result = MagicMock()
    result.scalar_one_or_none.return_value = session
    db.execute.return_value = result
    with (
        patch("app.services.chat_voice.rate_limit", return_value=MagicMock(success=True)),
        patch("app.services.chat_voice.check_ai_limit", return_value={"allowed": True}),
        patch("app.services.chat_voice.generate_live_token", return_value={"token": "test", "wsUri": "wss://test", "model": "test"}),
    ):
        token = await create_live_token(db, mock_user, LiveTokenRequest(conversationId=session.id))
    assert token.conversation_id == session.id
    assert "체크인" in token.system_instruction


@pytest.mark.asyncio
@pytest.mark.parametrize("ended", [True, False])
async def test_token_rejects_completed_or_conflicting_session(mock_user, session, ended):
    if ended:
        session.ended_at = datetime.now(UTC)
    db = AsyncMock()
    result = MagicMock()
    result.scalar_one_or_none.return_value = session
    db.execute.return_value = result
    with (
        patch("app.services.chat_voice.rate_limit", return_value=MagicMock(success=True)),
        patch("app.services.chat_voice.check_ai_limit", return_value={"allowed": True}),
        patch("app.services.chat_voice.generate_live_token", new_callable=AsyncMock) as generate,
        pytest.raises(ChatVoiceServiceError) as error,
    ):
        await create_live_token(db, mock_user, LiveTokenRequest(conversationId=session.id, scenarioId=None if ended else uuid.uuid4()))
    assert error.value.status_code == (400 if ended else 409)
    generate.assert_not_awaited()


@pytest.mark.parametrize("duration", [-1, 86401])
def test_live_feedback_rejects_invalid_duration(duration):
    with pytest.raises(ValidationError):
        LiveFeedbackRequest(durationSeconds=duration)


@pytest.mark.asyncio
async def test_token_is_not_returned_when_session_ends_during_provider_request(mock_user, session):
    db = AsyncMock()
    row = MagicMock()
    row.scalar_one_or_none.return_value = session
    db.execute.return_value = row
    requested, release = asyncio.Event(), asyncio.Event()

    async def delayed_token():
        requested.set()
        await release.wait()
        return {"token": "unused", "wsUri": "wss://test", "model": "test"}

    with (
        patch("app.services.chat_voice.rate_limit", return_value=MagicMock(success=True)),
        patch("app.services.chat_voice.check_ai_limit", return_value={"allowed": True}),
        patch("app.services.chat_voice.generate_live_token", side_effect=delayed_token),
    ):
        task = asyncio.create_task(create_live_token(db, mock_user, LiveTokenRequest(conversationId=session.id)))
        await asyncio.wait_for(requested.wait(), timeout=1)
        session.ended_at = datetime.now(UTC)
        release.set()
        with pytest.raises(ChatVoiceServiceError) as error:
            await asyncio.wait_for(task, timeout=1)
    assert error.value.status_code == 400
    assert db.execute.await_count == 2


def test_additive_request_flags_remain_optional_in_schema_and_at_runtime():
    assert LiveFeedbackRequest(durationSeconds=0).analysis_enabled is True
    assert WordbookCreateRequest(word="朝食", reading="", meaningKo="조식").preserve_existing is False
    for model, field in [(LiveFeedbackRequest, "analysisEnabled"), (WordbookCreateRequest, "preserveExisting")]:
        schema = model.model_json_schema(by_alias=True)
        assert field not in schema["required"]
        assert "default" not in schema["properties"][field]


@pytest.mark.asyncio
async def test_achievement_count_excludes_empty_cancelled_conversations(mock_user):
    db = AsyncMock()
    result = MagicMock()
    result.scalar.return_value = 0
    db.execute.return_value = result
    assert await _count_completed_conversations(db, user_id=mock_user.id) == 0
    statement = str(db.execute.await_args.args[0].compile(compile_kwargs={"literal_binds": True}))
    assert "conversations.ended_at IS NOT NULL" in statement
    assert "jsonb_typeof" in statement
    assert "jsonb_path_exists" in statement
    assert '@.role == "user"' in statement
