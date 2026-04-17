from __future__ import annotations

from typing import Any
from uuid import UUID

from app.models.enums import JlptLevel, QuizType
from app.schemas.common import CamelModel


class QuizResumeRequest(CamelModel):
    session_id: UUID


class IncompleteQuizSession(CamelModel):
    id: str
    quiz_type: str
    jlpt_level: str
    total_questions: int
    answered_count: int
    correct_count: int
    started_at: str


class IncompleteQuizResponse(CamelModel):
    session: IncompleteQuizSession | None


class QuizOption(CamelModel):
    id: str
    text: str


class QuizQuestion(CamelModel):
    question_id: str
    question_text: str
    question_sub_text: str | None = None
    hint: str | None = None
    options: list[QuizOption]
    correct_option_id: str | None = None
    # Sentence arrange fields
    tokens: list[str] | None = None
    japanese_sentence: str | None = None
    explanation: str | None = None


class WrongAnswer(CamelModel):
    question_id: str
    word: str | None = None
    reading: str | None = None
    meaning_ko: str | None = None
    example_sentence: str | None = None
    example_translation: str | None = None


class MatchingPair(CamelModel):
    id: str
    word: str
    meaning: str


class QuizStartRequest(CamelModel):
    quiz_type: QuizType
    jlpt_level: JlptLevel
    count: int = 10
    mode: str = "normal"
    stage_id: UUID | None = None


class QuizStartResponse(CamelModel):
    session_id: UUID
    questions: list[QuizQuestion]
    total_questions: int
    matching_pairs: list[MatchingPair] | None = None


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
    stage_id: UUID | None = None


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


class QuizResumeResponse(CamelModel):
    session_id: str
    questions: list[QuizQuestion]
    answered_question_ids: list[str]
    total_questions: int
    correct_count: int
    quiz_type: str


class QuizStatsResponse(CamelModel):
    total_quizzes: int
    total_correct: int
    total_questions: int
    accuracy: float


class ContentQuizStatsResponse(CamelModel):
    total_count: int
    studied_count: int
    progress: int


class WrongAnswersResponse(CamelModel):
    wrong_answers: list[WrongAnswer]


class RecommendationsResponse(CamelModel):
    review_due_count: int
    new_words_count: int
    wrong_count: int
    last_reviewed_at: str | None = None


# ── Smart Quiz ──


class PoolSize(CamelModel):
    new_ready: int
    review_due: int
    retry_due: int


class SessionDistribution(CamelModel):
    new: int
    review: int
    retry: int
    total: int


class OverallProgress(CamelModel):
    total: int
    studied: int
    mastered: int
    percentage: int


class SmartPreviewResponse(CamelModel):
    pool_size: PoolSize
    session_distribution: SessionDistribution
    daily_goal: int
    today_completed: int
    overall_progress: OverallProgress


class SmartStartRequest(CamelModel):
    category: str = "VOCABULARY"
    jlpt_level: JlptLevel = JlptLevel.N5
    count: int = 20
