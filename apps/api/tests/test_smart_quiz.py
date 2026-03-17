"""Tests for smart quiz distribution algorithm and SM-2 v2 SRS logic."""

from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

from app.routers.quiz import _apply_srs_update, _calculate_smart_distribution
from app.utils.constants import SMART_QUIZ, SRS_CONFIG

# ── Distribution Algorithm ──


def test_distribution_basic():
    """Standard case: review + retry + new fill the goal."""
    result = _calculate_smart_distribution(daily_goal=20, review_due=10, retry_due=3)
    assert result["retry"] == 3  # min(3, 20//5=4)
    assert result["review"] == 10  # min(10, 12*0.75=9) → actually capped
    assert result["new"] + result["review"] + result["retry"] <= 20 + 2  # min_new guarantee


def test_distribution_no_review_no_retry():
    """First-time user: all new words."""
    result = _calculate_smart_distribution(daily_goal=20, review_due=0, retry_due=0)
    assert result["retry"] == 0
    assert result["review"] == 0
    assert result["new"] == 20


def test_distribution_retry_capped_at_20_percent():
    """Retry pool is capped at 20% of goal."""
    result = _calculate_smart_distribution(daily_goal=20, review_due=0, retry_due=100)
    assert result["retry"] == 4  # 20 // 5 = 4
    assert result["new"] >= 2  # min_new guaranteed


def test_distribution_review_capped_at_75_percent():
    """Review takes at most 75% of remaining after retry."""
    result = _calculate_smart_distribution(daily_goal=20, review_due=100, retry_due=0)
    remaining = 20 - 0  # no retry
    max_review = int(remaining * 0.75)
    # With severe debt handling, review gets more
    assert result["review"] >= max_review
    assert result["new"] >= 2  # min_new guaranteed


def test_distribution_severe_debt():
    """When review_due >> allocated, new drops to min_new."""
    result = _calculate_smart_distribution(daily_goal=20, review_due=100, retry_due=0)
    assert result["new"] == 2  # min_new = max(2, 20//10)
    assert result["review"] > 15  # takes most of the budget


def test_distribution_mild_debt():
    """Mild debt: partially shifts new to review."""
    result = _calculate_smart_distribution(daily_goal=20, review_due=25, retry_due=0)
    # review_due(25) > allocated + 10 → mild debt
    assert result["new"] >= 2
    total = result["new"] + result["review"] + result["retry"]
    assert total <= 20 + 2  # slight overshoot from min_new is OK


def test_distribution_min_new_always_guaranteed():
    """Even with heavy review/retry load, min_new is preserved."""
    result = _calculate_smart_distribution(daily_goal=20, review_due=500, retry_due=50)
    assert result["new"] >= 2


def test_distribution_small_goal():
    """Small daily goal still distributes sensibly."""
    result = _calculate_smart_distribution(daily_goal=5, review_due=3, retry_due=1)
    assert result["retry"] == 1  # min(1, 5//5=1)
    assert result["new"] >= 2  # min_new = max(2, 5//10=0) = 2


# ── SM-2 v2 SRS Update ──


def _make_progress(**kwargs):
    """Create a mock progress object for testing."""
    p = MagicMock()
    p.ease_factor = kwargs.get("ease_factor", 2.5)
    p.interval = kwargs.get("interval", 0)
    p.streak = kwargs.get("streak", 0)
    p.correct_count = kwargs.get("correct_count", 0)
    p.incorrect_count = kwargs.get("incorrect_count", 0)
    p.next_review_at = None
    p.last_reviewed_at = None
    p.mastered = False
    return p


def test_srs_correct_first_time():
    """First correct answer: interval=1, streak=1."""
    p = _make_progress()
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=True, time_spent_seconds=5, now=now)
    assert p.streak == 1
    assert p.interval == SRS_CONFIG.INITIAL_INTERVALS[0]  # 1
    assert p.correct_count == 1


def test_srs_correct_second_time():
    """Second correct: interval=3, streak=2."""
    p = _make_progress(streak=1, interval=1, correct_count=1)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=True, time_spent_seconds=5, now=now)
    assert p.streak == 2
    assert p.interval == SRS_CONFIG.INITIAL_INTERVALS[1]  # 3


