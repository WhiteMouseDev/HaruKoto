from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass

from app.models import QuizSession
from app.utils.helpers import enum_value


@dataclass(frozen=True, slots=True)
class DailyProgressIncrements:
    words_studied: int
    grammar_studied: int
    sentences_studied: int


def calculate_accuracy(session: QuizSession) -> float:
    if session.total_questions <= 0:
        return 0
    return session.correct_count / session.total_questions * 100


def calculate_study_minutes(answer_seconds: Iterable[int | None]) -> int:
    """Count persisted answer time, never days spent away from an unfinished quiz."""
    return sum(max(0, seconds or 0) for seconds in answer_seconds) // 60


def calculate_daily_progress_increments(session: QuizSession) -> DailyProgressIncrements:
    quiz_type = enum_value(session.quiz_type)
    return DailyProgressIncrements(
        words_studied=session.correct_count if quiz_type in ("VOCABULARY", "KANJI", "LISTENING") else 0,
        grammar_studied=session.correct_count if quiz_type == "GRAMMAR" else 0,
        sentences_studied=session.total_questions if quiz_type in ("CLOZE", "SENTENCE_ARRANGE") else 0,
    )
