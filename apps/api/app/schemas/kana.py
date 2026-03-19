from __future__ import annotations

from typing import Any
from uuid import UUID

from pydantic import Field

from app.models.enums import KanaType
from app.schemas.common import CamelModel


class KanaCharacterResponse(CamelModel):
    id: UUID
    kana_type: KanaType
    character: str
    romaji: str
    stroke_order: list[str] | None = None
    audio_url: str | None = None
    stage_number: int
    display_order: int


class KanaStat(CamelModel):
    learned: int
    mastered: int
    total: int


class KanaStageResponse(CamelModel):
    id: UUID
    kana_type: KanaType
    stage_number: int
    title: str
    description: str | None = None
    characters: list[KanaCharacterResponse]
    is_unlocked: bool | None = None
    is_completed: bool | None = None
    quiz_score: int | None = None


class KanaProgressResponse(CamelModel):
    hiragana: KanaStat
    katakana: KanaStat


class KanaProgressRecord(CamelModel):
    """Request body for recording kana learning progress."""

    kana_id: UUID = Field(..., description="ID of the kana character learned")


class KanaQuizStartRequest(CamelModel):
    kana_type: KanaType
    stage_number: int | None = None
    quiz_mode: str = "recognition"
    count: int = 10


class KanaQuizStartResponse(CamelModel):
    session_id: UUID
    questions: list[dict[str, Any]]
    total_questions: int


class KanaQuizAnswerRequest(CamelModel):
    session_id: UUID
    question_id: UUID
    selected_option_id: str


class KanaQuizAnswerResponse(CamelModel):
    is_correct: bool
    correct_option_id: str


class KanaQuizCompleteRequest(CamelModel):
    session_id: UUID


class KanaQuizCompleteResponse(CamelModel):
    accuracy: int
    xp_earned: int
    level: int
    current_xp: int
    xp_for_next: int
    events: list[dict[str, Any]]


class KanaStageCompleteRequest(CamelModel):
    stage_id: UUID
    quiz_score: int | None = None


class KanaStageCompleteResponse(CamelModel):
    success: bool
    xp_earned: int
    level: int
    current_xp: int
    xp_for_next: int
    events: list[dict[str, Any]]
    next_stage_unlocked: bool
