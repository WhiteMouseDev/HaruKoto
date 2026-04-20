from __future__ import annotations

import uuid
from typing import Any

import pytest

from app.services.srs_session_builder import build_smart_session
from app.services.srs_transition import LEARNING, REVIEW


@pytest.mark.asyncio
async def test_build_smart_session_prioritizes_due_then_new_then_preview() -> None:
    due_id = uuid.uuid4()
    unseen_id = uuid.uuid4()
    fresh_id = uuid.uuid4()
    preview_id = uuid.uuid4()
    db = _FakeDb(
        [
            _RowsResult([(due_id, LEARNING)]),
            _ScalarResult(0),
            _RowsResult([(unseen_id,)]),
            _RowsResult([(fresh_id,)]),
            _RowsResult([(preview_id,)]),
        ]
    )

    cards = await build_smart_session(
        db,  # type: ignore[arg-type]
        user_id=uuid.uuid4(),
        item_type="WORD",
        jlpt_level="N5",
        count=10,
        daily_new_cap=10,
    )

    assert cards == [
        {
            "item_id": str(due_id),
            "item_type": "WORD",
            "direction": "JP_KR",
            "is_new": False,
        },
        {
            "item_id": str(unseen_id),
            "item_type": "WORD",
            "direction": "KR_JP",
            "is_new": True,
        },
        {
            "item_id": str(fresh_id),
            "item_type": "WORD",
            "direction": "JP_KR",
            "is_new": True,
        },
        {
            "item_id": str(preview_id),
            "item_type": "WORD",
            "direction": "KR_JP",
            "is_new": False,
        },
    ]
    assert db.execute_calls == 5


@pytest.mark.asyncio
async def test_build_smart_session_deduplicates_rows_and_stops_at_count() -> None:
    first_id = uuid.uuid4()
    second_id = uuid.uuid4()
    db = _FakeDb(
        [
            _RowsResult([(first_id, REVIEW), (first_id, REVIEW), (second_id, REVIEW)]),
        ]
    )

    cards = await build_smart_session(
        db,  # type: ignore[arg-type]
        user_id=uuid.uuid4(),
        item_type="GRAMMAR",
        jlpt_level="N4",
        count=2,
    )

    assert cards == [
        {
            "item_id": str(first_id),
            "item_type": "GRAMMAR",
            "direction": "JP_KR",
            "is_new": False,
        },
        {
            "item_id": str(second_id),
            "item_type": "GRAMMAR",
            "direction": "KR_JP",
            "is_new": False,
        },
    ]
    assert db.execute_calls == 1


@pytest.mark.asyncio
async def test_build_smart_session_respects_daily_new_cap() -> None:
    due_id = uuid.uuid4()
    db = _FakeDb(
        [
            _RowsResult([(due_id, LEARNING)]),
            _ScalarResult(10),
            _RowsResult([]),
        ]
    )

    cards = await build_smart_session(
        db,  # type: ignore[arg-type]
        user_id=uuid.uuid4(),
        item_type="WORD",
        jlpt_level="N5",
        count=5,
        daily_new_cap=10,
    )

    assert cards == [
        {
            "item_id": str(due_id),
            "item_type": "WORD",
            "direction": "JP_KR",
            "is_new": False,
        }
    ]
    assert db.execute_calls == 3


@pytest.mark.asyncio
async def test_build_smart_session_rejects_unknown_item_type() -> None:
    db = _FakeDb([])

    with pytest.raises(ValueError, match="Unknown item_type"):
        await build_smart_session(
            db,  # type: ignore[arg-type]
            user_id=uuid.uuid4(),
            item_type="KANJI",
            jlpt_level="N5",
        )


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


class _ScalarResult:
    def __init__(self, value: int) -> None:
        self._value = value

    def scalar(self) -> int:
        return self._value
