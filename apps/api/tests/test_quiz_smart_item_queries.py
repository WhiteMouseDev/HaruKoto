from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.quiz_smart_item_queries import (
    load_grammar_retry_items,
    load_grammar_review_items,
    load_grammar_studied_ids,
    load_new_grammar_items,
    load_new_vocab_items,
    load_vocab_retry_items,
    load_vocab_review_items,
    load_vocab_studied_ids,
)


def _scalars_result(items: list[object]) -> MagicMock:
    result = MagicMock()
    result.scalars.return_value.all.return_value = items
    return result


@pytest.mark.asyncio
@pytest.mark.parametrize("loader", [load_vocab_review_items, load_vocab_retry_items, load_grammar_review_items, load_grammar_retry_items])
async def test_count_limited_progress_loaders_skip_db_when_count_is_zero(loader):
    db = AsyncMock()

    items = await loader(db, user_id=uuid.uuid4(), jlpt_level="N5", count=0, now=datetime(2026, 4, 20, tzinfo=UTC))

    assert items == []
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("loader", [load_new_vocab_items, load_new_grammar_items])
async def test_count_limited_new_item_loaders_skip_db_when_count_is_zero(loader):
    db = AsyncMock()

    items = await loader(db, jlpt_level="N5", count=0, exclude_ids={uuid.uuid4()})

    assert items == []
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("loader", [load_vocab_studied_ids, load_grammar_studied_ids])
async def test_studied_id_loaders_return_id_sets(loader):
    first_id = uuid.uuid4()
    second_id = uuid.uuid4()
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_scalars_result([first_id, second_id]))

    studied_ids = await loader(db, user_id=uuid.uuid4())

    assert studied_ids == {first_id, second_id}


@pytest.mark.asyncio
@pytest.mark.parametrize("loader", [load_new_vocab_items, load_new_grammar_items])
async def test_new_item_loaders_return_query_results(loader):
    first_item = SimpleNamespace(id=uuid.uuid4())
    second_item = SimpleNamespace(id=uuid.uuid4())
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_scalars_result([first_item, second_item]))

    items = await loader(db, jlpt_level="N5", count=2, exclude_ids={uuid.uuid4()})

    assert items == [first_item, second_item]
