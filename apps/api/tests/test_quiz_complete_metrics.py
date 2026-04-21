from __future__ import annotations

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

from app.models.enums import QuizType
from app.services.quiz_complete_metrics import (
    DailyProgressIncrements,
    calculate_accuracy,
    calculate_daily_progress_increments,
    calculate_study_minutes,
)


def test_calculate_accuracy_handles_empty_and_scored_sessions():
    assert calculate_accuracy(SimpleNamespace(total_questions=0, correct_count=0)) == 0
    assert calculate_accuracy(SimpleNamespace(total_questions=4, correct_count=3)) == 75.0


def test_calculate_study_minutes_supports_naive_and_aware_start_times():
    now = datetime(2026, 4, 21, 12, 0, tzinfo=UTC)

    assert calculate_study_minutes(SimpleNamespace(started_at=None), now) == 0
    assert calculate_study_minutes(SimpleNamespace(started_at=now + timedelta(minutes=1)), now) == 0
    assert calculate_study_minutes(SimpleNamespace(started_at=datetime(2026, 4, 21, 11, 45)), now) == 15
    assert calculate_study_minutes(SimpleNamespace(started_at=now - timedelta(minutes=7, seconds=30)), now) == 7


def test_calculate_daily_progress_increments_maps_quiz_types():
    assert _increments(QuizType.VOCABULARY) == DailyProgressIncrements(words_studied=3, grammar_studied=0, sentences_studied=0)
    assert _increments(QuizType.KANJI) == DailyProgressIncrements(words_studied=3, grammar_studied=0, sentences_studied=0)
    assert _increments(QuizType.LISTENING) == DailyProgressIncrements(words_studied=3, grammar_studied=0, sentences_studied=0)
    assert _increments(QuizType.GRAMMAR) == DailyProgressIncrements(words_studied=0, grammar_studied=3, sentences_studied=0)
    assert _increments(QuizType.CLOZE) == DailyProgressIncrements(words_studied=0, grammar_studied=0, sentences_studied=5)
    assert _increments(QuizType.SENTENCE_ARRANGE) == DailyProgressIncrements(words_studied=0, grammar_studied=0, sentences_studied=5)


def _increments(quiz_type: QuizType) -> DailyProgressIncrements:
    return calculate_daily_progress_increments(
        SimpleNamespace(
            quiz_type=quiz_type,
            correct_count=3,
            total_questions=5,
        )
    )
