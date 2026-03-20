"""Lesson API schemas (request/response)."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from app.schemas.common import CamelModel

# ── Response: 챕터 목록 ──


class LessonSummary(CamelModel):
    id: UUID
    lesson_no: int
    chapter_lesson_no: int
    title: str
    topic: str
    estimated_minutes: int
    status: str = "NOT_STARTED"  # NOT_STARTED | IN_PROGRESS | COMPLETED
    score_correct: int = 0
    score_total: int = 0


class ChapterResponse(CamelModel):
    id: UUID
    jlpt_level: str
    part_no: int
    chapter_no: int
    title: str
    topic: str | None = None
    lessons: list[LessonSummary]
    completed_lessons: int = 0
    total_lessons: int = 0


class ChapterListResponse(CamelModel):
    chapters: list[ChapterResponse]


# ── Response: 레슨 상세 ──


class ScriptLine(CamelModel):
    speaker: str
    voice_id: str
    text: str
    translation: str | None = None


class Reading(CamelModel):
    type: str = "dialogue"
    scene: str | None = None
    script: list[ScriptLine]
    highlights: list[str] = []
    audio_url: str | None = None


class QuestionOption(CamelModel):
    id: str
    text: str


class Question(CamelModel):
    order: int
    type: str  # VOCAB_MCQ | CONTEXT_CLOZE | SENTENCE_REORDER
    cognitive_level: str | None = None
    prompt: str
    options: list[QuestionOption] | None = None  # MCQ/CLOZE
    tokens: list[str] | None = None  # SENTENCE_REORDER
    correct_order: list[str] | None = None  # SENTENCE_REORDER (stripped for client)
    correct_answer: str | None = None  # MCQ/CLOZE (stripped for client)
    explanation: str | None = None  # shown after answer


class LessonContent(CamelModel):
    reading: Reading
    questions: list[Question]


class VocabItem(CamelModel):
    id: UUID
    word: str
    reading: str
    meaning_ko: str
    part_of_speech: str


class GrammarItem(CamelModel):
    id: UUID
    pattern: str
    meaning_ko: str
    explanation: str


class LessonDetailResponse(CamelModel):
    id: UUID
    lesson_no: int
    chapter_lesson_no: int
    title: str
    subtitle: str | None = None
    topic: str
    estimated_minutes: int
    content: LessonContent
    vocab_items: list[VocabItem]
    grammar_items: list[GrammarItem]
    progress: LessonProgressResponse | None = None


# ── Response: 레슨 진도 ──


class LessonProgressResponse(CamelModel):
    status: str
    attempts: int
    score_correct: int
    score_total: int
    started_at: datetime | None = None
    completed_at: datetime | None = None


# ── Request: 퀴즈 제출 ──


class AnswerSubmission(CamelModel):
    order: int
    selected_answer: str | None = None  # MCQ/CLOZE: option id
    submitted_order: list[str] | None = None  # SENTENCE_REORDER: token order
    response_ms: int = 0


class LessonSubmitRequest(CamelModel):
    answers: list[AnswerSubmission]


class QuestionResult(CamelModel):
    order: int
    is_correct: bool
    correct_answer: str | None = None
    correct_order: list[str] | None = None
    explanation: str | None = None


class LessonSubmitResponse(CamelModel):
    score_correct: int
    score_total: int
    results: list[QuestionResult]
    status: str  # IN_PROGRESS | COMPLETED
