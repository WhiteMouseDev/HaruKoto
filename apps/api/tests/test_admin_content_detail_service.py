from __future__ import annotations

import uuid
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.services.admin_content_detail import AdminContentDetailServiceError, get_admin_content_item


def _scalar_result(obj: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


@pytest.mark.asyncio
async def test_get_admin_content_item_returns_found_item() -> None:
    item = MagicMock()
    db = _FakeDb([_scalar_result(item)])

    result = await get_admin_content_item(
        db,  # type: ignore[arg-type]
        content_type="vocabulary",
        item_id=uuid.uuid4(),
    )

    assert result is item
    assert db.execute_calls == 1


@pytest.mark.asyncio
async def test_get_admin_content_item_rejects_unknown_content_type() -> None:
    db = _FakeDb([])

    with pytest.raises(AdminContentDetailServiceError) as exc_info:
        await get_admin_content_item(
            db,  # type: ignore[arg-type]
            content_type="unknown",
            item_id=uuid.uuid4(),
        )

    assert exc_info.value.status_code == 400
    assert "Unknown content_type" in exc_info.value.detail
    assert db.execute_calls == 0


@pytest.mark.asyncio
async def test_get_admin_content_item_rejects_missing_item() -> None:
    db = _FakeDb([_scalar_result(None)])

    with pytest.raises(AdminContentDetailServiceError) as exc_info:
        await get_admin_content_item(
            db,  # type: ignore[arg-type]
            content_type="conversation",
            item_id=uuid.uuid4(),
        )

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "Not found"
    assert db.execute_calls == 1


class _FakeDb:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.execute_calls = 0

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)
