"""Private immutable receipts; source removal never erases accepted activity."""

import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, SmallInteger, Text, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class StudyActivityReceipt(Base):
    __tablename__ = "study_activity_receipts"

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    activity_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    source_kind: Mapped[str] = mapped_column(Text, nullable=False)
    source_scope_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    attempt_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    source_item_key: Mapped[str] = mapped_column(Text, nullable=False)
    content_version: Mapped[str] = mapped_column(Text, nullable=False)
    request_fingerprint: Mapped[str] = mapped_column(Text, nullable=False)
    fingerprint_version: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    response_schema_version: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    response_body: Mapped[dict[str, object]] = mapped_column(JSONB, nullable=False)
    processed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    study_date: Mapped[date] = mapped_column(Date, nullable=False)

    __table_args__ = (
        CheckConstraint("source_kind IN ('LESSON_ANSWER','KANA_QUIZ_ANSWER')", name="ck_study_activity_source_kind"),
        CheckConstraint("request_fingerprint ~ '^[0-9a-f]{64}$'", name="ck_study_activity_fingerprint"),
        CheckConstraint("content_version ~ '^[0-9a-f]{64}$'", name="ck_study_activity_content_version"),
        CheckConstraint("jsonb_typeof(response_body)='object'", name="ck_study_activity_response_object"),
        Index("idx_study_activity_user_scope_processed", "user_id", "source_scope_id", "processed_at"),
        Index(
            "uq_study_activity_kana_first_answer",
            "user_id",
            "source_scope_id",
            "source_item_key",
            unique=True,
            postgresql_where=text("source_kind='KANA_QUIZ_ANSWER'"),
        ),
    )
