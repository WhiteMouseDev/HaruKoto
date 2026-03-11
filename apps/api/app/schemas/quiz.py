from __future__ import annotations

from typing import Any
from uuid import UUID

from app.models.enums import JlptLevel, QuizType
from app.schemas.common import CamelModel


class QuizOption(CamelModel):
    id: str
    text: str


class QuizQuestion(CamelModel):
    id: UUID
    type: QuizType
    question: str
    options: list[QuizOption]
    correct_option_id: str | None = None


class WrongAnswer(CamelModel):
    question_id: UUID
    word: str | None = None
    reading: str | None = None
    meaning_ko: str | None = None
    pattern: str | None = None
    selected_option: str
    correct_option: str


class QuizStartRequest(CamelModel):
    quiz_type: QuizType
    jlpt_level: JlptLevel
    count: int = 10
    mode: str = "normal"


class QuizStartResponse(CamelModel):
    session_id: UUID
    questions: list[QuizQuestion]
    total_questions: int


class QuizAnswerRequest(CamelModel):
    session_id: UUID
    question_id: UUID
    selected_option_id: str
    time_spent_seconds: int = 0
    question_type: QuizType


class QuizAnswerResponse(CamelModel):
    success: bool


class QuizCompleteRequest(CamelModel):
    session_id: UUID


class QuizCompleteResponse(CamelModel):
    session_id: UUID
    correct_count: int
    total_questions: int
    accuracy: float
    xp_earned: int
    level: int
    current_xp: int
    xp_for_next: int
    events: list[dict[str, Any]]