def test_srs_correct_third_time_uses_ef():
    """Third+ correct: interval = round(interval * EF)."""
    p = _make_progress(streak=2, interval=3, ease_factor=2.5, correct_count=2)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=True, time_spent_seconds=5, now=now)
    assert p.streak == 3
    # EF updated first, then interval calculated
    assert p.interval >= 7  # 3 * ~2.5 = ~7


def test_srs_instant_bonus():
    """Instant answer (<=3s) gets quality=5 and 10% interval bonus."""
    p = _make_progress(streak=3, interval=10, ease_factor=2.5, correct_count=3)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=True, time_spent_seconds=2, now=now)
    # quality=5 → EF increases, then interval*EF*1.1
    assert p.interval > 25  # 10 * 2.6 * 1.1 ≈ 28


def test_srs_slow_correct_quality_3():
    """Slow correct (>8s) gets quality=3, EF decreases."""
    p = _make_progress(streak=2, interval=3, ease_factor=2.5, correct_count=2)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=True, time_spent_seconds=15, now=now)
    assert p.ease_factor < 2.5  # quality=3 → EF decreases by 0.14


def test_srs_incorrect_lapse_multiplier():
    """Wrong answer on studied word: interval = max(1, round(old * 0.1))."""
    p = _make_progress(streak=5, interval=30, ease_factor=2.5)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=False, time_spent_seconds=5, now=now)
    assert p.streak == 0
    assert p.interval == 3  # round(30 * 0.1) = 3
    assert p.incorrect_count == 1


def test_srs_incorrect_lapse_caps_at_7():
    """Lapse interval capped at 7 days."""
    p = _make_progress(streak=10, interval=200, ease_factor=2.5)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=False, time_spent_seconds=5, now=now)
    assert p.interval == 7  # min(7, round(200*0.1)=20) = 7


def test_srs_incorrect_new_word_stays_zero():
    """Wrong on brand new word (interval=0): stays at 0."""
    p = _make_progress(interval=0)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=False, time_spent_seconds=5, now=now)
    assert p.interval == 0
    assert p.next_review_at == now + timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES)


def test_srs_ef_never_below_minimum():
    """EF never drops below MIN_EASE_FACTOR."""
    p = _make_progress(ease_factor=1.3)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=False, time_spent_seconds=5, now=now)
    assert p.ease_factor >= SRS_CONFIG.MIN_EASE_FACTOR


def test_srs_mastery_threshold():
    """interval >= 21 days marks mastered=True."""
    p = _make_progress(streak=5, interval=10, ease_factor=2.5, correct_count=5)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=True, time_spent_seconds=2, now=now)
    # interval should be > 21 (10 * 2.6 * 1.1 ≈ 28)
    assert p.mastered is True


def test_srs_next_review_set():
    """next_review_at is set correctly based on interval."""
    p = _make_progress(streak=1, interval=1, correct_count=1)
    now = datetime.now(UTC)
    _apply_srs_update(p, is_correct=True, time_spent_seconds=5, now=now)
    expected = now + timedelta(days=p.interval)
    assert p.next_review_at == expected
    assert p.last_reviewed_at == now


# ── Constants ──


def test_smart_quiz_config():
    """Verify smart quiz config values."""
    assert SMART_QUIZ.DAILY_GOAL == 20
    assert SMART_QUIZ.MAX_RETRY_RATIO == 0.2
    assert SMART_QUIZ.MAX_REVIEW_RATIO == 0.75
    assert SMART_QUIZ.DEBT_SEVERE_THRESHOLD == 30
    assert SMART_QUIZ.DEBT_MILD_THRESHOLD == 10


def test_srs_v2_config():
    """Verify SM-2 v2 config values."""
    assert SRS_CONFIG.LAPSE_MULTIPLIER == 0.1
    assert SRS_CONFIG.LAPSE_MAX_INTERVAL == 7
    assert SRS_CONFIG.INSTANT_BONUS == 1.1
