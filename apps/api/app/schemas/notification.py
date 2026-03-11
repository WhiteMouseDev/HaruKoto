from __future__ import annotations

from datetime import datetime
from uuid import UUID

from app.schemas.common import CamelModel


class NotificationResponse(CamelModel):
    id: UUID
    type: str
    title: str
    body: str
    emoji: str | None = None
    is_read: bool
    created_at: datetime


class PushSubscribeRequest(CamelModel):
    endpoint: str
    p256dh: str
    auth: str
