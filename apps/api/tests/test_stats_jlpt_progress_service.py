from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.models.enums import JlptLevel
from app.routers import stats
from app.schemas.stats import JlptProgressResponse
from app.services.stats_jlpt_progress import get_jlpt_progress_data

USER_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


class _DbResult:
    def __init__(self, *, all_rows: list[tuple[object, ...]]) -> None:
        self._all_rows = all_rows

    def all(self) -> list[tuple[object, ...]]:
        return self._all_rows


@pytest.mark.asyncio
@pytest.mark.parametrize("include_all_levels", [False, True])
async def test_get_jlpt_progress_data_includes_studied_and_current_levels(include_all_levels: bool) -> None:
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
                        (JlptLevel.N2, 10),
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
        include_all_levels=include_all_levels,
    )

    assert [level.level for level in response.levels] == (["N5", "N4", "N3", "N2"] if include_all_levels else ["N5", "N4"])
    assert response.levels[0].vocabulary.total == 100
    assert response.levels[0].vocabulary.mastered == 12
    assert response.levels[0].vocabulary.in_progress == 3
    assert response.levels[0].grammar.total == 40
    assert response.levels[0].grammar.mastered == 0
    assert response.levels[0].grammar.in_progress == 4
    assert response.levels[1].vocabulary.total == 80
    assert response.levels[1].vocabulary.mastered == 0
    assert response.levels[1].grammar.total == 35
    if include_all_levels:
        progress = [level.model_dump(mode="json", by_alias=True) for level in response.levels[2:]]
        assert progress == [
            {
                "level": "N3",
                "vocabulary": {"total": 70, "mastered": 0, "inProgress": 0},
                "grammar": {"total": 20, "mastered": 0, "inProgress": 0},
            },
            {
                "level": "N2",
                "vocabulary": {"total": 0, "mastered": 0, "inProgress": 0},
                "grammar": {"total": 10, "mastered": 0, "inProgress": 0},
            },
        ]
    assert db.execute.await_count == 4


@pytest.mark.asyncio
@pytest.mark.parametrize("include_all_levels", [False, True])
async def test_get_jlpt_progress_data_excludes_levels_without_content_totals(include_all_levels: bool) -> None:
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
        include_all_levels=include_all_levels,
    )

    assert response.levels == []


@pytest.mark.asyncio
@pytest.mark.parametrize(("query", "expected"), [("", False), ("?include_all_levels=false", False), ("?include_all_levels=true", True)])
async def test_get_jlpt_progress_maps_optional_query_to_service(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch, query: str, expected: bool
) -> None:
    service = AsyncMock(return_value=JlptProgressResponse(levels=[]))
    monkeypatch.setattr(stats, "get_jlpt_progress_data", service)

    response = await client.get(f"/api/v1/stats/jlpt-progress{query}")

    assert response.status_code == 200
    assert response.json() == {"levels": []}
    service.assert_awaited_once()
    assert service.await_args.kwargs["include_all_levels"] is expected
