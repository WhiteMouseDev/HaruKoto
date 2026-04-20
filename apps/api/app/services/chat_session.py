from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from sqlalchemy import func, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.middleware.rate_limit import rate_limit
from app.models import Conversation, ConversationScenario, DailyProgress, Notification, User
from app.models.enums import ConversationType
from app.schemas.chat import (
    ChatEndRequest,
    ChatEndResponse,
    ChatMessageRequest,
    ChatMessageResponse,
    ChatStartRequest,
    ChatStartResponse,
)
from app.schemas.chat import ChatMessage as ChatMessageSchema
from app.services.ai import generate_chat_response, generate_feedback_summary
from app.services.gamification import calculate_level, check_and_grant_achievements, update_streak
from app.services.subscription import check_ai_limit, track_ai_usage
from app.utils.constants import RATE_LIMITS, REWARDS
from app.utils.date import get_now_kst, get_today_kst
from app.utils.prompts import SYSTEM_PROMPTS, build_system_prompt

logger = logging.getLogger(__name__)


class ChatSessionServiceError(Exception):
    def __init__(self, status_code: int, detail: str, headers: dict[str, str] | None = None) -> None:
        self.status_code = status_code
        self.detail = detail
        self.headers = headers
        super().__init__(detail)


@dataclass(slots=True)
class ConversationHistory:
    system_prompt: str
    history: list[dict[str, str]]


def _extract_conversation_history(messages: list[dict[str, Any]]) -> ConversationHistory:
    system_prompt = ""
    history: list[dict[str, str]] = []

    for message in messages:
        role = message.get("role")
        content = str(message.get("content", ""))
        if role == "system":
            system_prompt = content
        elif role in ("user", "assistant"):
            history.append({"role": role, "content": content})

    return ConversationHistory(system_prompt=system_prompt, history=history)


async def _load_user_conversation(
    db: AsyncSession,
    *,
    user_id: Any,
    conversation_id: Any,
) -> Conversation:
    result = await db.execute(select(Conversation).where(Conversation.id == conversation_id, Conversation.user_id == user_id))
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise ChatSessionServiceError(status_code=404, detail="대화를 찾을 수 없습니다")
    return conversation


async def start_chat_session(db: AsyncSession, user: User, body: ChatStartRequest) -> ChatStartResponse:
    limit_check = await check_ai_limit(db, str(user.id), "chat")
    if not limit_check["allowed"]:
        raise ChatSessionServiceError(status_code=429, detail=limit_check["reason"])

    rl = await rate_limit(f"chat:{user.id}", RATE_LIMITS.AI.max_requests, RATE_LIMITS.AI.window_seconds)
    if not rl.success:
        raise ChatSessionServiceError(
            status_code=429,
            detail="요청이 너무 많습니다",
            headers={"Retry-After": str(int(rl.reset))},
        )

    scenario = None
    if body.scenario_id:
        result = await db.execute(select(ConversationScenario).where(ConversationScenario.id == body.scenario_id))
        scenario = result.scalar_one_or_none()
        if not scenario:
            raise ChatSessionServiceError(status_code=404, detail="시나리오를 찾을 수 없습니다")

    system_prompt = build_system_prompt(user.jlpt_level or "N5", scenario=scenario)

    logger.info(
        "AI chat start",
        extra={
            "user_id": str(user.id),
            "scenario_id": str(body.scenario_id),
            "type": str(body.type),
        },
    )
    ai_response = await generate_chat_response(system_prompt, [], SYSTEM_PROMPTS["first_message_prompt"])
    logger.info(
        "AI chat start response received",
        extra={
            "user_id": str(user.id),
            "response_length": len(ai_response.get("messageJa", "")),
        },
    )

    conversation = Conversation(
        user_id=user.id,
        scenario_id=body.scenario_id,
        character_id=body.character_id,
        type=body.type or ConversationType.TEXT,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "assistant", "content": ai_response.get("messageJa", "")},
        ],
        message_count=1,
    )
    db.add(conversation)
    await db.flush()

    return ChatStartResponse(
        conversation_id=conversation.id,
        first_message=ChatMessageSchema(
            message_ja=ai_response.get("messageJa", ""),
            message_ko=ai_response.get("messageKo", ""),
            hint=ai_response.get("hint"),
        ),
    )


