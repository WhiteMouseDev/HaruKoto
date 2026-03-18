from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TtsAudio(Base):
    __tablename__ = "tts_audio"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    target_type: Mapped[str] = mapped_column(Text, nullable=False)  # 'vocabulary' | 'kana'
    target_id: Mapped[str] = mapped_column(Text, nullable=False)  # vocab.id or kana text hash
    text: Mapped[str] = mapped_column(Text, nullable=False)  # TTS에 넘긴 실제 텍스트
    speed: Mapped[float] = mapped_column(Float, nullable=False, default=1.0)
    provider: Mapped[str] = mapped_column(Text, nullable=False)  # 'elevenlabs' | 'gemini'
    model: Mapped[str] = mapped_column(Text, nullable=False)  # 'eleven_multilingual_v2' etc.
    audio_url: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (UniqueConstraint("target_type", "target_id", "speed"),)
