from __future__ import annotations

import uuid
from collections.abc import Iterable
from typing import Protocol


class SmartContentItem(Protocol):
    id: uuid.UUID
    meaning_ko: str


def calculate_new_count_needed(distribution: dict[str, int], *, review_count: int, retry_count: int) -> int:
    review_shortfall = distribution["review"] - review_count
    retry_shortfall = distribution["retry"] - retry_count
    return distribution["new"] + review_shortfall + retry_shortfall


def build_exclude_ids(
    studied_ids: Iterable[uuid.UUID],
    review_items: Iterable[SmartContentItem],
    retry_items: Iterable[SmartContentItem],
) -> set[uuid.UUID]:
    return set(studied_ids) | {item.id for item in review_items} | {item.id for item in retry_items}


def merge_smart_items[SmartItem: SmartContentItem](
    review_items: Iterable[SmartItem],
    retry_items: Iterable[SmartItem],
    new_items: Iterable[SmartItem],
) -> list[SmartItem]:
    return [*review_items, *retry_items, *new_items]


def dedupe_by_meaning[SmartItem: SmartContentItem](items: Iterable[SmartItem]) -> list[SmartItem]:
    deduped: list[SmartItem] = []
    seen_meanings: set[str] = set()
    for item in items:
        if item.meaning_ko in seen_meanings:
            continue
        seen_meanings.add(item.meaning_ko)
        deduped.append(item)
    return deduped
