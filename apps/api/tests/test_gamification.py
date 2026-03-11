from datetime import UTC, date, datetime, timedelta

from app.services.gamification import calculate_level, update_streak


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
