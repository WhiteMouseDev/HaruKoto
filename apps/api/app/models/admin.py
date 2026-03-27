from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Text, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    content_type: Mapped[str] = mapped_column(Text, nullable=False)  # "vocabulary"|"grammar"|"cloze"|"sentence_arrange"|"conversation"
    content_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    action: Mapped[str] = mapped_column(Text, nullable=False)  # "edit"|"approve"|"reject"
    changes: Mapped[dict | None] = mapped_column(JSON, nullable=True)  # {field: {before, after}}
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)  # rejection reason
    reviewer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_audit_logs_content", "content_type", "content_id"),
        Index("ix_audit_logs_created_at", "created_at"),
    )
