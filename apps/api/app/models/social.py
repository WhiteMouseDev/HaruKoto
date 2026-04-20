from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.enums import WordbookSource

if TYPE_CHECKING:
    from app.models.conversation import AiCharacter
    from app.models.user import User


class WordbookEntry(Base):
    __tablename__ = "wordbook_entries"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    word: Mapped[str] = mapped_column(Text, nullable=False)
    reading: Mapped[str] = mapped_column(Text, nullable=False)
    meaning_ko: Mapped[str] = mapped_column(Text, nullable=False)
    source: Mapped[WordbookSource] = mapped_column(default=WordbookSource.MANUAL)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="wordbook")  # noqa: F821

    __table_args__ = (UniqueConstraint("user_id", "word"),)


class UserFavoriteCharacter(Base):
    __tablename__ = "user_favorite_characters"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    character_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("ai_characters.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="favorite_characters")  # noqa: F821
    character: Mapped[AiCharacter] = relationship(back_populates="favorited_by")  # noqa: F821

    __table_args__ = (UniqueConstraint("user_id", "character_id"),)


class UserCharacterUnlock(Base):
    __tablename__ = "user_character_unlocks"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    character_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("ai_characters.id", ondelete="CASCADE"))
    unlocked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="character_unlocks")  # noqa: F821
    character: Mapped[AiCharacter] = relationship(back_populates="unlocked_by")  # noqa: F821

    __table_args__ = (UniqueConstraint("user_id", "character_id"),)
