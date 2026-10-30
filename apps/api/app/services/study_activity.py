from __future__ import annotations

from app.models import DailyProgress


def has_study_activity(progress: DailyProgress | None) -> bool:
    """Report positive legacy activity aggregates without changing attendance state."""
    if progress is None:
        return False

    return any(
        (getattr(progress, field, 0) or 0) > 0
        for field in (
            "words_studied",
            "quizzes_completed",
            "conversation_count",
            "xp_earned",
            "kana_learned",
            "grammar_studied",
            "sentences_studied",
            "study_time_seconds",
            "study_minutes",
        )
    )
