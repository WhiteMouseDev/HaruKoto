from __future__ import annotations

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import Response
from sqlalchemy import func, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
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
    ChatTTSRequest,
    LiveFeedbackRequest,
    LiveTokenRequest,
)
from app.schemas.chat import ChatMessage as ChatMessageSchema
from app.services.ai import (
    generate_chat_response,
    generate_feedback_summary,
    generate_live_feedback,
    generate_live_token,
    generate_tts,
    transcribe_audio,
)
from app.services.gamification import calculate_level, check_and_grant_achievements, update_streak
from app.services.subscription import check_ai_limit, track_ai_usage
from app.utils.constants import RATE_LIMITS, REWARDS
from app.utils.date import get_now_kst, get_today_kst
from app.utils.prompts import SYSTEM_PROMPTS, build_system_prompt

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/chat", tags=["chat"])


# ==========================================
# POST /start — 대화 시작
# ==========================================


@router.post("/start", response_model=ChatStartResponse)
async def start_chat(
    body: ChatStartRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # Rate limit + AI usage limit
    limit_check = await check_ai_limit(db, str(user.id), "chat")
    if not limit_check["allowed"]:
        raise HTTPException(status_code=429, detail=limit_check["reason"])

    rl = await rate_limit(f"chat:{user.id}", RATE_LIMITS.AI.max_requests, RATE_LIMITS.AI.window_seconds)
    if not rl.success:
        raise HTTPException(status_code=429, detail="요청이 너무 많습니다", headers={"Retry-After": str(int(rl.reset))})

    # Load scenario if provided
    scenario = None
    if body.scenario_id:
        result = await db.execute(select(ConversationScenario).where(ConversationScenario.id == body.scenario_id))
        scenario = result.scalar_one_or_none()
        if not scenario:
            raise HTTPException(status_code=404, detail="시나리오를 찾을 수 없습니다")

    # Build system prompt
    system_prompt = build_system_prompt(user.jlpt_level or "N5", scenario=scenario)

    # Generate first AI message
    ai_response = await generate_chat_response(system_prompt, [], SYSTEM_PROMPTS["first_message_prompt"])

    # Store conversation
    initial_messages = [
        {"role": "system", "content": system_prompt},
        {"role": "assistant", "content": ai_response.get("messageJa", "")},
    ]
    conversation = Conversation(
        user_id=user.id,
        scenario_id=body.scenario_id,
        character_id=body.character_id,
        type=body.type or ConversationType.TEXT,
        messages=initial_messages,
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


# ==========================================
# POST /message — 메시지 전송
# ==========================================


@router.post("/message", response_model=ChatMessageResponse)
async def send_message(
    body: ChatMessageRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # Load conversation
    result = await db.execute(select(Conversation).where(Conversation.id == body.conversation_id, Conversation.user_id == user.id))
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="대화를 찾을 수 없습니다")
    if conversation.ended_at:
        raise HTTPException(status_code=400, detail="이미 종료된 대화입니다")

    # Extract system prompt and history
    messages = conversation.messages or []
    system_prompt = ""
    history: list[dict[str, str]] = []
    for msg in messages:
        if msg.get("role") == "system":
            system_prompt = msg.get("content", "")
        elif msg.get("role") in ("user", "assistant"):
            history.append(msg)

    # Generate AI response
    ai_response = await generate_chat_response(system_prompt, history, body.message)

    # Append messages atomically
    new_messages = messages + [
        {"role": "user", "content": body.message},
        {"role": "assistant", "content": ai_response.get("messageJa", "")},
    ]
    conversation.messages = new_messages
    conversation.message_count = len([m for m in new_messages if m.get("role") in ("user", "assistant")])
    await db.flush()

    return ChatMessageResponse(
        message_ja=ai_response.get("messageJa", ""),
        message_ko=ai_response.get("messageKo", ""),
        feedback=ai_response.get("feedback"),
        hint=ai_response.get("hint"),
        new_vocabulary=ai_response.get("newVocabulary"),
    )


# ==========================================
# POST /end — 대화 종료 + 피드백 + 게임화
# ==========================================


@router.post("/end", response_model=ChatEndResponse)
async def end_chat(
    body: ChatEndRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(select(Conversation).where(Conversation.id == body.conversation_id, Conversation.user_id == user.id))
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="대화를 찾을 수 없습니다")
    if conversation.ended_at:
        return ChatEndResponse(success=True, feedback_summary=conversation.feedback_summary, xp_earned=0, events=[])

    # Generate feedback summary
    messages = [m for m in (conversation.messages or []) if m.get("role") in ("user", "assistant")]
    feedback = await generate_feedback_summary(messages)

    # Update conversation
    now = get_now_kst()
    conversation.ended_at = now
    conversation.feedback_summary = feedback

    # Gamification — award XP
    xp = REWARDS.CONVERSATION_COMPLETE_XP
    old_level = calculate_level(user.experience_points)["level"]

    await db.execute(update(User).where(User.id == user.id).values(experience_points=User.experience_points + xp))
    await db.refresh(user)

    new_level_info = calculate_level(user.experience_points)
    new_level = new_level_info["level"]
    if new_level != user.level:
        user.level = new_level

    # Streak
    streak = update_streak(user.last_study_date, user.streak_count, user.longest_streak, now)
    user.streak_count = streak["streak_count"]
    user.longest_streak = streak["longest_streak"]
    user.last_study_date = now

    # Daily progress
    today = get_today_kst()
    duration = int((now - conversation.created_at).total_seconds()) if conversation.created_at else 0
    chat_study_minutes = max(0, duration // 60)
    await db.execute(
        insert(DailyProgress)
        .values(user_id=user.id, date=today, xp_earned=xp, quizzes_completed=0, words_studied=0, study_minutes=chat_study_minutes)
        .on_conflict_do_update(
            index_elements=["user_id", "date"],
            set_={
                "xp_earned": DailyProgress.xp_earned + xp,
                "study_minutes": DailyProgress.study_minutes + chat_study_minutes,
            },
        )
    )

    # Track AI usage
    await track_ai_usage(db, str(user.id), "chat", duration)

    # Achievements
    conv_count = (
        await db.execute(
            select(func.count()).select_from(Conversation).where(Conversation.user_id == user.id, Conversation.ended_at.isnot(None))
        )
    ).scalar() or 0

    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": new_level,
            "old_level": old_level,
            "streak_count": streak["streak_count"],
            "conversation_count": conv_count,
        },
    )

    # Create notifications for events
    for event in events:
        db.add(Notification(user_id=user.id, title=event["title"], body=event["body"], type="achievement"))

    await db.commit()

    return ChatEndResponse(
        success=True,
        feedback_summary=feedback,
        xp_earned=xp,
        events=events,
    )


# ==========================================
# POST /tts — 텍스트 음성 변환
# ==========================================


@router.post("/tts")
async def text_to_speech(
    body: ChatTTSRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    rl = await rate_limit(f"tts:{user.id}", RATE_LIMITS.AI.max_requests, RATE_LIMITS.AI.window_seconds)
    if not rl.success:
        raise HTTPException(status_code=429, detail="요청이 너무 많습니다")

    wav_bytes = await generate_tts(body.text, voice=body.voice_name or "Kore")
    return Response(content=wav_bytes, media_type="audio/wav")


# ==========================================
# POST /voice/transcribe — 음성 인식
# ==========================================

ALLOWED_AUDIO_TYPES = {"audio/webm", "audio/mp3", "audio/mpeg", "audio/wav", "audio/ogg", "audio/flac", "audio/m4a"}
MAX_AUDIO_SIZE = 4_500_000  # 4.5MB


@router.post("/voice/transcribe")
async def transcribe_voice(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if file.content_type and file.content_type not in ALLOWED_AUDIO_TYPES:
        raise HTTPException(status_code=400, detail=f"지원하지 않는 오디오 형식입니다: {file.content_type}")

    audio_bytes = await file.read()
    if len(audio_bytes) > MAX_AUDIO_SIZE:
        raise HTTPException(status_code=400, detail="파일 크기가 4.5MB를 초과합니다")

    mime_type = file.content_type or "audio/webm"
    text = await transcribe_audio(audio_bytes, mime_type)
    return {"transcription": text}


# ==========================================
# POST /live-token — 실시간 대화 토큰
# ==========================================


@router.post("/live-token")
async def get_live_token_endpoint(
    body: LiveTokenRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    rl = await rate_limit(f"live:{user.id}", RATE_LIMITS.LIVE_TOKEN.max_requests, RATE_LIMITS.LIVE_TOKEN.window_seconds)
    if not rl.success:
        raise HTTPException(status_code=429, detail="요청이 너무 많습니다")

    limit_check = await check_ai_limit(db, str(user.id), "call")
    if not limit_check["allowed"]:
        raise HTTPException(status_code=429, detail=limit_check["reason"])

    token_data = await generate_live_token()
    return token_data


# ==========================================
# POST /live-feedback — 음성 대화 피드백
# ==========================================


@router.post("/live-feedback")
async def submit_live_feedback(
    body: LiveFeedbackRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # Load existing conversation
    result = await db.execute(select(Conversation).where(Conversation.id == body.conversation_id, Conversation.user_id == user.id))
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="대화를 찾을 수 없습니다")

    # Generate feedback from transcript
    transcript = conversation.messages or []
    feedback = await generate_live_feedback(
        [{"role": m.get("role", "user"), "text": m.get("content", "")} for m in transcript if m.get("role") != "system"]
    )

    # Update conversation
    now = get_now_kst()
    conversation.ended_at = now
    conversation.feedback_summary = feedback

    # Gamification (same as /end)
    xp = REWARDS.CONVERSATION_COMPLETE_XP
    old_level = calculate_level(user.experience_points)["level"]

    await db.execute(update(User).where(User.id == user.id).values(experience_points=User.experience_points + xp))
    await db.refresh(user)

    new_level = calculate_level(user.experience_points)["level"]
    if new_level != user.level:
        user.level = new_level

    streak = update_streak(user.last_study_date, user.streak_count, user.longest_streak, now)
    user.streak_count = streak["streak_count"]
    user.longest_streak = streak["longest_streak"]
    user.last_study_date = now

    today = get_today_kst()
    live_study_minutes = max(0, body.duration_seconds // 60)
    await db.execute(
        insert(DailyProgress)
        .values(user_id=user.id, date=today, xp_earned=xp, quizzes_completed=0, words_studied=0, study_minutes=live_study_minutes)
        .on_conflict_do_update(
            index_elements=["user_id", "date"],
            set_={
                "xp_earned": DailyProgress.xp_earned + xp,
                "study_minutes": DailyProgress.study_minutes + live_study_minutes,
            },
        )
    )

    # Track voice usage
    await track_ai_usage(db, str(user.id), "call", body.duration_seconds)

    # Achievements
    conv_count = (
        await db.execute(
            select(func.count()).select_from(Conversation).where(Conversation.user_id == user.id, Conversation.ended_at.isnot(None))
        )
    ).scalar() or 0

    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": new_level,
            "old_level": old_level,
            "streak_count": streak["streak_count"],
            "conversation_count": conv_count,
        },
    )

    for event in events:
        db.add(Notification(user_id=user.id, title=event["title"], body=event["body"], type="achievement"))

    await db.commit()

    return {
        "success": True,
        "conversationId": str(conversation.id),
        "feedbackSummary": feedback,
        "xpEarned": xp,
        "events": events,
    }
