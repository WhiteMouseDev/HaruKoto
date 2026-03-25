from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.enums import JlptLevel


class StudyStage(Base):
    __tablename__ = "study_stages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    category: Mapped[str] = mapped_column(Text, nullable=False)  # "VOCABULARY", "GRAMMAR", "SENTENCE"
    jlpt_level: Mapped[JlptLevel] = mapped_column(nullable=False)
    stage_number: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    content_ids: Mapped[list | dict] = mapped_column(JSON, nullable=False, default=list)
    unlock_after: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("study_stages.id"), nullable=True)
    order: Mapped[int | None] = mapped_column(Integer, nullable=True, default=0)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, server_default=func.now())

    user_progress: Mapped[list[UserStudyStageProgress]] = relationship(back_populates="stage", cascade="all, delete-orphan")

    __table_args__ = (UniqueConstraint("category", "jlpt_level", "stage_number"),)


class UserStudyStageProgress(Base):
    __tablename__ = "user_study_stage_progress"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    stage_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("study_stages.id", ondelete="CASCADE"))
    best_score: Mapped[int | None] = mapped_column(Integer, nullable=True, default=0)
    attempts: Mapped[int | None] = mapped_column(Integer, nullable=True, default=0)
    completed: Mapped[bool | None] = mapped_column(Boolean, nullable=True, default=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_attempted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        server_default=func.now(),
        onupdate=func.now(),
    )

    user: Mapped[User] = relationship(back_populates="study_stage_progress")  # noqa: F821
    stage: Mapped[StudyStage] = relationship(back_populates="user_progress")

    __table_args__ = (UniqueConstraint("user_id", "stage_id"),)
