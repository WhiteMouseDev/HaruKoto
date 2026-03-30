from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from app.schemas.common import CamelModel

# ---------------------------------------------------------------------------
# List view schemas (existing — do not modify)
# ---------------------------------------------------------------------------


class VocabularyAdminItem(CamelModel):
    id: uuid.UUID
    word: str
    reading: str
    meaning_ko: str
    jlpt_level: str
    review_status: str
    created_at: datetime


class GrammarAdminItem(CamelModel):
    id: uuid.UUID
    pattern: str
    explanation: str
    meaning_ko: str
    jlpt_level: str
    review_status: str
    created_at: datetime


class QuizAdminItem(CamelModel):
    id: uuid.UUID
    sentence: str  # sentence for cloze, korean_sentence for sentence_arrange
    quiz_type: str  # "cloze" or "sentence_arrange"
    jlpt_level: str
    review_status: str
    created_at: datetime


class ConversationAdminItem(CamelModel):
    id: uuid.UUID
    title: str
    category: str
    jlpt_level: str | None  # conversation_scenarios has no jlpt_level column
    review_status: str
    created_at: datetime


class ContentStatsItem(CamelModel):
    content_type: str
    needs_review: int
    approved: int
    rejected: int
    total: int


class ContentStatsResponse(CamelModel):
    stats: list[ContentStatsItem]


# ---------------------------------------------------------------------------
# Detail response schemas (for single-item GET)
# ---------------------------------------------------------------------------


class VocabularyDetailResponse(CamelModel):
    id: uuid.UUID
    word: str
    reading: str
    meaning_ko: str
    jlpt_level: str
    part_of_speech: str | None
    example_sentence: str | None
    example_reading: str | None
    example_translation: str | None
    review_status: str
    created_at: datetime
    updated_at: datetime | None


class GrammarDetailResponse(CamelModel):
    id: uuid.UUID
    pattern: str
    meaning_ko: str
    explanation: str | None
    example_sentences: list | None  # JSON
    jlpt_level: str
    review_status: str
    created_at: datetime
    updated_at: datetime | None


class ClozeQuestionDetailResponse(CamelModel):
    id: uuid.UUID
    sentence: str
    translation: str
    correct_answer: str
    options: list | None  # JSON
    explanation: str | None
    jlpt_level: str
    review_status: str
    created_at: datetime
    updated_at: datetime | None


class SentenceArrangeDetailResponse(CamelModel):
    id: uuid.UUID
    korean_sentence: str
    japanese_sentence: str
    tokens: list | None  # JSON
    explanation: str | None
    jlpt_level: str
    review_status: str
    created_at: datetime
    updated_at: datetime | None


class ConversationDetailResponse(CamelModel):
    id: uuid.UUID
    title: str
    title_ja: str | None
    description: str | None
    situation: str | None
    your_role: str | None
    ai_role: str | None
    system_prompt: str | None
    key_expressions: list | None  # JSON
    category: str
    review_status: str
    created_at: datetime
    updated_at: datetime | None


# ---------------------------------------------------------------------------
# Update request schemas (all fields Optional for PATCH — D-11)
# ---------------------------------------------------------------------------


class VocabularyUpdateRequest(CamelModel):
    word: str | None = None
    reading: str | None = None
    meaning_ko: str | None = None
    part_of_speech: str | None = None
    example_sentence: str | None = None
    example_reading: str | None = None
    example_translation: str | None = None


class GrammarUpdateRequest(CamelModel):
    pattern: str | None = None
    meaning_ko: str | None = None
    explanation: str | None = None


class ClozeQuestionUpdateRequest(CamelModel):
    sentence: str | None = None
    translation: str | None = None
    correct_answer: str | None = None
    options: list | None = None
    explanation: str | None = None


class SentenceArrangeUpdateRequest(CamelModel):
    korean_sentence: str | None = None
    japanese_sentence: str | None = None
    tokens: list | None = None
    explanation: str | None = None


class ConversationUpdateRequest(CamelModel):
    title: str | None = None
    title_ja: str | None = None
    description: str | None = None
    situation: str | None = None
    your_role: str | None = None
    ai_role: str | None = None
    system_prompt: str | None = None
    key_expressions: list | None = None


# ---------------------------------------------------------------------------
# Review and audit log schemas
# ---------------------------------------------------------------------------


class ReviewRequest(CamelModel):
    action: Literal["approve", "reject"]
    reason: str | None = None


class BatchReviewRequest(CamelModel):
    content_type: Literal["vocabulary", "grammar", "cloze", "sentence_arrange", "conversation"]
    ids: list[uuid.UUID]
    action: Literal["approve", "reject"]
    reason: str | None = None


class AuditLogItem(CamelModel):
    id: uuid.UUID
    action: str
    changes: dict | None
    reason: str | None
    reviewer_id: uuid.UUID
    created_at: datetime


class OkResponse(CamelModel):
    ok: bool = True
    count: int = 0


# ---------------------------------------------------------------------------
# TTS schemas (Phase 4)
# ---------------------------------------------------------------------------


class AdminTtsResponse(CamelModel):
    audio_url: str | None
    field: str | None
    provider: str | None


class AdminTtsRegenerateRequest(CamelModel):
    content_type: Literal["vocabulary", "grammar", "cloze", "sentence_arrange", "conversation"]
    item_id: str
    field: str  # "reading", "word", "example_sentence", "pattern", "sentence", "japanese_sentence", "situation"


# ---------------------------------------------------------------------------
# Review queue schemas (Phase 5)
# ---------------------------------------------------------------------------


class ReviewQueueItem(CamelModel):
    id: str
    quiz_type: str | None = None  # only for quiz content type: "cloze" or "sentence_arrange"


class ReviewQueueResponse(CamelModel):
    ids: list[ReviewQueueItem]
    total: int
    capped: bool
