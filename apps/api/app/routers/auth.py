from __future__ import annotations

import logging
from typing import Annotated
from uuid import UUID

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import _decode_token, get_current_user
from app.models.user import User
from app.schemas.auth import OnboardingRequest, OnboardingResponse
from app.schemas.user import LevelProgressInfo, UserProfile
from app.services.gamification import calculate_level

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

bearer_scheme = HTTPBearer()


@router.post("/ensure-user")
async def ensure_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Supabase JWT에서 유저 ID/email 추출, DB에 없으면 자동 생성."""
    try:
        payload = _decode_token(credentials.credentials)
    except (jwt.InvalidTokenError, Exception) as err:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from err

    sub = payload.get("sub")
    email = payload.get("email", "")
    if sub is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing subject claim")

    try:
        user_id = UUID(sub)
    except ValueError as err:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid subject claim") from err

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(id=user_id, email=email)
        db.add(user)
        await db.commit()
        await db.refresh(user)

    level_info = calculate_level(user.experience_points)
    profile = UserProfile.model_validate(user)
    profile.level_progress = LevelProgressInfo(
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
    )

    return {"user": profile.model_dump(by_alias=True)}


@router.post("/onboarding", response_model=OnboardingResponse)
async def onboarding(
    body: OnboardingRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    user.nickname = body.nickname
    user.jlpt_level = body.jlpt_level
    user.daily_goal = body.daily_goal
    user.onboarding_completed = True
    if body.goal is not None:
        user.goal = body.goal
    if body.show_kana is not None:
        user.show_kana = body.show_kana

    await db.commit()
    await db.refresh(user)

    level_info = calculate_level(user.experience_points)
    profile = UserProfile.model_validate(user)
    profile.level_progress = LevelProgressInfo(
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
    )

    return OnboardingResponse(profile=profile)
