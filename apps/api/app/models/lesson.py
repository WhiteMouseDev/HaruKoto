"""Chapter / Lesson / LessonItemLink / UserLessonProgress models.

04-DATA-SCHEMA.md 설계 기반. review_events는 월별 파티션 테이블이므로
raw SQL 마이그레이션으로 처리하고 ORM 모델은 생략한다.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.enums import JlptLevel


class Chapter(Base):
    __tablename__ = "chapters"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    jlpt_level: Mapped[JlptLevel] = mapped_column(nullable=False)
    part_no: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    chapter_no: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    topic: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_no: Mapped[int] = mapped_column(SmallInteger, default=0)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    lessons: Mapped[list[Lesson]] = relationship(back_populates="chapter", cascade="all, delete-orphan")

    __table_args__ = (UniqueConstraint("jlpt_level", "part_no", "chapter_no"),)


class Lesson(Base):
    __tablename__ = "lessons"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chapter_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("chapters.id"), nullable=False)
    jlpt_level: Mapped[JlptLevel] = mapped_column(nullable=False)
    lesson_no: Mapped[int] = mapped_column(Integer, nullable=False)
    chapter_lesson_no: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    topic: Mapped[str] = mapped_column(Text, nullable=False)
    estimated_minutes: Mapped[int] = mapped_column(SmallInteger, default=10)
    content_jsonb: Mapped[dict] = mapped_column(JSONB, default=dict)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    chapter: Mapped[Chapter] = relationship(back_populates="lessons")
    item_links: Mapped[list[LessonItemLink]] = relationship(back_populates="lesson", cascade="all, delete-orphan")
    user_progress: Mapped[list[UserLessonProgress]] = relationship(back_populates="lesson", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("chapter_id", "chapter_lesson_no"),
        UniqueConstraint("jlpt_level", "lesson_no"),
        Index("idx_lessons_chapter", "chapter_id", "chapter_lesson_no"),
    )


class LessonItemLink(Base):
    __tablename__ = "lesson_item_links"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lesson_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("lessons.id", ondelete="CASCADE"), nullable=False)
    item_type: Mapped[str] = mapped_column(Text, nullable=False)  # 'WORD' | 'GRAMMAR'
    vocabulary_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("vocabularies.id"), nullable=True)
    grammar_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("grammars.id"), nullable=True)
    item_order: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    is_core: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    lesson: Mapped[Lesson] = relationship(back_populates="item_links")

    __table_args__ = (
        UniqueConstraint("lesson_id", "item_type", "vocabulary_id", "grammar_id"),
        CheckConstraint(
            "(item_type = 'WORD' AND vocabulary_id IS NOT NULL AND grammar_id IS NULL) OR "
            "(item_type = 'GRAMMAR' AND grammar_id IS NOT NULL AND vocabulary_id IS NULL)",
            name="ck_lesson_item_links_type",
        ),
        Index("idx_lesson_item_links_lesson", "lesson_id", "item_order"),
        Index("idx_lesson_item_links_vocab", "vocabulary_id"),
        Index("idx_lesson_item_links_grammar", "grammar_id"),
    )


class UserLessonProgress(Base):
    __tablename__ = "user_lesson_progress"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    lesson_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("lessons.id", ondelete="CASCADE"), nullable=False)
    status: Mapped[str] = mapped_column(Text, default="NOT_STARTED")  # NOT_STARTED | IN_PROGRESS | COMPLETED
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    score_correct: Mapped[int] = mapped_column(Integer, default=0)
    score_total: Mapped[int] = mapped_column(Integer, default=0)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    srs_registered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user: Mapped[User] = relationship(back_populates="lesson_progress")  # noqa: F821
    lesson: Mapped[Lesson] = relationship(back_populates="user_progress")

    __table_args__ = (
        UniqueConstraint("user_id", "lesson_id"),
        Index("idx_user_lesson_progress_user", "user_id", "status"),
    )
