from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class UserVocabProgress(Base):
    __tablename__ = "user_vocab_progress"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    vocabulary_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vocabularies.id", ondelete="CASCADE"))

    # Legacy SM-2 fields (유지)
    correct_count: Mapped[int] = mapped_column(Integer, default=0)
    incorrect_count: Mapped[int] = mapped_column(Integer, default=0)
    streak: Mapped[int] = mapped_column(Integer, default=0)
    ease_factor: Mapped[float] = mapped_column(Float, default=2.5)
    interval: Mapped[int] = mapped_column(Integer, default=0)
    next_review_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    mastered: Mapped[bool] = mapped_column(Boolean, default=False)

    # SRS 상태 (신규)
    state: Mapped[str] = mapped_column(Text, default="UNSEEN")  # UNSEEN|LEARNING|REVIEW|MASTERED|RELEARNING
    introduced_by: Mapped[str | None] = mapped_column(Text, nullable=True)  # LESSON|QUIZ
    learning_step: Mapped[int] = mapped_column(SmallInteger, default=0)
    source_lesson_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    # FSRS 필드 (SM-2와 공존)
    fsrs_stability: Mapped[float] = mapped_column(Float, default=0)
    fsrs_difficulty: Mapped[float] = mapped_column(Float, default=5)
    fsrs_last_rating: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    fsrs_reps: Mapped[int] = mapped_column(Integer, default=0)
    fsrs_lapses: Mapped[int] = mapped_column(Integer, default=0)

    # 스케줄러 버전
    scheduler_version: Mapped[int] = mapped_column(SmallInteger, default=1)  # 1=SM-2, 2=FSRS

    # 방향별 통계
    jp_kr_correct: Mapped[int] = mapped_column(Integer, default=0)
    jp_kr_total: Mapped[int] = mapped_column(Integer, default=0)
    kr_jp_correct: Mapped[int] = mapped_column(Integer, default=0)
    kr_jp_total: Mapped[int] = mapped_column(Integer, default=0)

    # 찍기 위험도
    guess_risk: Mapped[float] = mapped_column(Numeric(4, 3), default=0)

    # 당일 중복 방지
    last_presented_on: Mapped[date | None] = mapped_column(Date, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user: Mapped[User] = relationship(back_populates="vocab_progress")  # noqa: F821
    vocabulary: Mapped[Vocabulary] = relationship(back_populates="user_progress")  # noqa: F821

    __table_args__ = (UniqueConstraint("user_id", "vocabulary_id"),)


class UserGrammarProgress(Base):
    __tablename__ = "user_grammar_progress"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    grammar_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("grammars.id", ondelete="CASCADE"))

    # Legacy SM-2 fields (유지)
    correct_count: Mapped[int] = mapped_column(Integer, default=0)
    incorrect_count: Mapped[int] = mapped_column(Integer, default=0)
    streak: Mapped[int] = mapped_column(Integer, default=0)
    ease_factor: Mapped[float] = mapped_column(Float, default=2.5)
    interval: Mapped[int] = mapped_column(Integer, default=0)
    next_review_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    mastered: Mapped[bool] = mapped_column(Boolean, default=False)

    # SRS 상태 (신규) — user_vocab_progress와 동일
    state: Mapped[str] = mapped_column(Text, default="UNSEEN")
    introduced_by: Mapped[str | None] = mapped_column(Text, nullable=True)
    learning_step: Mapped[int] = mapped_column(SmallInteger, default=0)
    source_lesson_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    fsrs_stability: Mapped[float] = mapped_column(Float, default=0)
    fsrs_difficulty: Mapped[float] = mapped_column(Float, default=5)
    fsrs_last_rating: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    fsrs_reps: Mapped[int] = mapped_column(Integer, default=0)
    fsrs_lapses: Mapped[int] = mapped_column(Integer, default=0)

    scheduler_version: Mapped[int] = mapped_column(SmallInteger, default=1)

    jp_kr_correct: Mapped[int] = mapped_column(Integer, default=0)
    jp_kr_total: Mapped[int] = mapped_column(Integer, default=0)
    kr_jp_correct: Mapped[int] = mapped_column(Integer, default=0)
    kr_jp_total: Mapped[int] = mapped_column(Integer, default=0)

    guess_risk: Mapped[float] = mapped_column(Numeric(4, 3), default=0)
    last_presented_on: Mapped[date | None] = mapped_column(Date, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user: Mapped[User] = relationship(back_populates="grammar_progress")  # noqa: F821
    grammar: Mapped[Grammar] = relationship(back_populates="user_progress")  # noqa: F821

    __table_args__ = (UniqueConstraint("user_id", "grammar_id"),)
