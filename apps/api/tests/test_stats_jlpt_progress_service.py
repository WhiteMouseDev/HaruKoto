from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.models.enums import JlptLevel
from app.services.stats_jlpt_progress import get_jlpt_progress_data

USER_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


class _DbResult:
    def __init__(self, *, all_rows: list[tuple[object, ...]]) -> None:
        self._all_rows = all_rows

    def all(self) -> list[tuple[object, ...]]:
        return self._all_rows


@pytest.mark.asyncio
async def test_get_jlpt_progress_data_includes_studied_and_current_levels() -> None:
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _DbResult(
                    all_rows=[
                        (JlptLevel.N5, 100),
                        (JlptLevel.N4, 80),
                        (JlptLevel.N3, 70),
                    ]
                ),
                _DbResult(
                    all_rows=[
                        (JlptLevel.N5, 40),
                        (JlptLevel.N4, 35),
                        (JlptLevel.N3, 20),
                    ]
                ),
                _DbResult(
                    all_rows=[
                        (JlptLevel.N5, True, 12),
                        (JlptLevel.N5, False, 3),
                    ]
                ),
                _DbResult(
                    all_rows=[
                        (JlptLevel.N5, False, 4),
                    ]
                ),
            ]
        )
    )

    response = await get_jlpt_progress_data(
        db,
        user_id=USER_ID,
        current_jlpt_level=JlptLevel.N4,
    )

    assert [level.level for level in response.levels] == ["N5", "N4"]
    assert response.levels[0].vocabulary.total == 100
    assert response.levels[0].vocabulary.mastered == 12
    assert response.levels[0].vocabulary.in_progress == 3
    assert response.levels[0].grammar.total == 40
    assert response.levels[0].grammar.mastered == 0
    assert response.levels[0].grammar.in_progress == 4
    assert response.levels[1].vocabulary.total == 80
    assert response.levels[1].vocabulary.mastered == 0
    assert response.levels[1].grammar.total == 35


@pytest.mark.asyncio
async def test_get_jlpt_progress_data_excludes_levels_without_content_totals() -> None:
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _DbResult(all_rows=[]),
                _DbResult(all_rows=[]),
                _DbResult(all_rows=[(JlptLevel.N5, True, 1)]),
                _DbResult(all_rows=[(JlptLevel.N5, False, 1)]),
            ]
        )
    )

    response = await get_jlpt_progress_data(
        db,
        user_id=USER_ID,
        current_jlpt_level=JlptLevel.N5,
    )

    assert response.levels == []
