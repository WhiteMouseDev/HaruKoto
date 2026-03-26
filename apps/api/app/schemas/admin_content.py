from __future__ import annotations

import uuid
from datetime import datetime

from app.schemas.common import CamelModel


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
    question_text: str  # sentence for cloze, korean_sentence for sentence_arrange
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
