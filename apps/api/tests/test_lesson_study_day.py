"""Study-day semantics without changing XP, due dates, or vocabulary goals."""

from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.study_activity import has_study_activity
from app.services.study_day_recording import ACTIVITY_FIELDS, apply_study_streak, lock_study_user


@pytest.mark.parametrize(
    ("previous", "now", "current", "expected"),
    [
        (None, datetime(2026, 11, 1, 14, 59, 59, tzinfo=UTC), 0, 1),
        (datetime(2026, 11, 1, 14, tzinfo=UTC), datetime(2026, 11, 1, 15, tzinfo=UTC), 4, 5),
        (datetime(2026, 11, 1, 15, tzinfo=UTC), datetime(2026, 11, 2, 1, tzinfo=UTC), 4, 4),
        (datetime(2026, 10, 30, 15, tzinfo=UTC), datetime(2026, 11, 2, 1, tzinfo=UTC), 4, 1),
        (datetime(2026, 11, 2, 15, tzinfo=UTC), datetime(2026, 11, 2, 1, tzinfo=UTC), 4, 4),
        (datetime(2026, 11, 1, 14), datetime(2026, 11, 1, 15, tzinfo=UTC), 4, 5),
    ],
    ids=["first", "kst-midnight", "same-day", "gap", "future-date-not-regressed", "legacy-naive-utc"],
)
def test_single_server_instant_controls_study_day(previous, now, current, expected):
    user = SimpleNamespace(last_study_date=previous, streak_count=current, longest_streak=9, experience_points=77, daily_goal=20)
    day = apply_study_streak(user, processed_at=now)
    assert day == (date(2026, 11, 1) if now.hour < 15 and now.day == 1 else date(2026, 11, 2))
    assert user.streak_count == expected
    assert user.longest_streak == 9
    assert user.experience_points == 77 and user.daily_goal == 20
    if previous is not None and previous.tzinfo is not None and previous > now:
        assert user.last_study_date == previous
    else:
        assert user.last_study_date == now


def test_naive_processing_timestamp_is_rejected_before_any_mutation():
    user = SimpleNamespace(last_study_date=None, streak_count=0, longest_streak=0)
    with pytest.raises(ValueError, match="timezone-aware"):
        apply_study_streak(user, processed_at=datetime(2026, 11, 2))
    assert vars(user) == {"last_study_date": None, "streak_count": 0, "longest_streak": 0}


def test_same_day_older_processing_instant_does_not_regress_last_study_time():
    last = datetime(2026, 11, 2, 5, tzinfo=UTC)
    for previous in [last, last.replace(tzinfo=None)]:
        user = SimpleNamespace(last_study_date=previous, streak_count=4, longest_streak=9)
        apply_study_streak(user, processed_at=datetime(2026, 11, 2, 1, tzinfo=UTC))
        assert user.last_study_date == previous
        assert (user.streak_count, user.longest_streak) == (4, 9)


def test_lesson_marker_is_activity_without_inventing_legacy_aggregates():
    assert has_study_activity(SimpleNamespace(lesson_completed=True))
    assert not has_study_activity(SimpleNamespace(lesson_completed=False))
    assert not has_study_activity(SimpleNamespace())
    assert has_study_activity(SimpleNamespace(lesson_completed=False, quizzes_completed=1))
    assert not has_study_activity(None)


async def test_activity_lock_refreshes_only_reward_fields_with_no_autoflush():
    db = AsyncMock()
    context = MagicMock()
    db.no_autoflush = context
    user = SimpleNamespace()
    await lock_study_user(db, user)
    context.__enter__.assert_called_once()
    db.refresh.assert_awaited_once_with(user, attribute_names=ACTIVITY_FIELDS, with_for_update={"key_share": True})
    context.__exit__.assert_called_once()
    db.commit.assert_not_awaited()
    assert "show_kana" not in ACTIVITY_FIELDS and "app_settings" not in ACTIVITY_FIELDS
