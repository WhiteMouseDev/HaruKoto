from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import ARRAY, JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.orm import relationship as sa_relationship

from app.db.base import Base
from app.models.enums import ConversationType, Difficulty, ScenarioCategory


class ConversationScenario(Base):
    __tablename__ = "conversation_scenarios"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    title_ja: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[ScenarioCategory] = mapped_column(nullable=False)
    difficulty: Mapped[Difficulty] = mapped_column(nullable=False)
    estimated_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    key_expressions: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    situation: Mapped[str] = mapped_column(Text, nullable=False)
    your_role: Mapped[str] = mapped_column(Text, nullable=False)
    ai_role: Mapped[str] = mapped_column(Text, nullable=False)
    system_prompt: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversations: Mapped[list[Conversation]] = sa_relationship(back_populates="scenario")


class AiCharacter(Base):
    __tablename__ = "ai_characters"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    name_ja: Mapped[str] = mapped_column(Text, nullable=False)
    name_romaji: Mapped[str] = mapped_column(Text, nullable=False)
    gender: Mapped[str] = mapped_column(Text, nullable=False)
    age_description: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    relationship: Mapped[str] = mapped_column(Text, nullable=False)
    background_story: Mapped[str] = mapped_column(Text, nullable=False)
    personality: Mapped[str] = mapped_column(Text, nullable=False)
    voice_name: Mapped[str] = mapped_column(Text, nullable=False)
    voice_backup: Mapped[str | None] = mapped_column(Text, nullable=True)
    speech_style: Mapped[str] = mapped_column(Text, nullable=False)
    target_level: Mapped[str] = mapped_column(Text, nullable=False)
    silence_ms: Mapped[int] = mapped_column(Integer, default=1200)
    tier: Mapped[str] = mapped_column(Text, default="default")
    unlock_condition: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    avatar_emoji: Mapped[str] = mapped_column(Text, nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    gradient: Mapped[str | None] = mapped_column(Text, nullable=True)
    order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversations: Mapped[list[Conversation]] = sa_relationship(back_populates="character")
    favorited_by: Mapped[list[UserFavoriteCharacter]] = sa_relationship(back_populates="character")  # noqa: F821
    unlocked_by: Mapped[list[UserCharacterUnlock]] = sa_relationship(back_populates="character")  # noqa: F821


class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    scenario_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("conversation_scenarios.id"), nullable=True)
    character_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("ai_characters.id"), nullable=True)
    type: Mapped[ConversationType] = mapped_column(default=ConversationType.TEXT)
    messages: Mapped[dict | list] = mapped_column(JSON, default=list)
    feedback_summary: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    message_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = sa_relationship(back_populates="conversations")  # noqa: F821
    scenario: Mapped[ConversationScenario | None] = sa_relationship(back_populates="conversations")
    character: Mapped[AiCharacter | None] = sa_relationship(back_populates="conversations")
