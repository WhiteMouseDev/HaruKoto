from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from app.models.enums import ConversationType, Difficulty, ScenarioCategory
from app.schemas.common import CamelModel


class ChatMessage(CamelModel):
    message_ja: str
    message_ko: str
    hint: str | None = None


class ChatStartRequest(CamelModel):
    scenario_id: UUID | None = None
    character_id: UUID | None = None
    type: ConversationType = ConversationType.TEXT


class ChatStartResponse(CamelModel):
    conversation_id: UUID
    first_message: ChatMessage


class ChatMessageRequest(CamelModel):
    conversation_id: UUID
    message: str


class ChatMessageResponse(CamelModel):
    message_ja: str
    message_ko: str
    feedback: list[dict[str, Any]] | None = None
    hint: str | None = None
    new_vocabulary: list[dict[str, Any]] | None = None


class ChatEndRequest(CamelModel):
    conversation_id: UUID


class ChatEndResponse(CamelModel):
    success: bool
    feedback_summary: dict[str, Any] | None = None
    xp_earned: int
    events: list[dict[str, Any]]


class ChatHistoryItem(CamelModel):
    id: UUID
    scenario_title: str | None = None
    category: ScenarioCategory | None = None
    difficulty: Difficulty | None = None
    character_name: str | None = None
    character_emoji: str | None = None
    message_count: int
    overall_score: float | None = None
    created_at: datetime
    ended_at: datetime | None = None


class ChatTTSRequest(CamelModel):
    text: str
    voice_name: str | None = None


class TranscribeRequest(CamelModel):
    pass


class LiveTokenRequest(CamelModel):
    character_id: UUID | None = None


class LiveFeedbackRequest(CamelModel):
    conversation_id: UUID
    duration: int
