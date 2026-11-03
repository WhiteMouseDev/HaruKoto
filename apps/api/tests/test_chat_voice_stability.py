from __future__ import annotations

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models import Conversation, ConversationScenario
from app.models.enums import ConversationType, JlptLevel
from app.schemas.chat import LiveFeedbackRequest, LiveTokenRequest
from app.services.chat_voice import ChatVoiceServiceError, create_live_token, submit_live_conversation_feedback


@pytest.fixture
def scenario():
    return ConversationScenario(
        id=uuid.uuid4(),
        title="호텔 체크인",
        title_ja="ホテルチェックイン",
        situation="일본 호텔에서 체크인합니다.",
        your_role="숙박객",
        ai_role="호텔 프론트 직원",
        key_expressions=["予約しました"],
        system_prompt="あなたはホテルのフロントスタッフです。予約を確認してください。",
        is_active=True,
    )


@pytest.fixture
def db():
    session = MagicMock()
    session.execute = AsyncMock()
    session.get = AsyncMock(return_value=None)
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    session.commit = AsyncMock()
    session.rollback = AsyncMock()

    def add_conversation(obj):
        if isinstance(obj, Conversation) and obj.id is None:
            obj.id = uuid.uuid4()

    session.add.side_effect = add_conversation
    return session


@pytest.fixture
def voice_conversation(mock_user):
    return Conversation(
        id=uuid.uuid4(),
        user_id=mock_user.id,
        type=ConversationType.VOICE,
        messages=[{"role": "user", "content": "予約しました"}],
        ended_at=datetime.now(UTC),
        feedback_summary=None,
    )


def select_conversation(db, conversation):
    result = MagicMock()
    result.scalar_one_or_none.return_value = conversation
    db.execute.return_value = result


@pytest.mark.asyncio
async def test_analysis_disabled_still_saves_transcript_count_and_usage(db, mock_user):
    body = LiveFeedbackRequest(
        durationSeconds=30,
        analysisEnabled=False,
        transcript=[{"role": "assistant", "text": "こんにちは"}, {"role": "user", "text": "こんにちは"}],
    )
    with (
        patch("app.services.chat_voice.generate_live_feedback", new_callable=AsyncMock) as generate,
        patch("app.services.chat_voice.grant_conversation_completion_rewards", new_callable=AsyncMock) as rewards,
    ):
        rewards.return_value = MagicMock(xp_earned=20, events=[])
        result = await submit_live_conversation_feedback(db, mock_user, body)

    generate.assert_not_awaited()
    rewards.assert_awaited_once()
    assert rewards.await_args.kwargs["duration_seconds"] == 30
    assert result["feedbackSummary"] is None
    assert result["feedbackError"] is None
    assert result["conversationId"]
    assert db.add.call_args.args[0].message_count == 2
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_failed_analysis_preserves_call_record_and_reports_error(db, mock_user):
    with (
        patch("app.services.chat_voice.generate_live_feedback", side_effect=ValueError("malformed provider output")),
        patch("app.services.chat_voice.grant_conversation_completion_rewards", new_callable=AsyncMock) as rewards,
    ):
        rewards.return_value = MagicMock(xp_earned=20, events=[])
        result = await submit_live_conversation_feedback(
            db, mock_user, LiveFeedbackRequest(durationSeconds=30, transcript=[{"role": "user", "text": "予約しました"}])
        )
    assert result["conversationId"]
    assert result["feedbackSummary"] is None
    assert result["feedbackError"] == "generation_failed"
    assert db.commit.await_count == 2


