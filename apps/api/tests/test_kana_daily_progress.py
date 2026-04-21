from __future__ import annotations

import uuid
from datetime import date

import pytest

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


def test_build_daily_progress_increment_statement_rejects_empty_increment():
    with pytest.raises(ValueError, match="At least one daily progress increment"):
        build_daily_progress_increment_statement(
            user_id=uuid.uuid4(),
            today=date(2026, 4, 21),
        )
