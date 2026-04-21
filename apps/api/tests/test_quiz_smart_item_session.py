from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.quiz_smart_item_session import SmartItemLoaders, load_selected_smart_items


def _item(meaning_ko: str) -> SimpleNamespace:
    return SimpleNamespace(id=uuid.uuid4(), meaning_ko=meaning_ko)


@pytest.mark.asyncio
async def test_load_selected_smart_items_combines_distribution_shortfall_and_dedupes_meanings():
    user_id = uuid.uuid4()
    studied_id = uuid.uuid4()
    review_item = _item("먹다")
    retry_item = _item("보다")
    new_item = _item("가다")
    duplicate_new_item = _item("보다")
    calls: dict[str, object] = {}

    async def load_review_items(_db, **kwargs):
        calls["review_count"] = kwargs["count"]
        return [review_item]

    async def load_retry_items(_db, **kwargs):
        calls["retry_count"] = kwargs["count"]
        return [retry_item]

    async def load_studied_ids(_db, **kwargs):
        calls["studied_user_id"] = kwargs["user_id"]
        return {studied_id}

    async def load_new_items(_db, **kwargs):
        calls["new_count"] = kwargs["count"]
        calls["exclude_ids"] = kwargs["exclude_ids"]
        return [new_item, duplicate_new_item]

    items = await load_selected_smart_items(
        AsyncMock(),
        user_id=user_id,
        jlpt_level="N5",
        distribution={"review": 2, "retry": 1, "new": 1},
        now=datetime(2026, 4, 20, tzinfo=UTC),
        loaders=SmartItemLoaders(
            load_review_items=load_review_items,
            load_retry_items=load_retry_items,
            load_studied_ids=load_studied_ids,
            load_new_items=load_new_items,
        ),
    )

    assert items == [review_item, retry_item, new_item]
    assert calls["review_count"] == 2
    assert calls["retry_count"] == 1
    assert calls["studied_user_id"] == user_id
    assert calls["new_count"] == 2
    assert calls["exclude_ids"] == {studied_id, review_item.id, retry_item.id}
