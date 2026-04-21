from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock

import pytest

from app.enums import JlptLevel, ReviewStatus
from app.services.admin_vocabulary_list import list_admin_vocabulary


@pytest.mark.asyncio
async def test_list_admin_vocabulary_returns_paginated_items() -> None:
    items = [MagicMock(), MagicMock()]
    db = _FakeDb([_ScalarResult(41), _ScalarsResult(items)])

    result = await list_admin_vocabulary(
        db,  # type: ignore[arg-type]
        page=2,
        page_size=20,
        jlpt_level=JlptLevel.N5,
        review_status=ReviewStatus.NEEDS_REVIEW,
        search="食",
        sort_by="review_status",
        sort_order="asc",
    )

    assert result.items == items
    assert result.total == 41
    assert result.page == 2
    assert result.page_size == 20
    assert result.total_pages == 3
    assert db.execute_calls == 2


@pytest.mark.asyncio
async def test_list_admin_vocabulary_uses_one_total_page_for_empty_result() -> None:
    db = _FakeDb([_ScalarResult(0), _ScalarsResult([])])

    result = await list_admin_vocabulary(
        db,  # type: ignore[arg-type]
        page=1,
        page_size=20,
    )

    assert result.items == []
    assert result.total == 0
    assert result.total_pages == 1
    assert db.execute_calls == 2


class _FakeDb:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.execute_calls = 0

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)


class _ScalarResult:
    def __init__(self, value: int) -> None:
        self._value = value

    def scalar_one(self) -> int:
        return self._value


class _ScalarsResult:
    def __init__(self, items: list[Any]) -> None:
        self._items = items

    def scalars(self) -> _ScalarsResult:
        return self

    def all(self) -> list[Any]:
        return self._items