async def send_chat_message(db: AsyncSession, user: User, body: ChatMessageRequest) -> ChatMessageResponse:
    conversation = await _load_user_conversation(db, user_id=user.id, conversation_id=body.conversation_id)
    if conversation.ended_at:
        raise ChatSessionServiceError(status_code=400, detail="이미 종료된 대화입니다")

    messages = conversation.messages or []
    conversation_history = _extract_conversation_history(messages)

    logger.info(
        "AI chat message",
        extra={
            "user_id": str(user.id),
            "conversation_id": str(body.conversation_id),
            "history_length": len(conversation_history.history),
        },
    )
    ai_response = await generate_chat_response(conversation_history.system_prompt, conversation_history.history, body.message)
    logger.info(
        "AI chat message response",
        extra={
            "user_id": str(user.id),
            "conversation_id": str(body.conversation_id),
            "response_length": len(ai_response.get("messageJa", "")),
        },
    )

    new_messages = messages + [
        {"role": "user", "content": body.message},
        {"role": "assistant", "content": ai_response.get("messageJa", "")},
    ]
    conversation.messages = new_messages
    conversation.message_count = len([message for message in new_messages if message.get("role") in ("user", "assistant")])
    await db.flush()

    return ChatMessageResponse(
        message_ja=ai_response.get("messageJa", ""),
        message_ko=ai_response.get("messageKo", ""),
        feedback=ai_response.get("feedback"),
        hint=ai_response.get("hint"),
        new_vocabulary=ai_response.get("newVocabulary"),
    )


async def _update_chat_daily_progress(
    db: AsyncSession,
    *,
    user_id: Any,
    xp: int,
    study_minutes: int,
) -> None:
    today = get_today_kst()
    await db.execute(
        insert(DailyProgress)
        .values(
            user_id=user_id,
            date=today,
            xp_earned=xp,
            quizzes_completed=0,
            words_studied=0,
            study_minutes=study_minutes,
            conversation_count=1,
        )
        .on_conflict_do_update(
            index_elements=["user_id", "date"],
            set_={
                "xp_earned": DailyProgress.xp_earned + xp,
                "study_minutes": func.coalesce(DailyProgress.study_minutes, 0) + study_minutes,
                "conversation_count": func.coalesce(DailyProgress.conversation_count, 0) + 1,
            },
        )
    )


async def _count_completed_conversations(db: AsyncSession, *, user_id: Any) -> int:
    result = await db.execute(
        select(func.count()).select_from(Conversation).where(Conversation.user_id == user_id, Conversation.ended_at.isnot(None))
    )
    return result.scalar() or 0


async def end_chat_session(db: AsyncSession, user: User, body: ChatEndRequest) -> ChatEndResponse:
    conversation = await _load_user_conversation(db, user_id=user.id, conversation_id=body.conversation_id)
    if conversation.ended_at:
        return ChatEndResponse(success=True, feedback_summary=conversation.feedback_summary, xp_earned=0, events=[])

    messages = [message for message in (conversation.messages or []) if message.get("role") in ("user", "assistant")]
    logger.info(
        "AI chat end - generating feedback",
        extra={
            "user_id": str(user.id),
            "conversation_id": str(body.conversation_id),
            "message_count": len(messages),
        },
    )
    feedback = await generate_feedback_summary(messages)

    now = get_now_kst()
    conversation.ended_at = now
    conversation.feedback_summary = feedback

    xp = REWARDS.CONVERSATION_COMPLETE_XP
    logger.info("AI chat end - awarding XP", extra={"user_id": str(user.id), "xp": xp})
    old_level = calculate_level(user.experience_points)["level"]

    await db.execute(update(User).where(User.id == user.id).values(experience_points=User.experience_points + xp))
    await db.refresh(user)

    new_level_info = calculate_level(user.experience_points)
    new_level = new_level_info["level"]
    if new_level != user.level:
        user.level = new_level

    streak = update_streak(user.last_study_date, user.streak_count, user.longest_streak, now)
    user.streak_count = streak["streak_count"]
    user.longest_streak = streak["longest_streak"]
    user.last_study_date = now

    duration = int((now - conversation.created_at).total_seconds()) if conversation.created_at else 0
    await _update_chat_daily_progress(
        db,
        user_id=user.id,
        xp=xp,
        study_minutes=max(0, duration // 60),
    )

    await track_ai_usage(db, str(user.id), "chat", duration)
    conversation_count = await _count_completed_conversations(db, user_id=user.id)
    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": new_level,
            "old_level": old_level,
            "streak_count": streak["streak_count"],
            "conversation_count": conversation_count,
        },
    )

    for event in events:
        db.add(Notification(user_id=user.id, title=event["title"], body=event["body"], type="achievement"))

    await db.commit()

    return ChatEndResponse(
        success=True,
        feedback_summary=feedback,
        xp_earned=xp,
        events=events,
    )
