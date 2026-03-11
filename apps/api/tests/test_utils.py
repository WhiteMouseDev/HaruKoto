from datetime import date, datetime, timedelta

from app.utils.constants import (
    AI_LIMITS,
    KANA_REWARDS,
    PAGINATION,
    PRICES,
    QUIZ_CONFIG,
    RATE_LIMITS,
    REWARDS,
    SRS_CONFIG,
)
from app.utils.date import KST, get_now_kst, get_today_kst
from app.utils.shuffle import shuffle

# ---- date utils ----


def test_kst_offset():
    """KST timezone is UTC+9."""
    assert KST.utcoffset(None) == timedelta(hours=9)


def test_get_today_kst_returns_date():
    """get_today_kst returns a date object."""
    result = get_today_kst()
    assert isinstance(result, date)


def test_get_today_kst_matches_kst():
    """get_today_kst equals now(KST).date()."""
    result = get_today_kst()
    expected = datetime.now(KST).date()
    assert result == expected


def test_get_now_kst_returns_datetime():
    """get_now_kst returns a datetime object."""
    result = get_now_kst()
    assert isinstance(result, datetime)


def test_get_now_kst_has_kst_timezone():
    """get_now_kst returns a KST-aware datetime."""
    result = get_now_kst()
    assert result.utcoffset() == timedelta(hours=9)


# ---- shuffle ----


def test_shuffle_returns_new_list():
    """shuffle returns a new list, not the original."""
    original = [1, 2, 3, 4, 5]
    result = shuffle(original)
    assert result is not original
    assert original == [1, 2, 3, 4, 5]  # original unchanged


def test_shuffle_same_elements():
    """shuffle contains the same elements as the original."""
    original = [1, 2, 3, 4, 5]
    result = shuffle(original)
    assert sorted(result) == sorted(original)


def test_shuffle_empty_list():
    """shuffle handles empty list."""
    assert shuffle([]) == []


def test_shuffle_single_element():
    """shuffle handles single element list."""
    assert shuffle([42]) == [42]


# ---- constants ----


def test_rewards_values():
    assert REWARDS.QUIZ_XP_PER_CORRECT == 10
    assert REWARDS.CONVERSATION_COMPLETE_XP == 20


def test_quiz_config_values():
    assert QUIZ_CONFIG.DEFAULT_COUNT == 10
    assert QUIZ_CONFIG.ACCURACY_THRESHOLDS.GREAT == 80
    assert QUIZ_CONFIG.ACCURACY_THRESHOLDS.GOOD == 50
    assert QUIZ_CONFIG.REVIEW_RATIO == 0.6
    assert QUIZ_CONFIG.WRONG_OPTIONS_COUNT == 3


def test_srs_config_values():
    assert SRS_CONFIG.SPEED_THRESHOLDS.INSTANT == 3
    assert SRS_CONFIG.SPEED_THRESHOLDS.QUICK == 8
    assert SRS_CONFIG.INITIAL_INTERVALS == (1, 3)
    assert SRS_CONFIG.MASTERY_INTERVAL == 21
    assert SRS_CONFIG.MIN_EASE_FACTOR == 1.3
    assert SRS_CONFIG.INCORRECT_PENALTY == 0.2
    assert SRS_CONFIG.REVIEW_DELAY_MINUTES == 10


def test_kana_rewards_values():
    assert KANA_REWARDS.STAGE_COMPLETE_XP == 30
    assert KANA_REWARDS.QUIZ_PERFECT_XP == 20
    assert KANA_REWARDS.QUIZ_PASS_XP == 10


def test_pagination_values():
    assert PAGINATION.DEFAULT_PAGE_SIZE == 20
    assert PAGINATION.MAX_PAGE_SIZE == 50


def test_ai_limits_free():
    assert AI_LIMITS.FREE.CHAT_COUNT == 3
    assert AI_LIMITS.FREE.CHAT_SECONDS == 300
    assert AI_LIMITS.FREE.CALL_COUNT == 1
    assert AI_LIMITS.FREE.CALL_SECONDS == 180


def test_ai_limits_premium():
    assert AI_LIMITS.PREMIUM.CHAT_COUNT == 50
    assert AI_LIMITS.PREMIUM.CHAT_SECONDS == 600
    assert AI_LIMITS.PREMIUM.CALL_COUNT == 20
    assert AI_LIMITS.PREMIUM.CALL_SECONDS == 600


def test_prices():
    assert PRICES.MONTHLY == 4900
    assert PRICES.YEARLY == 39900


def test_rate_limits():
    assert RATE_LIMITS.AI.max_requests == 20
    assert RATE_LIMITS.AI.window_seconds == 60
    assert RATE_LIMITS.API.max_requests == 60
    assert RATE_LIMITS.AUTH.max_requests == 10
    assert RATE_LIMITS.LIVE_TOKEN.max_requests == 5


def test_constants_are_frozen():
    """Frozen dataclasses should reject attribute assignment."""
    import dataclasses

    with __import__("pytest").raises(dataclasses.FrozenInstanceError):
        REWARDS.QUIZ_XP_PER_CORRECT = 999
