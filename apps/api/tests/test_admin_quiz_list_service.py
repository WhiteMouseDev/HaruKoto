from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any

import pytest

from app.enums import JlptLevel, ReviewStatus
from app.services.admin_quiz_list import list_admin_quiz


@pytest.mark.asyncio
async def test_list_admin_quiz_returns_normalized_paginated_items() -> None:
    created_at = datetime(2026, 4, 21, 12, 0, tzinfo=UTC)
    rows = [
        SimpleNamespace(
            id=uuid.uuid4(),
            sentence="私は___を食べます。",
            quiz_type="cloze",
            jlpt_level=JlptLevel.N5,
            review_status=ReviewStatus.NEEDS_REVIEW,
            created_at=created_at,
        ),
        SimpleNamespace(
            id=uuid.uuid4(),
            sentence="나는 물을 마십니다.",
            quiz_type="sentence_arrange",
            jlpt_level="N4",
            review_status="approved",
            created_at=created_at,
        ),
    ]
    db = _FakeDb([_ScalarResult(21), _RowsResult(rows)])

    result = await list_admin_quiz(
        db,  # type: ignore[arg-type]
        page=2,
        page_size=10,
        jlpt_level=JlptLevel.N5,
        review_status=ReviewStatus.NEEDS_REVIEW,
        search="食",
        sort_by="review_status",
        sort_order="asc",
    )

    assert result.total == 21
    assert result.page == 2
    assert result.page_size == 10
    assert result.total_pages == 3
    assert [item.quiz_type for item in result.items] == ["cloze", "sentence_arrange"]
    assert result.items[0].jlpt_level == "N5"
    assert result.items[0].review_status == "needs_review"
    assert result.items[1].jlpt_level == "N4"
    assert result.items[1].review_status == "approved"
    assert db.execute_calls == 2


@pytest.mark.asyncio
async def test_list_admin_quiz_uses_one_total_page_for_empty_result() -> None:
    db = _FakeDb([_ScalarResult(0), _RowsResult([])])

    result = await list_admin_quiz(
        db,  # type: ignore[arg-type]
        page=1,
        page_size=20,
        quiz_type="cloze",
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


class _RowsResult:
    def __init__(self, rows: list[Any]) -> None:
        self._rows = rows

    def all(self) -> list[Any]:
        return self._rows
