from __future__ import annotations

import uuid
from types import SimpleNamespace

from app.services.quiz_smart_item_selection import build_exclude_ids, calculate_new_count_needed, dedupe_by_meaning, merge_smart_items


def test_calculate_new_count_needed_fills_review_and_retry_shortfalls():
    assert calculate_new_count_needed({"review": 2, "retry": 1, "new": 3}, review_count=1, retry_count=0) == 5


def test_build_exclude_ids_combines_studied_review_and_retry_ids():
    studied_id = uuid.uuid4()
    review_item = SimpleNamespace(id=uuid.uuid4(), meaning_ko="먹다")
    retry_item = SimpleNamespace(id=uuid.uuid4(), meaning_ko="보다")

    exclude_ids = build_exclude_ids([studied_id], [review_item], [retry_item])

    assert exclude_ids == {studied_id, review_item.id, retry_item.id}


def test_merge_smart_items_preserves_review_retry_new_order():
    review_item = SimpleNamespace(id=uuid.uuid4(), meaning_ko="먹다")
    retry_item = SimpleNamespace(id=uuid.uuid4(), meaning_ko="보다")
    new_item = SimpleNamespace(id=uuid.uuid4(), meaning_ko="가다")

    assert merge_smart_items([review_item], [retry_item], [new_item]) == [review_item, retry_item, new_item]


def test_dedupe_by_meaning_preserves_first_item_per_meaning():
    first_item = SimpleNamespace(id=uuid.uuid4(), meaning_ko="보다")
    duplicate_item = SimpleNamespace(id=uuid.uuid4(), meaning_ko="보다")
    second_item = SimpleNamespace(id=uuid.uuid4(), meaning_ko="먹다")

    assert dedupe_by_meaning([first_item, duplicate_item, second_item]) == [first_item, second_item]