@pytest.mark.asyncio
async def test_completed_call_analysis_retry_does_not_repeat_usage_or_rewards(db, mock_user, voice_conversation, scenario):
    voice_conversation.scenario_id = scenario.id
    ended_at = voice_conversation.ended_at
    select_conversation(db, voice_conversation)
    db.get.return_value = scenario
    mock_user.jlpt_level = JlptLevel.N2
    with (
        patch("app.services.chat_voice.generate_live_feedback", return_value={"overallScore": 80}) as generate,
        patch("app.services.chat_voice.grant_conversation_completion_rewards", new_callable=AsyncMock) as rewards,
    ):
        result = await submit_live_conversation_feedback(
            db, mock_user, LiveFeedbackRequest(conversationId=voice_conversation.id, durationSeconds=999)
        )
    rewards.assert_not_awaited()
    assert result["conversationId"] == str(voice_conversation.id)
    assert result["xpEarned"] == 0
    assert result["events"] == []
    assert voice_conversation.ended_at == ended_at
    assert "FOR UPDATE" in str(db.execute.await_args.args[0])
    assert "숙박객" in generate.await_args.kwargs["scenario_info"]
    assert "予約しました" in generate.await_args.kwargs["scenario_info"]
    assert generate.await_args.kwargs["jlpt_level"] == "N2"
    db.add.assert_not_called()
    assert db.commit.await_count == 3


@pytest.mark.asyncio
async def test_completed_call_returns_saved_result_without_regeneration(db, mock_user, voice_conversation):
    voice_conversation.feedback_summary = {"overallScore": 80}
    select_conversation(db, voice_conversation)
    with (
        patch("app.services.chat_voice.generate_live_feedback", new_callable=AsyncMock) as generate,
        patch("app.services.chat_voice.grant_conversation_completion_rewards", new_callable=AsyncMock) as rewards,
    ):
        result = await submit_live_conversation_feedback(
            db, mock_user, LiveFeedbackRequest(conversationId=voice_conversation.id, durationSeconds=30)
        )
    generate.assert_not_awaited()
    rewards.assert_not_awaited()
    assert result["feedbackSummary"] == {"overallScore": 80}
    assert result["xpEarned"] == 0


@pytest.mark.asyncio
async def test_unknown_or_unowned_conversation_does_not_create_new_record(db, mock_user):
    select_conversation(db, None)
    with pytest.raises(ChatVoiceServiceError) as error:
        await submit_live_conversation_feedback(db, mock_user, LiveFeedbackRequest(conversationId=uuid.uuid4(), durationSeconds=30))
    assert error.value.status_code == 404
    db.add.assert_not_called()


@pytest.mark.asyncio
async def test_text_conversation_cannot_be_rewarded_as_voice(db, mock_user, voice_conversation):
    voice_conversation.type = ConversationType.TEXT
    select_conversation(db, voice_conversation)
    with pytest.raises(ChatVoiceServiceError) as error:
        await submit_live_conversation_feedback(
            db, mock_user, LiveFeedbackRequest(conversationId=voice_conversation.id, durationSeconds=30)
        )
    assert error.value.status_code == 400


@pytest.mark.asyncio
async def test_assistant_only_transcript_is_not_scored(db, mock_user):
    with (
        patch("app.services.chat_voice.generate_live_feedback", new_callable=AsyncMock) as generate,
        patch("app.services.chat_voice.grant_conversation_completion_rewards", new_callable=AsyncMock) as rewards,
    ):
        rewards.return_value = MagicMock(xp_earned=20, events=[])
        result = await submit_live_conversation_feedback(
            db, mock_user, LiveFeedbackRequest(durationSeconds=30, transcript=[{"role": "assistant", "text": "こんにちは"}])
        )
    generate.assert_not_awaited()
    assert result["feedbackError"] == "no_transcript"
    assert result["conversationId"]


@pytest.mark.asyncio
async def test_token_contains_selected_scenario_roles_and_level(db, mock_user, scenario):
    db.get.return_value = scenario
    mock_user.jlpt_level = JlptLevel.N2
    with (
        patch("app.services.chat_voice.rate_limit", return_value=MagicMock(success=True)),
        patch("app.services.chat_voice.check_ai_limit", return_value={"allowed": True}),
        patch("app.services.chat_voice.generate_live_token", return_value={"token": "test", "wsUri": "wss://test", "model": "test"}),
    ):
        result = await create_live_token(db, mock_user, LiveTokenRequest(scenarioId=scenario.id))
    assert result.jlpt_level == "N2"
    assert "숙박객" in result.system_instruction
    assert "호텔 프론트 직원" in result.system_instruction
    assert "N2" in result.system_instruction
    assert scenario.system_prompt in result.system_instruction
    assert "アプリのニックネーム" in result.system_instruction
    assert "本人が名乗るまでは名前で呼ばず" in result.system_instruction
    assert "会話中に本人が伝えた名前を優先" in result.system_instruction
    assert scenario.situation in result.scenario_greeting
    assert scenario.ai_role in result.scenario_greeting


