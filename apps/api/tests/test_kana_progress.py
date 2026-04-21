from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.schemas.kana import KanaProgressRecord
from app.services import kana_progress
from app.services.kana_progress import (
    build_daily_kana_increment_statement,
    build_kana_progress_upsert_statement,
    record_kana_learning_progress,
)


@pytest.mark.asyncio
async def test_record_kana_learning_progress_updates_progress_and_daily_count(monkeypatch):
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    user = SimpleNamespace(id=uuid.uuid4())
    kana_id = uuid.uuid4()

    monkeypatch.setattr(kana_progress, "get_today_kst", lambda: date(2026, 4, 21))

    result = await record_kana_learning_progress(
        db,
        user,
        KanaProgressRecord(kana_id=kana_id),
    )

    assert result.ok is True
    assert db.execute.await_count == 2
    db.commit.assert_awaited_once()


def test_build_kana_progress_upsert_statement_returns_executable_statement():
    stmt = build_kana_progress_upsert_statement(
        user_id=uuid.uuid4(),
        kana_id=uuid.uuid4(),
        reviewed_at=kana_progress.datetime.now(kana_progress.UTC),
    )

    assert "user_kana_progress" in str(stmt)


def test_build_daily_kana_increment_statement_returns_executable_statement():
    stmt = build_daily_kana_increment_statement(
        user_id=uuid.uuid4(),
        today=date(2026, 4, 21),
    )

    assert "daily_progress" in str(stmt)
