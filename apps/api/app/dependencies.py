from __future__ import annotations

from typing import Annotated, Any
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import User
from app.services.auth_identity import (
    InvalidSubjectClaimError,
    MissingSubjectClaimError,
    get_user_by_id,
    payload_has_reviewer_role,
    required_user_id_from_payload,
)
from app.services.auth_token import decode_supabase_token as _decode_token

bearer_scheme = HTTPBearer()
optional_bearer_scheme = HTTPBearer(auto_error=False)


# ==========================================
# FastAPI Dependencies
# ==========================================


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    payload = _decode_required_payload(credentials)
    return await _load_required_user(db, _required_user_id_from_payload(payload))


async def require_reviewer(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    """Decode JWT and verify app_metadata.reviewer == True."""
    payload = _decode_required_payload(credentials)

    if not payload_has_reviewer_role(payload):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Reviewer role required",
        )

    return await _load_required_user(db, _required_user_id_from_payload(payload))


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

    try:
        user_id = _required_user_id_from_payload(payload)
    except HTTPException:
        return None

    return await get_user_by_id(db, user_id)


def _decode_required_payload(credentials: HTTPAuthorizationCredentials) -> dict[str, Any]:
    try:
        return _decode_token(credentials.credentials)
    except (jwt.InvalidTokenError, jwt.ExpiredSignatureError, jwt.DecodeError) as err:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from err


def _required_user_id_from_payload(payload: dict[str, Any]) -> UUID:
    try:
        return required_user_id_from_payload(payload)
    except MissingSubjectClaimError as err:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing subject claim") from err
    except InvalidSubjectClaimError as err:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid subject claim") from err


async def _load_required_user(db: AsyncSession, user_id: UUID) -> User:
    user = await get_user_by_id(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return user
