from __future__ import annotations

import uuid
from datetime import date
from typing import Any


def build_daily_progress_insert_values(
    *,
    user_id: uuid.UUID,
    today: date,
    **overrides: Any,
) -> dict[str, Any]:
    values: dict[str, Any] = {
        "id": uuid.uuid4(),
        "user_id": user_id,
        "date": today,
        "words_studied": 0,
        "quizzes_completed": 0,
        "correct_answers": 0,
        "total_answers": 0,
        "conversation_count": 0,
        "study_time_seconds": 0,
        "xp_earned": 0,
        "kana_learned": 0,
        "grammar_studied": 0,
        "sentences_studied": 0,
        "study_minutes": 0,
    }
    values.update(overrides)
    return values
