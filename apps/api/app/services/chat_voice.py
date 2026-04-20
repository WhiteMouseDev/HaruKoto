from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.middleware.rate_limit import rate_limit
from app.models import Conversation, User
from app.models.enums import ConversationType
from app.schemas.chat import ChatTTSRequest, LiveFeedbackRequest, LiveTokenRequest
from app.services.ai import generate_live_feedback, generate_live_token, generate_tts, transcribe_audio
from app.services.conversation_rewards import grant_conversation_completion_rewards
from app.services.subscription import check_ai_limit
from app.utils.constants import RATE_LIMITS
from app.utils.date import get_now_kst

logger = logging.getLogger(__name__)

ALLOWED_AUDIO_TYPES = {"audio/webm", "audio/mp3", "audio/mpeg", "audio/wav", "audio/ogg", "audio/flac", "audio/m4a"}
MAX_AUDIO_SIZE = 4_500_000  # 4.5MB


class ChatVoiceServiceError(Exception):
    def __init__(self, status_code: int, detail: str, headers: dict[str, str] | None = None) -> None:
        self.status_code = status_code
        self.detail = detail
        self.headers = headers
        super().__init__(detail)


@dataclass(slots=True)
class ChatTTSResult:
    audio: bytes
    media_type: str


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


async def create_live_token(db: AsyncSession, user: User, body: LiveTokenRequest) -> dict[str, str]:
    del body
    rl = await rate_limit(f"live:{user.id}", RATE_LIMITS.LIVE_TOKEN.max_requests, RATE_LIMITS.LIVE_TOKEN.window_seconds)
    if not rl.success:
        raise ChatVoiceServiceError(status_code=429, detail="요청이 너무 많습니다")

    limit_check = await check_ai_limit(db, user.id, "call")
    if not limit_check["allowed"]:
        raise ChatVoiceServiceError(status_code=429, detail=limit_check["reason"])

    return await generate_live_token()


def _transcript_from_messages(raw_messages: Any) -> list[dict[str, str]]:
    if not isinstance(raw_messages, list):
        return []

    transcript: list[dict[str, str]] = []
    for message in raw_messages:
        if not isinstance(message, dict):
            continue
        role = str(message.get("role", "user"))
        if role == "system":
            continue
        transcript.append({"role": role, "text": str(message.get("content", ""))})
    return transcript


async def submit_live_conversation_feedback(
    db: AsyncSession,
    user: User,
    body: LiveFeedbackRequest,
) -> dict[str, Any]:
    now = get_now_kst()
    conversation = None

    if body.conversation_id:
        result = await db.execute(select(Conversation).where(Conversation.id == body.conversation_id, Conversation.user_id == user.id))
        conversation = result.scalar_one_or_none()

    if conversation and conversation.messages:
        transcript = _transcript_from_messages(conversation.messages)
    elif body.transcript:
        transcript = body.transcript
    else:
        transcript = []

    feedback = None
    if transcript:
        try:
            feedback = await generate_live_feedback(transcript)
        except Exception:
            logger.exception("Live feedback generation failed")

    if not conversation:
        conversation = Conversation(
            user_id=user.id,
            type=ConversationType.VOICE,
            scenario_id=body.scenario_id,
            character_id=body.character_id,
            messages=[{"role": entry.get("role", "user"), "content": entry.get("text", "")} for entry in transcript],
        )
        db.add(conversation)
        await db.flush()

    conversation.ended_at = now
    conversation.feedback_summary = feedback

    xp = 0
    events: list[dict[str, Any]] = []
    try:
        rewards = await grant_conversation_completion_rewards(
            db,
            user,
            now=now,
            duration_seconds=body.duration_seconds,
            usage_type="call",
        )
        xp = rewards.xp_earned
        events = rewards.events
    except Exception:
        logger.exception("Live feedback gamification failed")
        try:
            await db.rollback()
            if conversation not in db:
                db.add(conversation)
            conversation.ended_at = now
            conversation.feedback_summary = feedback
            await db.commit()
        except Exception:
            logger.exception("Live feedback conversation save also failed")
            await db.rollback()
    else:
        try:
            await db.commit()
        except Exception:
            logger.exception("Live feedback commit failed")
            await db.rollback()

    return {
        "conversationId": str(conversation.id),
        "feedbackSummary": feedback,
        "xpEarned": xp,
        "events": events,
    }
