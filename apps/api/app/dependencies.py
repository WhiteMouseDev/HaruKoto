from __future__ import annotations

import logging
import time
from typing import Annotated, Any
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient, PyJWKClientError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.models.user import User

logger = logging.getLogger(__name__)

bearer_scheme = HTTPBearer()
optional_bearer_scheme = HTTPBearer(auto_error=False)

# ==========================================
# JWKS 캐시 (ES256 공개키)
# ==========================================

_jwks_client: PyJWKClient | None = None
_jwks_cache_time: float = 0
_JWKS_CACHE_TTL = 3600  # 1시간 캐시


def _get_jwks_client() -> PyJWKClient:
    """JWKS 클라이언트를 가져오거나, 캐시 만료 시 새로 생성."""
    global _jwks_client, _jwks_cache_time  # noqa: PLW0603

    now = time.time()
    if _jwks_client is None or (now - _jwks_cache_time) > _JWKS_CACHE_TTL:
        _jwks_client = PyJWKClient(settings.supabase_jwks_url)
        _jwks_cache_time = now
        logger.info("JWKS client initialized from %s", settings.supabase_jwks_url)

    return _jwks_client


# ==========================================
# JWT 검증 (ES256 JWKS 우선, Legacy HS256 폴백)
# ==========================================


def _decode_token(token: str) -> dict[str, Any]:
    """Supabase JWT 토큰 검증. JWKS(ES256) 우선, SUPABASE_JWT_SECRET 있으면 HS256 폴백."""

    # 1) JWKS (ES256) — Supabase 신규 방식
    if settings.SUPABASE_URL:
        try:
            client = _get_jwks_client()
            signing_key = client.get_signing_key_from_jwt(token)
            return jwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256"],
                audience="authenticated",
            )
        except (jwt.InvalidTokenError, jwt.ExpiredSignatureError, jwt.DecodeError, jwt.InvalidKeyError, PyJWKClientError) as exc:
            logger.debug("JWKS verification failed (%s), trying HS256 fallback", type(exc).__name__)

    # 2) Legacy HS256 폴백
    if settings.SUPABASE_JWT_SECRET:
        return jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )

    raise jwt.InvalidTokenError("No JWT verification method configured")


# ==========================================
# FastAPI Dependencies
# ==========================================


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    try:
        payload = _decode_token(credentials.credentials)
    except (jwt.InvalidTokenError, jwt.ExpiredSignatureError, jwt.DecodeError) as err:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from err

    sub = payload.get("sub")
    if sub is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
        )

    try:
        user_id = UUID(sub)
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid subject claim",
        ) from err

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return user


async def get_optional_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(optional_bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User | None:
    if credentials is None:
        return None

    try:
        payload = _decode_token(credentials.credentials)
    except (jwt.InvalidTokenError, jwt.ExpiredSignatureError, jwt.DecodeError):
        return None

    sub = payload.get("sub")
    if sub is None:
        return None

    try:
        user_id = UUID(sub)
    except ValueError:
        return None

    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()
