from __future__ import annotations

import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin import AuditLog
from app.models.user import User


@dataclass(frozen=True, slots=True)
class AuditLogWithEmail:
    log: AuditLog
    reviewer_email: str


async def list_admin_audit_logs(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: uuid.UUID,
) -> list[AuditLogWithEmail]:
    result = await db.execute(
        select(AuditLog, User.email)
        .join(User, AuditLog.reviewer_id == User.id)
        .where(
            AuditLog.content_type == content_type,
            AuditLog.content_id == item_id,
        )
        .order_by(AuditLog.created_at.desc())
    )
    return [AuditLogWithEmail(log=row[0], reviewer_email=row[1]) for row in result.all()]
