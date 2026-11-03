from __future__ import annotations

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


def test_calculate_study_minutes_counts_only_persisted_nonnegative_answer_seconds():
    assert calculate_study_minutes([]) == 0
    assert calculate_study_minutes([None, 0, -30]) == 0
    assert calculate_study_minutes([30, 60]) == 1
    assert calculate_study_minutes([59]) == 0
    assert calculate_study_minutes([61, 59]) == 2


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
