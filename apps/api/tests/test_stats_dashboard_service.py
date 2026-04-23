from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.models.enums import KanaType
from app.services import stats_dashboard
from app.services.stats_dashboard import get_dashboard_data


class _ScalarRows:
    def __init__(self, rows: list[object]) -> None:
        self._rows = rows

    def all(self) -> list[object]:
        return self._rows


class _DbResult:
    def __init__(
        self,
        *,
        scalar_value: int | None = None,
        scalar_one_or_none_value: object | None = None,
        all_rows: list[object] | None = None,
        scalar_rows: list[object] | None = None,
    ) -> None:
        self._scalar_value = scalar_value
        self._scalar_one_or_none_value = scalar_one_or_none_value
        self._all_rows = all_rows or []
        self._scalar_rows = scalar_rows or []

    def scalar(self) -> int | None:
        return self._scalar_value

    def scalar_one_or_none(self) -> object | None:
        return self._scalar_one_or_none_value

    def all(self) -> list[object]:
        return self._all_rows

    def scalars(self) -> _ScalarRows:
        return _ScalarRows(self._scalar_rows)


@pytest.mark.asyncio
async def test_get_dashboard_data_builds_dashboard_response(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(stats_dashboard, "get_today_kst", lambda: date(2026, 4, 23))

    user = SimpleNamespace(
        id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
        jlpt_level="N5",
        daily_goal=10,
        streak_count=4,
        longest_streak=9,
        show_kana=True,
    )
    today_progress = SimpleNamespace(
        words_studied=8,
        quizzes_completed=2,
        correct_answers=17,
        total_answers=20,
        xp_earned=120,
    )
    weekly_progress = SimpleNamespace(
        date=date(2026, 4, 20),
        words_studied=3,
        xp_earned=30,
    )

    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _DbResult(scalar_one_or_none_value=today_progress),
                _DbResult(scalar_rows=[weekly_progress]),
                _DbResult(scalar_value=100),
                _DbResult(all_rows=[(True, 12), (False, 3)]),
                _DbResult(scalar_value=50),
                _DbResult(all_rows=[(False, 4)]),
                _DbResult(all_rows=[(KanaType.HIRAGANA, 46), (KanaType.KATAKANA, 46)]),
                _DbResult(all_rows=[(KanaType.HIRAGANA, 12)]),
                _DbResult(all_rows=[(KanaType.HIRAGANA, 20), (KanaType.KATAKANA, 5)]),
            ]
        )
    )

    response = await get_dashboard_data(db, user)

    assert response.show_kana is True
    assert response.today.words_studied == 8
    assert response.today.goal_progress == 1.0
    assert response.streak.current == 4
    assert response.streak.longest == 9
    assert len(response.weekly_stats) == 7
    assert response.weekly_stats[3].date == "2026-04-20"
    assert response.weekly_stats[3].words_studied == 3
    assert response.level_progress.vocabulary.total == 100
    assert response.level_progress.vocabulary.mastered == 12
    assert response.level_progress.vocabulary.in_progress == 3
    assert response.level_progress.grammar.total == 50
    assert response.level_progress.grammar.mastered == 0
    assert response.level_progress.grammar.in_progress == 4
    assert response.kana_progress.hiragana.learned == 20
    assert response.kana_progress.hiragana.mastered == 12
    assert response.kana_progress.katakana.learned == 5
    assert response.kana_progress.katakana.mastered == 0
