from datetime import UTC, datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.services import study_day_credit
from app.services.stats_dashboard import _build_streak_info
from app.services.study_activity import has_study_activity

NOW = datetime(2026, 11, 3, 1, tzinfo=UTC)
OLD = NOW - timedelta(days=3)


@pytest.mark.parametrize(
    "credit,legacy_xp,expected",
    [(None, 0, False), (None, 20, True), (False, 20, False), (True, 0, True)],
    ids=["empty-legacy", "positive-legacy", "explicit-false-overrides-xp", "explicit-true"],
)
def test_credit_reader_preserves_legacy_and_honors_explicit_decision(credit, legacy_xp, expected):
    progress = SimpleNamespace(study_day_credited=credit, xp_earned=legacy_xp)
    assert has_study_activity(progress) is expected


@pytest.mark.parametrize("gate", [False, True], ids=["compatible-off", "enabled"])
@pytest.mark.parametrize(
    "progress,expected_when_on",
    [
        (None, False),
        (SimpleNamespace(study_day_credited=None, xp_earned=0), False),
        (SimpleNamespace(study_day_credited=None, xp_earned=20), True),
        (SimpleNamespace(study_day_credited=False, xp_earned=20), False),
        (SimpleNamespace(study_day_credited=True, xp_earned=0), True),
    ],
    ids=["no-row", "empty-legacy", "positive-legacy", "existing-false", "existing-true"],
)
def test_delayed_completion_credit_decision_is_compatible_with_gate(monkeypatch, gate, progress, expected_when_on):
    monkeypatch.setattr(study_day_credit, "STUDY_DAY_CREDIT_SEPARATION_ENABLED", gate)
    result = study_day_credit.resolve_quiz_completion_study_day(progress, first_answer_times=[OLD], completed_at=NOW)
    existing_false = getattr(progress, "study_day_credited", None) is False
    assert result.credited is (expected_when_on if gate else not existing_false)
    assert result.update_streak is (not gate and not existing_false)


@pytest.mark.parametrize("gate", [False, True], ids=["compatible-off", "enabled"])
@pytest.mark.parametrize(
    "answer_time,expected",
    [
        (datetime(2026, 11, 2, 14, 59, 59, 999999, tzinfo=UTC), False),
        (datetime(2026, 11, 2, 15, tzinfo=UTC), True),
        (datetime(2026, 11, 2, 15), True),
        (datetime(2026, 11, 3, 0, tzinfo=timezone(timedelta(hours=9))), True),
        (NOW, True),
        (NOW + timedelta(microseconds=1), False),
    ],
    ids=["before-kst-midnight", "exact-kst-midnight", "legacy-naive-utc", "aware-kst", "at-completion", "future-answer"],
)
def test_fresh_canonical_answer_promotes_false_on_kst_day_even_when_off(monkeypatch, gate, answer_time, expected):
    monkeypatch.setattr(study_day_credit, "STUDY_DAY_CREDIT_SEPARATION_ENABLED", gate)
    result = study_day_credit.resolve_quiz_completion_study_day(
        SimpleNamespace(study_day_credited=False, xp_earned=30), first_answer_times=[OLD, answer_time], completed_at=NOW
    )
    assert result.credited is expected and result.update_streak is expected


def test_dashboard_does_not_override_explicit_false_with_last_study_date():
    result = _build_streak_info(
        user=SimpleNamespace(last_study_date=NOW, streak_count=2, longest_streak=3),
        today_progress=SimpleNamespace(study_day_credited=False, activity_recorded=True, xp_earned=30),
        today=NOW.date(),
    )
    assert result.studied_today is False and result.needs_action_today is True
