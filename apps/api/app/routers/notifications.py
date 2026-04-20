from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import Notification
from app.models.user import User
from app.schemas.common import CamelModel
from app.schemas.notification import NotificationResponse

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


class NotificationsListResponse(CamelModel):
    notifications: list[NotificationResponse]
    unread_count: int


class MarkReadRequest(BaseModel):
    id: UUID | None = None


@router.get("/", response_model=NotificationsListResponse, status_code=200)
async def get_notifications(
    limit: int = Query(default=20, le=50),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> NotificationsListResponse:
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == user.id)
        .order_by(Notification.is_read, Notification.created_at.desc())
        .limit(limit)
    )
    notifications = [NotificationResponse.model_validate(n) for n in result.scalars().all()]

    unread_result = await db.execute(
        select(func.count()).select_from(Notification).where(Notification.user_id == user.id, Notification.is_read == False)  # noqa: E712
    )
    unread_count = unread_result.scalar() or 0

    return NotificationsListResponse(notifications=notifications, unread_count=unread_count)


@router.patch("/", status_code=200)
async def mark_notifications_read(
    body: MarkReadRequest | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, bool]:
    if body and body.id:
        await db.execute(update(Notification).where(Notification.id == body.id, Notification.user_id == user.id).values(is_read=True))
    else:
        await db.execute(
            update(Notification)
            .where(Notification.user_id == user.id, Notification.is_read == False)  # noqa: E712
            .values(is_read=True)
        )
    await db.commit()
    return {"ok": True}
