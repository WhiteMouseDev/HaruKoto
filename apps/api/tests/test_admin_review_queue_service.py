from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from app.enums import JlptLevel
from app.services.admin_review_queue import AdminReviewQueueServiceError, get_admin_review_queue


@pytest.mark.asyncio
async def test_get_admin_review_queue_returns_content_ids_with_cap() -> None:
    rows = [(str(uuid.uuid4()),) for _ in range(201)]
    db = _FakeDb([_RowsResult(rows)])

    result = await get_admin_review_queue(
        db,  # type: ignore[arg-type]
        "vocabulary",
        jlpt_level=JlptLevel.N5,
    )

    assert result.total == 200
    assert result.capped is True
    assert [item.id for item in result.items] == [row[0] for row in rows[:200]]
    assert all(item.quiz_type is None for item in result.items)
    assert db.execute_calls == 1


@pytest.mark.asyncio
async def test_get_admin_review_queue_merges_quiz_items_by_created_at() -> None:
    now = datetime(2026, 4, 20, 12, 0, tzinfo=UTC)
    cloze_newer = uuid.uuid4()
    cloze_older = uuid.uuid4()
    arrange_middle = uuid.uuid4()
    db = _FakeDb(
        [
            _RowsResult(
                [
                    (cloze_newer, now + timedelta(minutes=2)),
                    (cloze_older, now),
                ]
            ),
            _RowsResult([(arrange_middle, now + timedelta(minutes=1))]),
        ]
    )

    result = await get_admin_review_queue(
        db,  # type: ignore[arg-type]
        "quiz",
        jlpt_level=JlptLevel.N4,
    )

    assert [(item.id, item.quiz_type) for item in result.items] == [
        (str(cloze_older), "cloze"),
        (str(arrange_middle), "sentence_arrange"),
        (str(cloze_newer), "cloze"),
    ]
    assert result.total == 3
    assert result.capped is False
    assert db.execute_calls == 2


@pytest.mark.asyncio
async def test_get_admin_review_queue_applies_custom_limit() -> None:
    rows = [(uuid.uuid4(), datetime(2026, 4, 20, 12, idx, tzinfo=UTC)) for idx in range(3)]
    db = _FakeDb([_RowsResult(rows), _RowsResult([])])

    result = await get_admin_review_queue(
        db,  # type: ignore[arg-type]
        "quiz",
        limit=2,
    )

    assert [(item.id, item.quiz_type) for item in result.items] == [
        (str(rows[0][0]), "cloze"),
        (str(rows[1][0]), "cloze"),
    ]
    assert result.total == 2
    assert result.capped is True


@pytest.mark.asyncio
async def test_get_admin_review_queue_rejects_unknown_content_type() -> None:
    db = _FakeDb([])

    with pytest.raises(AdminReviewQueueServiceError) as exc_info:
        await get_admin_review_queue(
            db,  # type: ignore[arg-type]
            "unknown",
        )

    assert exc_info.value.status_code == 400
    assert "Unknown content type" in exc_info.value.detail


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
    def __init__(self, rows: list[tuple[Any, ...]]) -> None:
        self._rows = rows

    def all(self) -> list[tuple[Any, ...]]:
        return self._rows