@pytest.mark.asyncio
async def test_free_call_keeps_nickname_without_scenario_identity_restrictions(db, mock_user):
    mock_user.nickname = "유이"
    with (
        patch("app.services.chat_voice.rate_limit", return_value=MagicMock(success=True)),
        patch("app.services.chat_voice.check_ai_limit", return_value={"allowed": True}),
        patch("app.services.chat_voice.generate_live_token", return_value={"token": "test", "wsUri": "wss://test", "model": "test"}),
    ):
        result = await create_live_token(db, mock_user, LiveTokenRequest())
    assert result.user_nickname == "유이"
    assert result.system_instruction is None
    assert result.scenario_greeting is None


@pytest.mark.asyncio
@pytest.mark.parametrize("missing", [True, False])
async def test_token_rejects_unavailable_scenario_before_issuing_token(db, mock_user, scenario, missing):
    scenario.is_active = False
    db.get.return_value = None if missing else scenario
    with (
        patch("app.services.chat_voice.rate_limit", return_value=MagicMock(success=True)),
        patch("app.services.chat_voice.check_ai_limit", return_value={"allowed": True}),
        patch("app.services.chat_voice.generate_live_token", new_callable=AsyncMock) as generate,
        pytest.raises(ChatVoiceServiceError) as error,
    ):
        await create_live_token(db, mock_user, LiveTokenRequest(scenarioId=scenario.id))
    assert error.value.status_code == 404
    generate.assert_not_awaited()


@pytest.mark.asyncio
async def test_analysis_context_failure_keeps_confirmed_save_and_same_session_id(db, mock_user, voice_conversation):
    voice_conversation.scenario_id = uuid.uuid4()
    select_conversation(db, voice_conversation)
    db.get.side_effect = RuntimeError("analysis context unavailable")
    with patch("app.services.chat_voice.generate_live_feedback", new_callable=AsyncMock) as generate:
        result = await submit_live_conversation_feedback(
            db, mock_user, LiveFeedbackRequest(conversationId=voice_conversation.id, durationSeconds=0)
        )
    assert result["conversationId"] == str(voice_conversation.id)
    assert result["feedbackError"] == "generation_failed"
    assert result["feedbackSummary"] is None
    assert result["xpEarned"] == 0
    db.commit.assert_awaited_once()
    db.rollback.assert_awaited_once()
    generate.assert_not_awaited()


@pytest.mark.asyncio
async def test_analysis_reload_failure_does_not_turn_saved_call_into_unknown_save(db, mock_user, voice_conversation):
    with (
        patch("app.services.chat_voice.load_live_conversation", side_effect=[voice_conversation, RuntimeError("reload failed")]),
        patch("app.services.chat_voice.generate_live_feedback", return_value={"overallScore": 80}),
    ):
        result = await submit_live_conversation_feedback(
            db, mock_user, LiveFeedbackRequest(conversationId=voice_conversation.id, durationSeconds=0)
        )
    assert result["conversationId"] == str(voice_conversation.id)
    assert result["feedbackError"] == "generation_failed"
    assert result["xpEarned"] == 0
    db.rollback.assert_awaited_once()


@pytest.mark.asyncio
async def test_malformed_legacy_content_is_not_fabricated_into_user_speech(db, mock_user, voice_conversation):
    voice_conversation.messages = [
        {"role": "user", "content": None},
        {"role": "user", "content": 123},
        {"content": "no known speaker"},
        {"role": ["user"], "content": "invalid role"},
        {"role": "assistant", "content": "こんにちは"},
    ]
    select_conversation(db, voice_conversation)
    with patch("app.services.chat_voice.generate_live_feedback", new_callable=AsyncMock) as generate:
        result = await submit_live_conversation_feedback(
            db, mock_user, LiveFeedbackRequest(conversationId=voice_conversation.id, durationSeconds=0)
        )
    assert result["feedbackError"] == "no_transcript"
    assert result["xpEarned"] == 0
    generate.assert_not_awaited()
