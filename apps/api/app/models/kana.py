from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING, Any

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import ARRAY, JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.enums import KanaType

if TYPE_CHECKING:
    from app.models.user import User


class KanaCharacter(Base):
    __tablename__ = "kana_characters"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    kana_type: Mapped[KanaType] = mapped_column(nullable=False)
    character: Mapped[str] = mapped_column(Text, nullable=False)
    romaji: Mapped[str] = mapped_column(Text, nullable=False)
    pronunciation: Mapped[str] = mapped_column(Text, nullable=False)
    row: Mapped[str] = mapped_column(Text, nullable=False)
    column: Mapped[str] = mapped_column(Text, nullable=False)
    stroke_count: Mapped[int] = mapped_column(Integer, nullable=False)
    stroke_order: Mapped[dict[str, Any] | list[Any] | None] = mapped_column(JSON, nullable=True)
    audio_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    example_word: Mapped[str | None] = mapped_column(Text, nullable=True)
    example_reading: Mapped[str | None] = mapped_column(Text, nullable=True)
    example_meaning: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(Text, default="basic")
    order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user_progress: Mapped[list[UserKanaProgress]] = relationship(back_populates="kana", cascade="all, delete-orphan")

    __table_args__ = (UniqueConstraint("kana_type", "character"),)


class UserKanaProgress(Base):
    __tablename__ = "user_kana_progress"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    kana_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("kana_characters.id", ondelete="CASCADE"))
    correct_count: Mapped[int] = mapped_column(Integer, default=0)
    incorrect_count: Mapped[int] = mapped_column(Integer, default=0)
    streak: Mapped[int] = mapped_column(Integer, default=0)
    mastered: Mapped[bool] = mapped_column(Boolean, default=False)
    last_reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user: Mapped[User] = relationship(back_populates="kana_progress")  # noqa: F821
    kana: Mapped[KanaCharacter] = relationship(back_populates="user_progress")

    __table_args__ = (UniqueConstraint("user_id", "kana_id"),)


class KanaLearningStage(Base):
    __tablename__ = "kana_learning_stages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    kana_type: Mapped[KanaType] = mapped_column(nullable=False)
    stage_number: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    characters: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user_stages: Mapped[list[UserKanaStage]] = relationship(back_populates="stage", cascade="all, delete-orphan")

    __table_args__ = (UniqueConstraint("kana_type", "stage_number"),)


class UserKanaStage(Base):
    __tablename__ = "user_kana_stages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    stage_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("kana_learning_stages.id", ondelete="CASCADE"))
    is_unlocked: Mapped[bool] = mapped_column(Boolean, default=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    quiz_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user: Mapped[User] = relationship(back_populates="kana_stages")  # noqa: F821
    stage: Mapped[KanaLearningStage] = relationship(back_populates="user_stages")

    __table_args__ = (UniqueConstraint("user_id", "stage_id"),)
