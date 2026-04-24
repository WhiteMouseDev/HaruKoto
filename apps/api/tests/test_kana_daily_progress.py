from __future__ import annotations

import uuid
from datetime import date

import pytest
from sqlalchemy.dialects import postgresql

from app.services.kana_daily_progress import build_daily_progress_increment_statement


def test_build_daily_progress_increment_statement_can_increment_kana_only():
    stmt = build_daily_progress_increment_statement(
        user_id=uuid.uuid4(),
        today=date(2026, 4, 21),
        kana_learned=1,
    )

    assert "daily_progress" in str(stmt)


def test_build_daily_progress_increment_statement_can_increment_xp_and_kana():
    stmt = build_daily_progress_increment_statement(
        user_id=uuid.uuid4(),
        today=date(2026, 4, 21),
        xp_earned=20,
        kana_learned=4,
    )

    rendered = str(stmt)
    assert "daily_progress" in rendered
    assert "xp_earned" in rendered
    assert "kana_learned" in rendered


def test_build_daily_progress_increment_statement_sets_non_null_insert_defaults():
    stmt = build_daily_progress_increment_statement(
        user_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
        today=date(2026, 4, 21),
        kana_learned=1,
    )

    params = stmt.compile(dialect=postgresql.dialect()).params

    assert params["id"] is not None
    assert params["words_studied"] == 0
    assert params["quizzes_completed"] == 0
    assert params["correct_answers"] == 0
    assert params["total_answers"] == 0
    assert params["conversation_count"] == 0
    assert params["study_time_seconds"] == 0
    assert params["xp_earned"] == 0
    assert params["grammar_studied"] == 0
    assert params["sentences_studied"] == 0
    assert params["study_minutes"] == 0


def test_build_daily_progress_increment_statement_rejects_empty_increment():
    with pytest.raises(ValueError, match="At least one daily progress increment"):
        build_daily_progress_increment_statement(
            user_id=uuid.uuid4(),
            today=date(2026, 4, 21),
        )
