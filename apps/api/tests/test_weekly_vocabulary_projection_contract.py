"""Additive weekly word-count contract; legacy counters stay unchanged."""

from datetime import date
from unittest.mock import AsyncMock

import pytest
from pydantic import ValidationError

from app.schemas.stats import WeeklyStatItem
from app.services.vocabulary_goal import get_vocabulary_answered_counts

LEGACY = {"date": "2026-11-02", "wordsStudied": 4, "xpEarned": 90, "hasStudied": True}


@pytest.mark.parametrize("count", [None, 0, 1, 20])
def test_weekly_count_is_optional_nonnegative_and_preserves_old_fields(count):
    item = WeeklyStatItem.model_validate({**LEGACY, "vocabularyAnsweredCount": count})
    assert item.model_dump(mode="json", by_alias=True) == {**LEGACY, "vocabularyAnsweredCount": count}
    assert WeeklyStatItem.model_validate(LEGACY).vocabulary_answered_count is None


def test_weekly_count_rejects_negative():
    with pytest.raises(ValidationError):
        WeeklyStatItem.model_validate({**LEGACY, "vocabularyAnsweredCount": -1})


def test_weekly_count_openapi_is_optional_nullable_and_nonnegative():
    from app.main import app

    schema = app.openapi()["components"]["schemas"]["WeeklyStatItem"]
    assert set(schema["required"]) == set(LEGACY)
    assert set(schema["properties"]) == {*LEGACY, "vocabularyAnsweredCount"}
    assert schema["properties"]["vocabularyAnsweredCount"]["anyOf"] == [{"type": "integer", "minimum": 0}, {"type": "null"}]


@pytest.mark.parametrize("start,end", [(date(2026, 11, 2), date(2026, 11, 1)), (date(2026, 11, 1), date(2026, 11, 8))])
async def test_range_helper_rejects_unbounded_or_reversed_windows_before_query(start, end):
    db = AsyncMock()
    with pytest.raises(ValueError):
        await get_vocabulary_answered_counts(db, user_id=__import__("uuid").uuid4(), start_day=start, end_day=end)
    db.execute.assert_not_awaited()
