from __future__ import annotations

from app.schemas.common import CamelModel


class LearnedWordEntry(CamelModel):
    id: str
    vocabulary_id: str
    word: str
    reading: str | None = None
    meaning_ko: str
    jlpt_level: str
    example_sentence: str | None = None
    example_translation: str | None = None
    correct_count: int
    incorrect_count: int
    streak: int
    mastered: bool
    last_reviewed_at: str | None = None


class LearnedWordsSummary(CamelModel):
    total_learned: int
    mastered: int
    learning: int


class LearnedWordsResponse(CamelModel):
    entries: list[LearnedWordEntry]
    total: int
    page: int
    total_pages: int
    summary: LearnedWordsSummary


class StudyWrongAnswerEntry(CamelModel):
    id: str
    vocabulary_id: str
    word: str
    reading: str | None = None
    meaning_ko: str
    jlpt_level: str
    example_sentence: str | None = None
    example_translation: str | None = None
    correct_count: int
    incorrect_count: int
    mastered: bool
    last_reviewed_at: str | None = None


class StudyWrongAnswersSummary(CamelModel):
    total_wrong: int
    mastered: int
    remaining: int


class StudyWrongAnswersResponse(CamelModel):
    entries: list[StudyWrongAnswerEntry]
    total: int
    page: int
    total_pages: int
    summary: StudyWrongAnswersSummary
