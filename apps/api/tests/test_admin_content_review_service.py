from __future__ import annotations

import uuid
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.enums import ReviewStatus
from app.models.admin import AuditLog
from app.services.admin_content_review import AdminContentReviewServiceError, review_admin_content_item


def _scalar_result(obj: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


@pytest.mark.asyncio
async def test_review_admin_content_item_approves_and_writes_audit_log() -> None:
    item_id = uuid.uuid4()
    reviewer_id = uuid.uuid4()
    item = MagicMock(review_status=ReviewStatus.NEEDS_REVIEW)
    db = _FakeDb([_scalar_result(item)])

    result = await review_admin_content_item(
        db,  # type: ignore[arg-type]
        content_type="vocabulary",
        item_id=item_id,
        action="approve",
        reviewer_id=reviewer_id,
    )

    assert result is item
    assert item.review_status == ReviewStatus.APPROVED
    assert db.execute_calls == 1
    assert db.commit_calls == 1
    assert db.refreshed == [item]
    assert len(db.added) == 1
    audit = db.added[0]
    assert isinstance(audit, AuditLog)
    assert audit.content_type == "vocabulary"
    assert audit.content_id == item_id
    assert audit.action == "approve"
    assert audit.reason is None
    assert audit.reviewer_id == reviewer_id


@pytest.mark.asyncio
async def test_review_admin_content_item_rejects_with_reason() -> None:
    item_id = uuid.uuid4()
    item = MagicMock(review_status=ReviewStatus.NEEDS_REVIEW)
    db = _FakeDb([_scalar_result(item)])

    await review_admin_content_item(
        db,  # type: ignore[arg-type]
        content_type="grammar",
        item_id=item_id,
        action="reject",
        reviewer_id=uuid.uuid4(),
        reason="incorrect explanation",
    )

    assert item.review_status == ReviewStatus.REJECTED
    assert db.added[0].content_type == "grammar"
    assert db.added[0].reason == "incorrect explanation"
    assert db.commit_calls == 1
    assert db.refreshed == [item]


@pytest.mark.asyncio
async def test_review_admin_content_item_reject_requires_reason() -> None:
    db = _FakeDb([])

    with pytest.raises(AdminContentReviewServiceError) as exc_info:
        await review_admin_content_item(
            db,  # type: ignore[arg-type]
            content_type="vocabulary",
            item_id=uuid.uuid4(),
            action="reject",
            reviewer_id=uuid.uuid4(),
        )

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "reason required for reject"
    assert db.execute_calls == 0
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_review_admin_content_item_rejects_unknown_content_type() -> None:
    db = _FakeDb([])

    with pytest.raises(AdminContentReviewServiceError) as exc_info:
        await review_admin_content_item(
            db,  # type: ignore[arg-type]
            content_type="unknown",
            item_id=uuid.uuid4(),
            action="approve",
            reviewer_id=uuid.uuid4(),
        )

    assert exc_info.value.status_code == 400
    assert "Unknown content_type" in exc_info.value.detail
    assert db.execute_calls == 0
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_review_admin_content_item_rejects_missing_item() -> None:
    db = _FakeDb([_scalar_result(None)])

    with pytest.raises(AdminContentReviewServiceError) as exc_info:
        await review_admin_content_item(
            db,  # type: ignore[arg-type]
            content_type="vocabulary",
            item_id=uuid.uuid4(),
            action="approve",
            reviewer_id=uuid.uuid4(),
        )

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "Not found"
    assert db.execute_calls == 1
    assert db.added == []
    assert db.commit_calls == 0
    assert db.refreshed == []


class _FakeDb:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.execute_calls = 0
        self.commit_calls = 0
        self.added: list[Any] = []
        self.refreshed: list[Any] = []

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)

    def add(self, obj: Any) -> None:
        self.added.append(obj)

    async def commit(self) -> None:
        self.commit_calls += 1

    async def refresh(self, obj: Any) -> None:
        self.refreshed.append(obj)
