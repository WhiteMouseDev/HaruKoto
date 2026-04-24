"""Python-side defaults for progress rows created by service code."""

from __future__ import annotations

from datetime import datetime


def new_progress_defaults(now: datetime) -> dict[str, object]:
    """Return defaults required before ORM/server defaults are materialized."""
    return {
        "correct_count": 0,
        "incorrect_count": 0,
        "streak": 0,
        "ease_factor": 2.5,
        "interval": 0,
        "mastered": False,
        "fsrs_stability": 0,
        "fsrs_difficulty": 5,
        "fsrs_reps": 0,
        "fsrs_lapses": 0,
        "scheduler_version": 1,
        "jp_kr_correct": 0,
        "jp_kr_total": 0,
        "kr_jp_correct": 0,
        "kr_jp_total": 0,
        "guess_risk": 0,
        "created_at": now,
        "updated_at": now,
    }
