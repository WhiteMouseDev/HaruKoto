from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from app.services.srs_transition import (
    AGAIN,
    EASY,
    GOOD,
    HARD,
    LEARNING,
    MASTERED,
    PROVISIONAL,
    RELEARNING,
    REVIEW,
    apply_transition,
    calculate_rating,
)


@dataclass
class ProgressStub:
    state: str
    learning_step: int = 0
    next_review_at: datetime | None = None
    ease_factor: float = 2.5
    interval: int = 0
    mastered: bool = False
    streak: int = 0


NOW = datetime(2026, 4, 20, 12, 0, tzinfo=UTC)


def test_calculate_rating_uses_correctness_and_response_time() -> None:
    assert calculate_rating(is_correct=False, response_ms=100) == AGAIN
    assert calculate_rating(is_correct=True, response_ms=2_999) == EASY
    assert calculate_rating(is_correct=True, response_ms=3_000) == GOOD
    assert calculate_rating(is_correct=True, response_ms=10_001) == HARD


def test_provisional_second_correct_graduates_to_learning() -> None:
    progress = ProgressStub(state=PROVISIONAL, learning_step=1)

    apply_transition(progress, is_correct=True, rating=HARD, now=NOW)

    assert progress.state == LEARNING
    assert progress.learning_step == 0
    assert progress.next_review_at == NOW + timedelta(days=1)


def test_learning_second_correct_graduates_to_review_with_sm2_interval() -> None:
    progress = ProgressStub(state=LEARNING, learning_step=1, ease_factor=2.5)

    apply_transition(progress, is_correct=True, rating=GOOD, now=NOW)

    assert progress.state == REVIEW
    assert progress.learning_step == 0
    assert progress.ease_factor == 2.6
    assert progress.interval == 7
    assert progress.next_review_at == NOW + timedelta(days=7)


def test_review_correct_marks_mastered_when_interval_reaches_threshold() -> None:
    progress = ProgressStub(state=REVIEW, interval=20, ease_factor=2.5)

    apply_transition(progress, is_correct=True, rating=EASY, now=NOW)

    assert progress.state == MASTERED
    assert progress.mastered is True
    assert progress.interval == 52
    assert progress.next_review_at == NOW + timedelta(days=52)


def test_review_wrong_moves_to_relearning_and_clamps_ease_factor() -> None:
    progress = ProgressStub(state=REVIEW, interval=10, ease_factor=1.35)

    apply_transition(progress, is_correct=False, rating=AGAIN, now=NOW)

    assert progress.state == RELEARNING
    assert progress.ease_factor == 1.3
    assert progress.interval == 1
    assert progress.learning_step == 0
    assert progress.next_review_at == NOW + timedelta(days=1)


def test_relearning_correct_returns_to_review() -> None:
    progress = ProgressStub(state=RELEARNING, learning_step=1, interval=0)

    apply_transition(progress, is_correct=True, rating=GOOD, now=NOW)

    assert progress.state == REVIEW
    assert progress.learning_step == 0
    assert progress.interval == 1
    assert progress.next_review_at == NOW + timedelta(days=1)
