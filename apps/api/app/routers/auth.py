from __future__ import annotations

from typing import Annotated, Any
from uuid import UUID

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import _decode_token, get_current_user
from app.models.user import User
from app.schemas.auth import OnboardingRequest, OnboardingResponse
from app.services.auth_user import complete_onboarding_profile, get_or_create_user_profile
from app.services.kakao_auth import (
    KakaoIdTokenMissingError,
    KakaoTokenExchangeError,
    exchange_kakao_authorization_code,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

bearer_scheme = HTTPBearer()


class KakaoTokenExchangeRequest(BaseModel):
    code: str
    redirect_uri: str


@router.post("/kakao/exchange", status_code=200)
async def kakao_token_exchange(body: KakaoTokenExchangeRequest) -> dict[str, str]:
    """카카오 인가 코드를 id_token으로 교환 (모바일 네이티브 SDK용)."""
    try:
        id_token = await exchange_kakao_authorization_code(
            code=body.code,
            redirect_uri=body.redirect_uri,
        )
    except KakaoTokenExchangeError as err:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="카카오 토큰 교환에 실패했습니다.",
        ) from err
    except KakaoIdTokenMissingError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="id_token이 없습니다. OpenID Connect가 활성화되어 있는지 확인하세요.",
        ) from err

    return {"id_token": id_token}


@router.post("/ensure-user", status_code=200)
async def ensure_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, dict[str, Any]]:
    """Supabase JWT에서 유저 ID/email 추출, DB에 없으면 자동 생성."""
    try:
        payload = _decode_token(credentials.credentials)
    except (jwt.InvalidTokenError, jwt.ExpiredSignatureError, jwt.DecodeError) as err:
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

    profile = await get_or_create_user_profile(db, user_id=user_id, email=email)
    return {"user": profile.model_dump(by_alias=True)}


@router.post("/onboarding", response_model=OnboardingResponse, status_code=200)
async def onboarding(
    body: OnboardingRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> OnboardingResponse:
    profile = await complete_onboarding_profile(db, user, body)
    return OnboardingResponse(profile=profile)
