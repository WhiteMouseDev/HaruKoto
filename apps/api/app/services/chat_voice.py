from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.middleware.rate_limit import rate_limit
from app.models import Conversation, ConversationScenario, User
from app.models.enums import ConversationType
from app.schemas.chat import ChatTTSRequest, LiveFeedbackRequest, LiveTokenRequest, LiveTokenResponse
from app.services.ai import generate_live_feedback, generate_live_token, generate_tts, transcribe_audio
from app.services.chat_live_session import load_live_conversation, validate_live_context
from app.services.chat_voice_errors import ChatVoiceServiceError as ChatVoiceServiceError
from app.services.conversation_rewards import grant_conversation_completion_rewards
from app.services.live_scenario import build_live_scenario_greeting, build_live_scenario_instruction, scenario_feedback_context
from app.services.study_day_recording import lock_study_user
from app.services.subscription_ai_usage import check_ai_limit, track_ai_usage
from app.utils.constants import RATE_LIMITS
from app.utils.date import get_now_kst

logger = logging.getLogger(__name__)

ALLOWED_AUDIO_TYPES = {"audio/webm", "audio/mp3", "audio/mpeg", "audio/wav", "audio/ogg", "audio/flac", "audio/m4a"}
MAX_AUDIO_SIZE = 4_500_000  # 4.5MB
LIVE_FEEDBACK_SAVE_ERROR_DETAIL = "라이브 피드백 저장에 실패했습니다"
FALLBACK_USER_NICKNAME = "학습자"


@dataclass(slots=True)
class ChatTTSResult:
    audio: bytes
    media_type: str


async def _rollback_live_feedback_save_failure(db: AsyncSession, *, log_message: str) -> None:
    logger.exception(log_message)
    await db.rollback()
    raise ChatVoiceServiceError(status_code=500, detail=LIVE_FEEDBACK_SAVE_ERROR_DETAIL) from None


async def synthesize_chat_tts(user: User, body: ChatTTSRequest) -> ChatTTSResult:
    rl = await rate_limit(f"tts:{user.id}", RATE_LIMITS.AI.max_requests, RATE_LIMITS.AI.window_seconds)
    if not rl.success:
        raise ChatVoiceServiceError(status_code=429, detail="요청이 너무 많습니다")

    try:
        tts_result = await generate_tts(body.text, voice=body.voice_name or "Kore")
    except RuntimeError:
        logger.exception("Chat TTS generation failed for text=%r", body.text)
        raise ChatVoiceServiceError(status_code=502, detail="TTS 음성 생성에 실패했습니다") from None

    return ChatTTSResult(audio=tts_result.audio, media_type="audio/mpeg")


async def transcribe_chat_voice(audio_bytes: bytes, content_type: str | None) -> str:
    if content_type and content_type not in ALLOWED_AUDIO_TYPES:
        raise ChatVoiceServiceError(status_code=400, detail=f"지원하지 않는 오디오 형식입니다: {content_type}")

    if len(audio_bytes) > MAX_AUDIO_SIZE:
        raise ChatVoiceServiceError(status_code=400, detail="파일 크기가 4.5MB를 초과합니다")

    return await transcribe_audio(audio_bytes, content_type or "audio/webm")


async def create_live_token(db: AsyncSession, user: User, body: LiveTokenRequest) -> LiveTokenResponse:
    rl = await rate_limit(f"live:{user.id}", RATE_LIMITS.LIVE_TOKEN.max_requests, RATE_LIMITS.LIVE_TOKEN.window_seconds)
    if not rl.success:
        raise ChatVoiceServiceError(status_code=429, detail="요청이 너무 많습니다")

    limit_check = await check_ai_limit(db, user.id, "call")
    if not limit_check["allowed"]:
        raise ChatVoiceServiceError(status_code=429, detail=limit_check["reason"])

    scenario_id, character_id = body.scenario_id, body.character_id
    if body.conversation_id:
        conversation = await load_live_conversation(db, user.id, body.conversation_id)
        if conversation.ended_at is not None:
            raise ChatVoiceServiceError(status_code=400, detail="이미 종료된 대화입니다")
        if (scenario_id is not None and scenario_id != conversation.scenario_id) or (
            character_id is not None and character_id != conversation.character_id
        ):
            raise ChatVoiceServiceError(status_code=409, detail="대화의 상황 또는 상대가 일치하지 않습니다")
        scenario_id, character_id = conversation.scenario_id, conversation.character_id
    scenario = await validate_live_context(db, user.id, scenario_id=scenario_id, character_id=character_id)

    token = await generate_live_token()
    if body.conversation_id:
        # Token issuance may finish after the user cancelled the prepared call.
        conversation = await load_live_conversation(db, user.id, body.conversation_id)
        if conversation.ended_at is not None:
            raise ChatVoiceServiceError(status_code=400, detail="이미 종료된 대화입니다")
    nickname = (user.nickname or "").strip() or FALLBACK_USER_NICKNAME
    jlpt_level = str(user.jlpt_level.value if hasattr(user.jlpt_level, "value") else user.jlpt_level)

    return LiveTokenResponse(
        token=token["token"],
        ws_uri=token["wsUri"],
        model=token["model"],
        user_nickname=nickname,
        jlpt_level=jlpt_level,
        system_instruction=build_live_scenario_instruction(scenario, jlpt_level) if scenario else None,
        scenario_greeting=build_live_scenario_greeting(scenario) if scenario else None,
        conversation_id=body.conversation_id,
    )


