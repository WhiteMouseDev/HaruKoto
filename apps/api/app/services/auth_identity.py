from __future__ import annotations

from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class AuthSubjectClaimError(ValueError):
    """Base class for invalid user identity claims."""


class MissingSubjectClaimError(AuthSubjectClaimError):
    """Raised when a JWT payload has no subject claim."""


class InvalidSubjectClaimError(AuthSubjectClaimError):
    """Raised when a JWT subject claim is not a UUID."""


def required_user_id_from_payload(payload: dict[str, Any]) -> UUID:
    sub = payload.get("sub")
    if sub is None:
        raise MissingSubjectClaimError

    try:
        return UUID(sub)
    except ValueError as err:
        raise InvalidSubjectClaimError from err


def payload_has_reviewer_role(payload: dict[str, Any]) -> bool:
    app_metadata = payload.get("app_metadata", {})
    return isinstance(app_metadata, dict) and bool(app_metadata.get("reviewer", False))


async def get_user_by_id(db: AsyncSession, user_id: UUID) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()
