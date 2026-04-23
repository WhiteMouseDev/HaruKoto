from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from app.models.admin import AuditLog
from app.services.admin_audit_logs import AuditLogWithEmail, list_admin_audit_logs


@pytest.mark.asyncio
async def test_list_admin_audit_logs_returns_logs_with_reviewer_email() -> None:
    item_id = uuid.uuid4()
    reviewer_id = uuid.uuid4()
    reviewer_email = "reviewer@example.com"
    now = datetime(2026, 4, 21, 12, 0, tzinfo=UTC)
    logs = [
        AuditLog(
            id=uuid.uuid4(),
            content_type="vocabulary",
            content_id=item_id,
            action="edit",
            changes={"word": {"before": "食べる", "after": "飲む"}},
            reason=None,
            reviewer_id=reviewer_id,
            created_at=now,
        ),
        AuditLog(
            id=uuid.uuid4(),
            content_type="vocabulary",
            content_id=item_id,
            action="approve",
            changes=None,
            reason=None,
            reviewer_id=reviewer_id,
            created_at=now - timedelta(minutes=1),
        ),
    ]
    rows = [(log, reviewer_email) for log in logs]
    db = _FakeDb(_AllResult(rows))

    result = await list_admin_audit_logs(
        db,  # type: ignore[arg-type]
        content_type="vocabulary",
        item_id=item_id,
    )

    assert result == [AuditLogWithEmail(log=log, reviewer_email=reviewer_email) for log in logs]
    assert db.execute_calls == 1


class _FakeDb:
    def __init__(self, result: Any) -> None:
        self._result = result
        self.execute_calls = 0

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        return self._result


class _AllResult:
    def __init__(self, rows: list[tuple[AuditLog, str]]) -> None:
        self._rows = rows

    def all(self) -> list[tuple[AuditLog, str]]:
        return self._rows
