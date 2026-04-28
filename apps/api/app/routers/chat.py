from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import User
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
    LiveTokenResponse,
)
from app.services.chat_session import ChatSessionServiceError, end_chat_session, send_chat_message, start_chat_session
from app.services.chat_voice import (
    ChatVoiceServiceError,
    create_live_token,
    submit_live_conversation_feedback,
    synthesize_chat_tts,
    transcribe_chat_voice,
)

router = APIRouter(prefix="/api/v1/chat", tags=["chat"])


# ==========================================
# POST /start — 대화 시작
# ==========================================


@router.post("/start", response_model=ChatStartResponse, status_code=200)
async def start_chat(
    body: ChatStartRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ChatStartResponse:
    try:
        return await start_chat_session(db, user, body)
    except ChatSessionServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=exc.headers) from exc


# ==========================================
# POST /message — 메시지 전송
# ==========================================


@router.post("/message", response_model=ChatMessageResponse, status_code=200)
async def send_message(
    body: ChatMessageRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ChatMessageResponse:
    try:
        return await send_chat_message(db, user, body)
    except ChatSessionServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=exc.headers) from exc


# ==========================================
# POST /end — 대화 종료 + 피드백 + 게임화
# ==========================================


@router.post("/end", response_model=ChatEndResponse, status_code=200)
async def end_chat(
    body: ChatEndRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ChatEndResponse:
    try:
        return await end_chat_session(db, user, body)
    except ChatSessionServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=exc.headers) from exc


# ==========================================
# POST /tts — 텍스트 음성 변환
# ==========================================


@router.post("/tts", status_code=200)
async def text_to_speech(
    body: ChatTTSRequest,
    user: Annotated[User, Depends(get_current_user)],
) -> Response:
    try:
        tts = await synthesize_chat_tts(user, body)
    except ChatVoiceServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=exc.headers) from exc

    return Response(content=tts.audio, media_type=tts.media_type)


# ==========================================
# POST /voice/transcribe — 음성 인식
# ==========================================


@router.post("/voice/transcribe", status_code=200)
async def transcribe_voice(
    file: UploadFile = File(...),
    _user: User = Depends(get_current_user),
) -> dict[str, str]:
    audio_bytes = await file.read()
    try:
        text = await transcribe_chat_voice(audio_bytes, file.content_type)
    except ChatVoiceServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=exc.headers) from exc

    return {"transcription": text}


# ==========================================
# POST /live-token — 실시간 대화 토큰
# ==========================================


@router.post("/live-token", response_model=LiveTokenResponse, status_code=200)
async def get_live_token_endpoint(
    body: LiveTokenRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> LiveTokenResponse:
    try:
        return await create_live_token(db, user, body)
    except ChatVoiceServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=exc.headers) from exc


# ==========================================
# POST /live-feedback — 음성 대화 피드백
# ==========================================


@router.post("/live-feedback", status_code=200)
async def submit_live_feedback(
    body: LiveFeedbackRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    try:
        return await submit_live_conversation_feedback(db, user, body)
    except ChatVoiceServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=exc.headers) from exc
