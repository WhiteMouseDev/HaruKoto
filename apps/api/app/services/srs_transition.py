"""Pure SRS state transition rules.

This module intentionally has no database dependencies. The orchestration layer
loads and persists progress records; this module only mutates transition fields.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Protocol

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PROVISIONAL_STEPS_REQUIRED = 2
PROVISIONAL_INTERVALS = [1, 3]  # days: step 0->1 = 1d, step 1->LEARNING = 3d
LEARNING_INTERVALS = [1, 3]  # days: step 0->1 = 1d, step 1->REVIEW = 3d
MASTERED_THRESHOLD_DAYS = 21
DEFAULT_EASE_FACTOR = 2.5
MIN_EASE_FACTOR = 1.3

# Rating thresholds (response time in ms)
FAST_THRESHOLD_MS = 3_000
SLOW_THRESHOLD_MS = 10_000

# States
UNSEEN = "UNSEEN"
PROVISIONAL = "PROVISIONAL"
LEARNING = "LEARNING"
REVIEW = "REVIEW"
MASTERED = "MASTERED"
RELEARNING = "RELEARNING"

# Ratings
AGAIN = 1
HARD = 2
GOOD = 3
EASY = 4


class SrsProgressRecord(Protocol):
    state: str
    learning_step: int
    next_review_at: datetime | None
    ease_factor: float
    interval: int
    mastered: bool
    streak: int


def calculate_rating(is_correct: bool, response_ms: int) -> int:
    """Determine rating 1-4 based on correctness and response time."""
    if not is_correct:
        return AGAIN
    if response_ms < FAST_THRESHOLD_MS:
        return EASY
    if response_ms <= SLOW_THRESHOLD_MS:
        return GOOD
    return HARD


def apply_transition(
    progress: SrsProgressRecord,
    is_correct: bool,
    rating: int,
    now: datetime,
) -> None:
    """Apply SRS state transition based on current state and answer correctness."""
    state = progress.state

    if state == PROVISIONAL:
        _transition_provisional(progress, is_correct, now)
    elif state == LEARNING:
        _transition_learning(progress, is_correct, rating, now)
    elif state == REVIEW:
        _transition_review(progress, is_correct, rating, now)
    elif state == MASTERED:
        _transition_mastered(progress, is_correct, rating, now)
    elif state == RELEARNING:
        _transition_relearning(progress, is_correct, now)
    # UNSEEN is handled before this function is called.


def _sm2_update_correct(ease_factor: float, interval: int) -> tuple[float, int]:
    """SM-2 correct answer: increase ease_factor, multiply interval."""
    new_ef = ease_factor + 0.1
    new_interval = max(int(interval * new_ef), 1) if interval > 0 else 1
    return new_ef, new_interval


def _sm2_update_incorrect(ease_factor: float) -> tuple[float, int]:
    """SM-2 incorrect answer: decrease ease_factor, reset interval."""
    new_ef = max(ease_factor - 0.2, MIN_EASE_FACTOR)
    return new_ef, 1


def _transition_provisional(
    progress: SrsProgressRecord,
    is_correct: bool,
    now: datetime,
) -> None:
    """PROVISIONAL phase: must pass 2 consecutive correct answers."""
    if is_correct:
        progress.learning_step += 1
        if progress.learning_step >= PROVISIONAL_STEPS_REQUIRED:
            progress.state = LEARNING
            progress.learning_step = 0
            progress.next_review_at = now + timedelta(days=LEARNING_INTERVALS[0])
        else:
            step_idx = min(progress.learning_step, len(PROVISIONAL_INTERVALS) - 1)
            progress.next_review_at = now + timedelta(days=PROVISIONAL_INTERVALS[step_idx])
    else:
        progress.learning_step = 0
        progress.next_review_at = now + timedelta(days=1)


def _transition_learning(
    progress: SrsProgressRecord,
    is_correct: bool,
    rating: int,
    now: datetime,
) -> None:
    """LEARNING phase: pass learning steps then move to REVIEW."""
    if is_correct:
        progress.learning_step += 1
        if progress.learning_step >= len(LEARNING_INTERVALS):
            progress.state = REVIEW
            progress.learning_step = 0
            progress.interval = LEARNING_INTERVALS[-1]
            ef, new_interval = _sm2_update_correct(progress.ease_factor, progress.interval)
            progress.ease_factor = ef
            progress.interval = new_interval
            progress.next_review_at = now + timedelta(days=new_interval)
        else:
            step_idx = min(progress.learning_step, len(LEARNING_INTERVALS) - 1)
            progress.next_review_at = now + timedelta(days=LEARNING_INTERVALS[step_idx])
    else:
        progress.learning_step = 0
        progress.streak = 0
        progress.next_review_at = now + timedelta(days=1)


def _transition_review(
    progress: SrsProgressRecord,
    is_correct: bool,
    rating: int,
    now: datetime,
) -> None:
    """REVIEW phase: SM-2 interval scheduling."""
    if is_correct:
        ef, new_interval = _sm2_update_correct(progress.ease_factor, progress.interval)
        progress.ease_factor = ef
        progress.interval = new_interval
        progress.next_review_at = now + timedelta(days=new_interval)

        if new_interval >= MASTERED_THRESHOLD_DAYS:
            progress.state = MASTERED
            progress.mastered = True
    else:
        ef, new_interval = _sm2_update_incorrect(progress.ease_factor)
        progress.state = RELEARNING
        progress.ease_factor = ef
        progress.interval = new_interval
        progress.learning_step = 0
        progress.next_review_at = now + timedelta(days=1)


def _transition_mastered(
    progress: SrsProgressRecord,
    is_correct: bool,
    rating: int,
    now: datetime,
) -> None:
    """MASTERED phase: long-term review."""
    if is_correct:
        ef, new_interval = _sm2_update_correct(progress.ease_factor, progress.interval)
        progress.ease_factor = ef
        progress.interval = new_interval
        progress.next_review_at = now + timedelta(days=new_interval)
    else:
        ef, new_interval = _sm2_update_incorrect(progress.ease_factor)
        progress.state = RELEARNING
        progress.ease_factor = ef
        progress.interval = new_interval
        progress.learning_step = 0
        progress.mastered = False
        progress.next_review_at = now + timedelta(days=1)


def _transition_relearning(
    progress: SrsProgressRecord,
    is_correct: bool,
    now: datetime,
) -> None:
    """RELEARNING phase: re-study after a lapse."""
    if is_correct:
        progress.state = REVIEW
        progress.interval = 1
        progress.learning_step = 0
        progress.next_review_at = now + timedelta(days=1)
    else:
        progress.next_review_at = now + timedelta(days=1)
