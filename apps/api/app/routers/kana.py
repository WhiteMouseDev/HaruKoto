from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.enums import KanaType
from app.models.user import User
from app.schemas.kana import (
    KanaProgressRecord,
    KanaProgressResponse,
    KanaQuizAnswerRequest,
    KanaQuizAnswerResponse,
    KanaQuizCompleteRequest,
    KanaQuizCompleteResponse,
    KanaQuizStartRequest,
    KanaQuizStartResponse,
    KanaStageCompleteRequest,
    KanaStageCompleteResponse,
)
from app.services.kana_progress import record_kana_learning_progress
from app.services.kana_query import get_kana_characters_data, get_kana_progress_data, get_kana_stages_data
from app.services.kana_quiz_answer import KanaQuizAnswerServiceError, submit_kana_quiz_answer
from app.services.kana_quiz_complete import KanaQuizCompleteServiceError, complete_kana_quiz_session
from app.services.kana_quiz_start import KanaQuizStartServiceError, start_kana_quiz_session
from app.services.kana_stage_complete import KanaStageCompleteServiceError, complete_kana_stage

router = APIRouter(prefix="/api/v1/kana", tags=["kana"])


@router.get("/characters", status_code=200)
async def get_characters(
    kana_type: KanaType | None = None,
    category: str | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict[str, Any]]:
    return await get_kana_characters_data(db, user_id=user.id, kana_type=kana_type, category=category)


@router.get("/stages", status_code=200)
async def get_stages(
    kana_type: KanaType | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict[str, Any]]:
    return await get_kana_stages_data(db, user_id=user.id, kana_type=kana_type)


@router.get("/progress", response_model=KanaProgressResponse, status_code=200)
async def get_progress(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> KanaProgressResponse:
    return await get_kana_progress_data(db, user_id=user.id)


@router.post("/progress", status_code=200)
async def record_kana_learning(
    body: KanaProgressRecord,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, bool]:
    result = await record_kana_learning_progress(db, user, body)
    return {"ok": result.ok}


@router.post("/quiz/start", response_model=KanaQuizStartResponse, status_code=200)
async def start_kana_quiz(
    body: KanaQuizStartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> KanaQuizStartResponse:
    try:
        result = await start_kana_quiz_session(db, user, body)
    except KanaQuizStartServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return KanaQuizStartResponse(
        session_id=result.session_id,
        questions=result.questions,
        total_questions=result.total_questions,
    )


@router.post("/quiz/answer", response_model=KanaQuizAnswerResponse, status_code=200)
async def answer_kana_quiz(
    body: KanaQuizAnswerRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> KanaQuizAnswerResponse:
    try:
        result = await submit_kana_quiz_answer(db, user, body)
    except KanaQuizAnswerServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return KanaQuizAnswerResponse(is_correct=result.is_correct, correct_option_id=result.correct_option_id)


@router.post("/quiz/complete", response_model=KanaQuizCompleteResponse, status_code=200)
async def complete_kana_quiz(
    body: KanaQuizCompleteRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> KanaQuizCompleteResponse:
    try:
        result = await complete_kana_quiz_session(db, user, body)
    except KanaQuizCompleteServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return KanaQuizCompleteResponse(
        accuracy=result.accuracy,
        xp_earned=result.xp_earned,
        level=result.level,
        current_xp=result.current_xp,
        xp_for_next=result.xp_for_next,
        events=result.events,
    )


@router.post("/stage-complete", response_model=KanaStageCompleteResponse, status_code=200)
async def complete_stage(
    body: KanaStageCompleteRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> KanaStageCompleteResponse:
    try:
        result = await complete_kana_stage(db, user, body)
    except KanaStageCompleteServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return KanaStageCompleteResponse(
        success=result.success,
        xp_earned=result.xp_earned,
        level=result.level,
        current_xp=result.current_xp,
        xp_for_next=result.xp_for_next,
        events=result.events,
        next_stage_unlocked=result.next_stage_unlocked,
    )