def _transcript_from_messages(raw_messages: Any) -> list[dict[str, str]]:
    if not isinstance(raw_messages, list):
        return []

    transcript: list[dict[str, str]] = []
    for message in raw_messages:
        if not isinstance(message, dict):
            continue
        role, content = message.get("role"), message.get("content")
        if role not in ("user", "assistant") or not isinstance(content, str):
            continue
        transcript.append({"role": role, "text": content})
    return transcript


def _live_feedback_result(
    conversation: Conversation, *, feedback_error: str | None = None, xp: int = 0, events: list[dict[str, Any]] | None = None
) -> dict[str, Any]:
    return {
        "conversationId": str(conversation.id),
        "feedbackSummary": conversation.feedback_summary,
        "feedbackError": feedback_error,
        "xpEarned": xp,
        "events": events or [],
    }


async def submit_live_conversation_feedback(
    db: AsyncSession,
    user: User,
    body: LiveFeedbackRequest,
) -> dict[str, Any]:
    """Commit a call once before any optional provider analysis.

    Stable IDs from /live-session allow retries after a lost HTTP response.
    Legacy callers without an ID cannot receive this guarantee.
    """
    # Preserve the shared writer order: user -> conversation -> daily progress.
    # The save commit below releases both locks before optional model analysis.
    await lock_study_user(db, user)
    now = get_now_kst()
    conversation = await load_live_conversation(db, user.id, body.conversation_id, lock=True) if body.conversation_id else None
    if conversation is None:
        conversation = Conversation(
            user_id=user.id,
            type=ConversationType.VOICE,
            scenario_id=body.scenario_id,
            character_id=body.character_id,
        )
        db.add(conversation)
    xp = 0
    events: list[dict[str, Any]] = []
    try:
        if conversation.ended_at is None:
            if body.transcript is not None:
                conversation.messages = [
                    {"role": entry.get("role", "user"), "content": entry.get("text", "")}
                    for entry in body.transcript
                    if entry.get("role", "user") in {"user", "assistant"}
                ]
            transcript = _transcript_from_messages(conversation.messages)
            conversation.message_count = sum(1 for entry in transcript if entry["text"].strip())
            conversation.ended_at = now
            await db.flush()
            has_user_content = any(entry["role"] == "user" and entry["text"].strip() for entry in transcript)
            if body.duration_seconds >= 15 and has_user_content:
                rewards = await grant_conversation_completion_rewards(
                    db, user, now=now, duration_seconds=body.duration_seconds, usage_type="call"
                )
                xp, events = rewards.xp_earned, rewards.events
            elif body.duration_seconds > 0:
                # Saving a short/empty call must not turn it into an XP completion.
                # Connected time still consumes usage; a cancelled zero-second call does not.
                await track_ai_usage(db, user.id, "call", body.duration_seconds)
        # Also release the row lock on retries before waiting for the provider.
        await db.commit()
    except Exception:
        await _rollback_live_feedback_save_failure(db, log_message="Live conversation completion save failed")

    if not body.analysis_enabled or conversation.feedback_summary is not None:
        return _live_feedback_result(conversation, xp=xp, events=events)
    transcript = _transcript_from_messages(conversation.messages)
    if not any(entry["role"] == "user" and entry["text"].strip() for entry in transcript):
        return _live_feedback_result(conversation, feedback_error="no_transcript", xp=xp, events=events)

    conversation_id, user_id = conversation.id, user.id
    jlpt_level = str(user.jlpt_level.value if hasattr(user.jlpt_level, "value") else user.jlpt_level)
    try:
        scenario = await db.get(ConversationScenario, conversation.scenario_id) if conversation.scenario_id else None
        scenario_info = scenario_feedback_context(scenario) if scenario else ""
        # Finish this read transaction too: no database transaction spans the model call.
        await db.commit()
        feedback = await generate_live_feedback(transcript, scenario_info=scenario_info, jlpt_level=jlpt_level)
        # Concurrent analyses may both finish, but retain the first stored result.
        conversation = await load_live_conversation(db, user_id, conversation_id, lock=True)
        if conversation.feedback_summary is None:
            conversation.feedback_summary = feedback
        await db.commit()
    except Exception as exc:
        await db.rollback()
        # Completion is already durable. Do not misreport this as an unknown call save.
        logger.warning("Live feedback analysis failed (conversation_id=%s, error_type=%s)", conversation_id, type(exc).__name__)
        return {
            "conversationId": str(conversation_id),
            "feedbackSummary": None,
            "feedbackError": "generation_failed",
            "xpEarned": xp,
            "events": events,
        }
    return _live_feedback_result(conversation, xp=xp, events=events)
