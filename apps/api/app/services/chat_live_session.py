from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.middleware.rate_limit import rate_limit
from app.models import AiCharacter, Conversation, ConversationScenario, User, UserCharacterUnlock
from app.models.enums import ConversationType
from app.schemas.chat import LiveSessionRequest, LiveSessionResponse
from app.services.chat_voice_errors import ChatVoiceServiceError
from app.services.study_day_recording import lock_study_user
from app.services.subscription_ai_usage import check_ai_limit
from app.utils.constants import RATE_LIMITS


async def load_live_conversation(db: AsyncSession, user_id: UUID, conversation_id: UUID, *, lock: bool = False) -> Conversation:
    query = (
        select(Conversation)
        .where(Conversation.id == conversation_id, Conversation.user_id == user_id)
        .execution_options(populate_existing=True)
    )
    if lock:
        query = query.with_for_update()
    conversation = (await db.execute(query)).scalar_one_or_none()
    if conversation is None:
        raise ChatVoiceServiceError(status_code=404, detail="대화를 찾을 수 없습니다")
    if conversation.type != ConversationType.VOICE:
        raise ChatVoiceServiceError(status_code=400, detail="음성 대화만 사용할 수 있습니다")
    return conversation


async def validate_live_context(
    db: AsyncSession, user_id: UUID, *, scenario_id: UUID | None, character_id: UUID | None
) -> ConversationScenario | None:
    scenario = None
    if scenario_id:
        scenario = await db.get(ConversationScenario, scenario_id)
        if scenario is None or not scenario.is_active:
            raise ChatVoiceServiceError(status_code=404, detail="시나리오를 찾을 수 없습니다")
    if character_id:
        character = await db.get(AiCharacter, character_id)
        if character is None or not character.is_active:
            raise ChatVoiceServiceError(status_code=404, detail="캐릭터를 찾을 수 없습니다")
        if not character.is_default:
            unlocked = await db.scalar(
                select(UserCharacterUnlock.id).where(
                    UserCharacterUnlock.user_id == user_id, UserCharacterUnlock.character_id == character_id
                )
            )
            if unlocked is None:
                raise ChatVoiceServiceError(status_code=403, detail="아직 해금하지 않은 캐릭터입니다")
    return scenario


def check_live_session_context(conversation: Conversation, body: LiveSessionRequest) -> None:
    if conversation.scenario_id != body.scenario_id or conversation.character_id != body.character_id:
        raise ChatVoiceServiceError(status_code=409, detail="이미 다른 대화에 사용한 요청입니다. 새 대화를 시작해 주세요")


async def create_live_session(db: AsyncSession, user: User, body: LiveSessionRequest) -> LiveSessionResponse:
    """Persist the client's stable ID before token issuance, without new tables."""
    existing = await db.get(Conversation, body.conversation_id)
    if existing is not None:
        if existing.user_id != user.id:
            raise ChatVoiceServiceError(status_code=404, detail="대화를 찾을 수 없습니다")
        if existing.type != ConversationType.VOICE:
            raise ChatVoiceServiceError(status_code=409, detail="이미 다른 대화에 사용한 요청입니다. 새 대화를 시작해 주세요")
        check_live_session_context(existing, body)
        return LiveSessionResponse(conversation_id=existing.id, ended_at=existing.ended_at)

    rl = await rate_limit(f"live-session:{user.id}", RATE_LIMITS.LIVE_TOKEN.max_requests, RATE_LIMITS.LIVE_TOKEN.window_seconds)
    if not rl.success:
        raise ChatVoiceServiceError(status_code=429, detail="요청이 너무 많습니다")
    limit = await check_ai_limit(db, user.id, "call")
    if not limit["allowed"]:
        raise ChatVoiceServiceError(status_code=429, detail=limit["reason"])
    await validate_live_context(db, user.id, scenario_id=body.scenario_id, character_id=body.character_id)

    try:
        await lock_study_user(db, user)
        await db.execute(
            insert(Conversation)
            .values(
                id=body.conversation_id,
                user_id=user.id,
                type=ConversationType.VOICE,
                scenario_id=body.scenario_id,
                character_id=body.character_id,
                messages=[],
                message_count=0,
            )
            .on_conflict_do_nothing(index_elements=[Conversation.id])
        )
        conversation = await load_live_conversation(db, user.id, body.conversation_id, lock=True)
        check_live_session_context(conversation, body)
        response = LiveSessionResponse(conversation_id=conversation.id, ended_at=conversation.ended_at)
        await db.commit()
    except ChatVoiceServiceError:
        await db.rollback()
        raise
    except Exception:
        await db.rollback()
        raise ChatVoiceServiceError(status_code=500, detail="대화를 준비하지 못했습니다. 다시 시도해 주세요") from None
    return response
