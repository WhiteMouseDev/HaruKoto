from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, Text, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.enums import JlptLevel, UserGoal


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    nickname: Mapped[str | None] = mapped_column(Text, nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    jlpt_level: Mapped[JlptLevel] = mapped_column(default=JlptLevel.N5)
    goal: Mapped[UserGoal | None] = mapped_column(nullable=True)
    daily_goal: Mapped[int] = mapped_column(Integer, default=10)
    experience_points: Mapped[int] = mapped_column(Integer, default=0)
    level: Mapped[int] = mapped_column(Integer, default=1)
    streak_count: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    last_study_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    subscription_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    call_settings: Mapped[dict | None] = mapped_column(JSON, default=dict)
    show_kana: Mapped[bool] = mapped_column(Boolean, default=False)
    app_settings: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    onboarding_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    quiz_sessions: Mapped[list[QuizSession]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    conversations: Mapped[list[Conversation]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    achievements: Mapped[list[UserAchievement]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    daily_missions: Mapped[list[DailyMission]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    wordbook: Mapped[list[WordbookEntry]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    daily_progress: Mapped[list[DailyProgress]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    vocab_progress: Mapped[list[UserVocabProgress]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    grammar_progress: Mapped[list[UserGrammarProgress]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    notifications: Mapped[list[Notification]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    push_subscriptions: Mapped[list[PushSubscription]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    kana_progress: Mapped[list[UserKanaProgress]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    kana_stages: Mapped[list[UserKanaStage]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    favorite_characters: Mapped[list[UserFavoriteCharacter]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    character_unlocks: Mapped[list[UserCharacterUnlock]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    subscriptions: Mapped[list[Subscription]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    payments: Mapped[list[Payment]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    daily_ai_usage: Mapped[list[DailyAiUsage]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
    study_stage_progress: Mapped[list[UserStudyStageProgress]] = relationship(back_populates="user", cascade="all, delete-orphan")  # noqa: F821
