from __future__ import annotations

import uuid
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.enums import ReviewStatus
from app.models.admin import AuditLog
from app.services.admin_batch_review import AdminBatchReviewServiceError, batch_review_content


def _scalar_result(obj: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


@pytest.mark.asyncio
async def test_batch_review_content_updates_items_and_writes_audit_logs() -> None:
    reviewer_id = uuid.uuid4()
    item_ids = [uuid.uuid4(), uuid.uuid4()]
    items = [MagicMock(review_status=ReviewStatus.NEEDS_REVIEW) for _ in item_ids]
    db = _FakeDb([_scalar_result(items[0]), _scalar_result(items[1])])

    result = await batch_review_content(
        db,  # type: ignore[arg-type]
        content_type="vocabulary",
        item_ids=item_ids,
        action="approve",
        reviewer_id=reviewer_id,
    )

    assert result.count == 2
    assert [item.review_status for item in items] == [ReviewStatus.APPROVED, ReviewStatus.APPROVED]
    assert db.execute_calls == 2
    assert db.commit_calls == 1
    assert len(db.added) == 2
    assert all(isinstance(audit, AuditLog) for audit in db.added)
    assert [audit.content_id for audit in db.added] == item_ids
    assert all(audit.content_type == "vocabulary" for audit in db.added)
    assert all(audit.action == "approve" for audit in db.added)
    assert all(audit.reviewer_id == reviewer_id for audit in db.added)


@pytest.mark.asyncio
async def test_batch_review_content_reject_requires_reason() -> None:
    db = _FakeDb([])

    with pytest.raises(AdminBatchReviewServiceError) as exc_info:
        await batch_review_content(
            db,  # type: ignore[arg-type]
            content_type="vocabulary",
            item_ids=[uuid.uuid4()],
            action="reject",
            reviewer_id=uuid.uuid4(),
        )

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "reason required for reject"
    assert db.execute_calls == 0
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_batch_review_content_rejects_unknown_content_type() -> None:
    db = _FakeDb([])

    with pytest.raises(AdminBatchReviewServiceError) as exc_info:
        await batch_review_content(
            db,  # type: ignore[arg-type]
            content_type="unknown",
            item_ids=[uuid.uuid4()],
            action="approve",
            reviewer_id=uuid.uuid4(),
        )

    assert exc_info.value.status_code == 400
    assert "Unknown content_type" in exc_info.value.detail
    assert db.execute_calls == 0
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_batch_review_content_rejects_missing_item() -> None:
    item_id = uuid.uuid4()
    db = _FakeDb([_scalar_result(None)])

    with pytest.raises(AdminBatchReviewServiceError) as exc_info:
        await batch_review_content(
            db,  # type: ignore[arg-type]
            content_type="vocabulary",
            item_ids=[item_id],
            action="approve",
            reviewer_id=uuid.uuid4(),
        )

    assert exc_info.value.status_code == 404
    assert str(item_id) in exc_info.value.detail
    assert db.execute_calls == 1
    assert db.added == []
    assert db.commit_calls == 0


class _FakeDb:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.execute_calls = 0
        self.commit_calls = 0
        self.added: list[Any] = []

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)

    def add(self, obj: Any) -> None:
        self.added.append(obj)

    async def commit(self) -> None:
        self.commit_calls += 1
