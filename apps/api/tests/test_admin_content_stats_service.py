from __future__ import annotations

from typing import Any

import pytest

from app.enums import ReviewStatus
from app.services.admin_content_stats import get_admin_content_stats


@pytest.mark.asyncio
async def test_get_admin_content_stats_returns_counts_for_all_content_types() -> None:
    db = _FakeDb(
        [
            _RowsResult([(ReviewStatus.NEEDS_REVIEW, 2), (ReviewStatus.APPROVED, 3)]),
            _RowsResult([(ReviewStatus.REJECTED, 1)]),
            _RowsResult([]),
            _RowsResult([(ReviewStatus.APPROVED, 4), (ReviewStatus.REJECTED, 1)]),
            _RowsResult([("needs_review", 5)]),
        ]
    )

    stats = await get_admin_content_stats(db)  # type: ignore[arg-type]

    assert [item.content_type for item in stats] == [
        "vocabulary",
        "grammar",
        "cloze",
        "sentence_arrange",
        "conversation",
    ]
    assert stats[0].needs_review == 2
    assert stats[0].approved == 3
    assert stats[0].rejected == 0
    assert stats[0].total == 5
    assert stats[1].needs_review == 0
    assert stats[1].approved == 0
    assert stats[1].rejected == 1
    assert stats[1].total == 1
    assert stats[2].total == 0
    assert stats[3].approved == 4
    assert stats[3].rejected == 1
    assert stats[3].total == 5
    assert stats[4].needs_review == 5
    assert stats[4].total == 5
    assert db.execute_calls == 5


class _FakeDb:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.execute_calls = 0

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)


class _RowsResult:
    def __init__(self, rows: list[tuple[Any, int]]) -> None:
        self._rows = rows

    def all(self) -> list[tuple[Any, int]]:
        return self._rows
