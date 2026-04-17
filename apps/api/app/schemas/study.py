from __future__ import annotations

from pydantic import Field

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


class StudyStageUserProgress(CamelModel):
    best_score: int
    attempts: int
    completed: bool
    completed_at: str | None = None
    last_attempted_at: str | None = None


class StudyStageResponse(CamelModel):
    id: str
    category: str
    jlpt_level: str
    stage_number: int
    title: str
    description: str | None = None
    content_count: int
    is_locked: bool
    user_progress: StudyStageUserProgress | None = None


class QuizCapabilitiesResponse(CamelModel):
    vocabulary: bool = Field(alias="VOCABULARY")
    grammar: bool = Field(alias="GRAMMAR")
    kanji: bool = Field(alias="KANJI")
    listening: bool = Field(alias="LISTENING")
    kana: bool = Field(alias="KANA")
    cloze: bool = Field(alias="CLOZE")
    sentence_arrange: bool = Field(alias="SENTENCE_ARRANGE")


class SmartCategoryCapability(CamelModel):
    available: bool
    has_pool: bool


class SmartCapabilitiesResponse(CamelModel):
    vocabulary: SmartCategoryCapability = Field(alias="VOCABULARY")
    grammar: SmartCategoryCapability = Field(alias="GRAMMAR")


class StageCapabilitiesResponse(CamelModel):
    vocabulary: bool = Field(alias="VOCABULARY")
    grammar: bool = Field(alias="GRAMMAR")
    sentence: bool = Field(alias="SENTENCE")


class StudyCapabilitiesResponse(CamelModel):
    requested_jlpt_level: str
    effective_jlpt_level: str
    quiz: QuizCapabilitiesResponse
    smart: SmartCapabilitiesResponse
    lesson: bool
    stage: StageCapabilitiesResponse
