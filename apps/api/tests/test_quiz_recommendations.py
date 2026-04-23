from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.quiz_recommendations import get_recommendations_data


class _ScalarResult:
    def __init__(self, value: object) -> None:
        self._value = value

    def scalar(self) -> object:
        return self._value


def _user() -> SimpleNamespace:
    return SimpleNamespace(id=uuid.UUID("00000000-0000-0000-0000-000000000001"))


@pytest.mark.asyncio
async def test_get_recommendations_data_skips_sentence_category_queries() -> None:
    db = SimpleNamespace(execute=AsyncMock())

    result = await get_recommendations_data(db, _user(), category="SENTENCE")

    assert result.review_due_count == 0
    assert result.new_words_count == 0
    assert result.wrong_count == 0
    assert result.last_reviewed_at is None
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_get_recommendations_data_aggregates_default_category() -> None:
    last_reviewed = datetime(2026, 4, 23, 10, 30, tzinfo=UTC)
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _ScalarResult(3),
                _ScalarResult(2),
                _ScalarResult(8),
                _ScalarResult(20),
                _ScalarResult(4),
                _ScalarResult(last_reviewed),
            ]
        )
    )

    result = await get_recommendations_data(db, _user(), category=None)

    assert result.review_due_count == 5
    assert result.new_words_count == 12
    assert result.wrong_count == 4
    assert result.last_reviewed_at == last_reviewed.isoformat()


@pytest.mark.asyncio
async def test_get_recommendations_data_clamps_negative_new_count() -> None:
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _ScalarResult(1),
                _ScalarResult(12),
                _ScalarResult(10),
                _ScalarResult(0),
                _ScalarResult(None),
            ]
        )
    )

    result = await get_recommendations_data(db, _user(), category="VOCABULARY")

    assert result.review_due_count == 1
    assert result.new_words_count == 0
    assert result.wrong_count == 0
    assert result.last_reviewed_at is None
