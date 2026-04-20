from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING, Any

from sqlalchemy import DateTime, Integer, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import ARRAY, JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.enums import JlptLevel, PartOfSpeech, ReviewStatus

if TYPE_CHECKING:
    from app.models.progress import UserGrammarProgress, UserVocabProgress


class Vocabulary(Base):
    __tablename__ = "vocabularies"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    jlpt_level: Mapped[JlptLevel] = mapped_column(nullable=False)
    word: Mapped[str] = mapped_column(Text, nullable=False)
    reading: Mapped[str] = mapped_column(Text, nullable=False)
    meaning_ko: Mapped[str] = mapped_column(Text, nullable=False)
    example_sentence: Mapped[str | None] = mapped_column(Text, nullable=True)
    example_reading: Mapped[str | None] = mapped_column(Text, nullable=True)
    example_translation: Mapped[str | None] = mapped_column(Text, nullable=True)
    part_of_speech: Mapped[PartOfSpeech] = mapped_column(nullable=False)
    tags: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    audio_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    order: Mapped[int] = mapped_column(Integer, default=0)
    meaning_glosses_ko: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    synonym_group_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    category_tag: Mapped[str | None] = mapped_column(Text, nullable=True)
    review_status: Mapped[ReviewStatus] = mapped_column(nullable=False, server_default="needs_review")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user_progress: Mapped[list[UserVocabProgress]] = relationship(back_populates="vocabulary", cascade="all, delete-orphan")  # noqa: F821

    __table_args__ = (UniqueConstraint("word", "reading", "jlpt_level"),)


class Grammar(Base):
    __tablename__ = "grammars"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    jlpt_level: Mapped[JlptLevel] = mapped_column(nullable=False)
    pattern: Mapped[str] = mapped_column(Text, nullable=False)
    meaning_ko: Mapped[str] = mapped_column(Text, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    example_sentences: Mapped[dict[str, Any] | list[Any]] = mapped_column(JSON, default=list)
    related_grammar_ids: Mapped[list[uuid.UUID]] = mapped_column(ARRAY(UUID(as_uuid=True)), default=list)
    order: Mapped[int] = mapped_column(Integer, default=0)
    meaning_glosses_ko: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    synonym_group_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    review_status: Mapped[ReviewStatus] = mapped_column(nullable=False, server_default="needs_review")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user_progress: Mapped[list[UserGrammarProgress]] = relationship(back_populates="grammar", cascade="all, delete-orphan")  # noqa: F821

    __table_args__ = (UniqueConstraint("pattern", "jlpt_level"),)


class ClozeQuestion(Base):
    __tablename__ = "cloze_questions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sentence: Mapped[str] = mapped_column(Text, nullable=False)
    translation: Mapped[str] = mapped_column(Text, nullable=False)
    correct_answer: Mapped[str] = mapped_column(Text, nullable=False)
    options: Mapped[dict[str, Any] | list[Any]] = mapped_column(JSON, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    grammar_point: Mapped[str | None] = mapped_column(Text, nullable=True)
    jlpt_level: Mapped[JlptLevel] = mapped_column(nullable=False)
    difficulty: Mapped[int] = mapped_column(Integer, default=1)
    order: Mapped[int] = mapped_column(Integer, default=0)
    review_status: Mapped[ReviewStatus] = mapped_column(nullable=False, server_default="needs_review")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (UniqueConstraint("sentence", "jlpt_level"),)


class SentenceArrangeQuestion(Base):
    __tablename__ = "sentence_arrange_questions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    korean_sentence: Mapped[str] = mapped_column(Text, nullable=False)
    japanese_sentence: Mapped[str] = mapped_column(Text, nullable=False)
    tokens: Mapped[dict[str, Any] | list[Any]] = mapped_column(JSON, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    grammar_point: Mapped[str | None] = mapped_column(Text, nullable=True)
    jlpt_level: Mapped[JlptLevel] = mapped_column(nullable=False)
    difficulty: Mapped[int] = mapped_column(Integer, default=1)
    order: Mapped[int] = mapped_column(Integer, default=0)
    review_status: Mapped[ReviewStatus] = mapped_column(nullable=False, server_default="needs_review")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (UniqueConstraint("korean_sentence", "jlpt_level"),)
