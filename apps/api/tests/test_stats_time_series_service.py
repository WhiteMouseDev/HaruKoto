from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services import stats_time_series
from app.services.stats_time_series import (
    get_by_category_data,
    get_heatmap_data,
    get_time_chart_data,
    get_volume_chart_data,
)

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
async def test_get_heatmap_data_fills_missing_days_and_applies_levels() -> None:
    db = _db_with_progress(
        [
            SimpleNamespace(date=date(2026, 4, 1), words_studied=0, study_minutes=0),
            SimpleNamespace(date=date(2026, 4, 2), words_studied=9, study_minutes=3),
            SimpleNamespace(date=date(2026, 4, 3), words_studied=10, study_minutes=5),
            SimpleNamespace(date=date(2026, 4, 4), words_studied=20, study_minutes=None),
        ]
    )

    response = await get_heatmap_data(db, user_id=USER_ID, year=2026, month=4)

    assert len(response.data) == 30
    assert [item.level for item in response.data[:4]] == [0, 1, 2, 3]
    assert response.data[0].date == "2026-04-01"
    assert response.data[3].study_minutes == 0
    assert response.data[4].date == "2026-04-05"
    assert response.data[4].words_studied == 0
    assert response.data[4].level == 0


@pytest.mark.asyncio
async def test_get_time_chart_data_uses_recent_range_and_zero_fills(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(stats_time_series, "get_today_kst", lambda: date(2026, 4, 23))
    db = _db_with_progress(
        [
            SimpleNamespace(date=date(2026, 4, 22), study_minutes=12),
        ]
    )

    response = await get_time_chart_data(db, user_id=USER_ID, days=3)

    assert [item.date for item in response.data] == ["2026-04-21", "2026-04-22", "2026-04-23"]
    assert [item.minutes for item in response.data] == [0, 12, 0]


@pytest.mark.asyncio
async def test_get_volume_chart_data_uses_recent_range_and_zero_fills(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(stats_time_series, "get_today_kst", lambda: date(2026, 4, 23))
    db = _db_with_progress(
        [
            SimpleNamespace(
                date=date(2026, 4, 22),
                words_studied=4,
                grammar_studied=None,
                sentences_studied=2,
            ),
        ]
    )

    response = await get_volume_chart_data(db, user_id=USER_ID, days=3)

    assert [item.date for item in response.data] == ["2026-04-21", "2026-04-22", "2026-04-23"]
    assert [item.words_studied for item in response.data] == [0, 4, 0]
    assert [item.grammar_studied for item in response.data] == [0, 0, 0]
    assert [item.sentences_studied for item in response.data] == [0, 2, 0]


@pytest.mark.asyncio
async def test_get_by_category_data_returns_seven_day_totals(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(stats_time_series, "get_today_kst", lambda: date(2026, 4, 23))
    db = _db_with_progress(
        [
            SimpleNamespace(
                date=date(2026, 4, 22),
                words_studied=4,
                grammar_studied=None,
                sentences_studied=2,
            ),
        ]
    )

    response = await get_by_category_data(db, user_id=USER_ID)

    assert response.vocabulary.daily == [0, 0, 0, 0, 0, 4, 0]
    assert response.vocabulary.total == 4
    assert response.grammar.daily == [0, 0, 0, 0, 0, 0, 0]
    assert response.grammar.total == 0
    assert response.sentences.daily == [0, 0, 0, 0, 0, 2, 0]
    assert response.sentences.total == 2
