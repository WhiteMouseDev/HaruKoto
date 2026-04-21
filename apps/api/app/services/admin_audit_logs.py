from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.admin import AuditLog


async def list_admin_audit_logs(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: uuid.UUID,
) -> list[AuditLog]:
    result = await db.execute(
        select(AuditLog)
        .where(
            AuditLog.content_type == content_type,
            AuditLog.content_id == item_id,
        )
        .order_by(AuditLog.created_at.desc())
    )
    return list(result.scalars().all())
