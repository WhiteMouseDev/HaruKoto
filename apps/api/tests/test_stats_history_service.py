from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services import stats_history
from app.services.stats_history import get_history_data

USER_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


class _ScalarRows:
    def __init__(self, rows: list[object]) -> None:
        self._rows = rows

    def all(self) -> list[object]:
        return self._rows


class _DbResult:
    def __init__(self, *, scalar_rows: list[object]) -> None:
        self._scalar_rows = scalar_rows

    def scalars(self) -> _ScalarRows:
        return _ScalarRows(self._scalar_rows)


def _db_with_progress(rows: list[object]) -> SimpleNamespace:
    return SimpleNamespace(execute=AsyncMock(return_value=_DbResult(scalar_rows=rows)))


@pytest.mark.asyncio
async def test_get_history_data_defaults_to_current_year_and_month(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(stats_history, "get_today_kst", lambda: date(2026, 4, 23))
    db = _db_with_progress(
        [
            SimpleNamespace(
                date=date(2026, 4, 3),
                words_studied=7,
                quizzes_completed=2,
                correct_answers=9,
                total_answers=10,
                conversation_count=1,
                study_time_seconds=600,
                xp_earned=120,
            )
        ]
    )

    response = await get_history_data(db, user_id=USER_ID, year=None, month=None)

    assert response.year == 2026
    assert response.month == 4
    assert len(response.records) == 1
    assert response.records[0].date == "2026-04-03"
    assert response.records[0].words_studied == 7
    assert response.records[0].quizzes_completed == 2
    assert response.records[0].correct_answers == 9
    assert response.records[0].total_answers == 10
    assert response.records[0].conversation_count == 1
    assert response.records[0].study_time_seconds == 600
    assert response.records[0].xp_earned == 120


@pytest.mark.asyncio
async def test_get_history_data_defaults_missing_month_independently(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(stats_history, "get_today_kst", lambda: date(2026, 4, 23))
    db = _db_with_progress([])

    response = await get_history_data(db, user_id=USER_ID, year=2025, month=None)

    assert response.year == 2025
    assert response.month == 4
    assert response.records == []


@pytest.mark.parametrize(
    "activity_field",
    [
        "words_studied",
        "quizzes_completed",
        "conversation_count",
        "xp_earned",
        "kana_learned",
        "grammar_studied",
        "sentences_studied",
        "study_time_seconds",
        "study_minutes",
    ],
)
def test_history_activity_includes_each_existing_aggregate_without_mutating_row(activity_field: str) -> None:
    progress = SimpleNamespace(
        date=date(2026, 10, 3),
        words_studied=0,
        quizzes_completed=0,
        correct_answers=0,
        total_answers=0,
        conversation_count=0,
        study_time_seconds=0,
        xp_earned=0,
        kana_learned=0,
        grammar_studied=None,
        sentences_studied=None,
        study_minutes=None,
    )
    setattr(progress, activity_field, 1)
    original = vars(progress).copy()

    record = stats_history._build_daily_progress_item(progress)

    assert record.has_studied is True
    assert vars(progress) == original


def test_history_all_zero_activity_does_not_count_answer_totals_or_row_existence() -> None:
    progress = SimpleNamespace(
        date=date(2026, 10, 3),
        words_studied=0,
        quizzes_completed=0,
        correct_answers=4,
        total_answers=5,
        conversation_count=0,
        study_time_seconds=0,
        xp_earned=0,
        grammar_studied=None,
        sentences_studied=None,
        study_minutes=None,
    )

    record = stats_history._build_daily_progress_item(progress)

    assert record.has_studied is False
    assert record.correct_answers == 4
    assert record.total_answers == 5
