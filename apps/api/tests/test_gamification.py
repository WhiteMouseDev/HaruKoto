from datetime import UTC, date, datetime, timedelta

import pytest

from app.services import gamification
from app.services.gamification import calculate_level, update_streak
from app.utils.date import KST


def test_calculate_level_zero_xp():
    result = calculate_level(0)
    assert result["level"] == 1
    assert result["current_xp"] == 0
    assert result["xp_for_next"] == 100


def test_calculate_level_100_xp():
    result = calculate_level(100)
    assert result["level"] == 2
    assert result["current_xp"] == 0
    assert result["xp_for_next"] == 400 - 100  # 300


def test_calculate_level_400_xp():
    result = calculate_level(400)
    assert result["level"] == 3
    assert result["current_xp"] == 0
    assert result["xp_for_next"] == 900 - 400  # 500


def test_calculate_level_500_xp():
    result = calculate_level(500)
    assert result["level"] == 3
    assert result["current_xp"] == 100
    assert result["xp_for_next"] == 500


def test_update_streak_first_study():
    result = update_streak(None, 0, 0)
    assert result["streak_count"] == 1
    assert result["longest_streak"] == 1
    assert result["streak_broken"] is False


def test_update_streak_same_day():
    today = date.today()
    now = datetime(today.year, today.month, today.day, tzinfo=UTC)
    result = update_streak(now, 5, 10, today)
    assert result["streak_count"] == 5
    assert result["longest_streak"] == 10
    assert result["streak_broken"] is False


def test_update_streak_consecutive():
    today = date.today()
    yesterday = datetime(today.year, today.month, today.day, tzinfo=UTC) - timedelta(days=1)
    result = update_streak(yesterday, 3, 5, today)
    assert result["streak_count"] == 4
    assert result["longest_streak"] == 5
    assert result["streak_broken"] is False


def test_update_streak_consecutive_new_record():
    today = date.today()
    yesterday = datetime(today.year, today.month, today.day, tzinfo=UTC) - timedelta(days=1)
    result = update_streak(yesterday, 5, 5, today)
    assert result["streak_count"] == 6
    assert result["longest_streak"] == 6
    assert result["streak_broken"] is False


def test_update_streak_broken():
    today = date.today()
    two_days_ago = datetime(today.year, today.month, today.day, tzinfo=UTC) - timedelta(days=2)
    result = update_streak(two_days_ago, 5, 10, today)
    assert result["streak_count"] == 1
    assert result["longest_streak"] == 10
    assert result["streak_broken"] is True


@pytest.mark.parametrize(
    ("last_study", "today", "current", "expected"),
    [
        (datetime(2026, 9, 28, 15, 30, tzinfo=UTC), date(2026, 9, 29), 1, 1),
        (datetime(2026, 9, 27, 23, tzinfo=UTC), date(2026, 9, 29), 4, 5),
        (datetime(2026, 9, 28, 14, 59, tzinfo=UTC), datetime(2026, 9, 28, 15, tzinfo=UTC), 2, 3),
        (datetime(2026, 9, 28, 15, 30), date(2026, 9, 29), 1, 1),
    ],
    ids=["same-kst-morning", "consecutive-kst-mornings", "kst-midnight", "legacy-naive-utc"],
)
def test_update_streak_uses_kst_learning_days(last_study, today, current, expected):
    result = update_streak(last_study, current, current, today)

    assert result == {
        "streak_count": expected,
        "longest_streak": expected,
        "streak_broken": False,
    }


@pytest.mark.parametrize(
    ("last_study", "today"),
    [
        (date(2026, 9, 29), date(2026, 9, 29)),
        (datetime(2026, 9, 29, 0, 30, tzinfo=KST), date(2026, 9, 29)),
        (datetime(2026, 9, 28, 15, 30, tzinfo=UTC), datetime(2026, 9, 28, 15, 45)),
        (datetime(2026, 9, 30, 3, tzinfo=UTC), date(2026, 9, 29)),
    ],
    ids=["date-value", "aware-kst", "naive-today-utc", "earlier-request-day"],
)
def test_update_streak_keeps_existing_counts_for_same_or_earlier_learning_day(last_study, today):
    assert update_streak(last_study, 4, 9, today) == {
        "streak_count": 4,
        "longest_streak": 9,
        "streak_broken": False,
    }


def test_update_streak_defaults_to_kst_today(monkeypatch):
    monkeypatch.setattr(gamification, "get_today_kst", lambda: date(2026, 9, 29))

    assert update_streak(datetime(2026, 9, 28, 15, 30, tzinfo=UTC), 4, 9) == {
        "streak_count": 4,
        "longest_streak": 9,
        "streak_broken": False,
    }
