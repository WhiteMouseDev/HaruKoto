from __future__ import annotations

from app.models import DailyProgress


def has_study_activity(progress: DailyProgress | None) -> bool:
    """Read explicit lesson completion or positive legacy activity aggregates."""
    if progress is None:
        return False

    return getattr(progress, "lesson_completed", False) is True or any(
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
