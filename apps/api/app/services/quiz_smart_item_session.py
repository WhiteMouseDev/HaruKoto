from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.quiz_smart_item_selection import build_exclude_ids, calculate_new_count_needed, dedupe_by_meaning, merge_smart_items


class SmartSessionItem(Protocol):
    id: uuid.UUID
    meaning_ko: str


class ProgressItemsLoader[SmartItem: SmartSessionItem](Protocol):
    async def __call__(
        self,
        db: AsyncSession,
        *,
        user_id: uuid.UUID,
        jlpt_level: str,
        count: int,
        now: datetime,
    ) -> list[SmartItem]: ...


class StudiedIdsLoader(Protocol):
    async def __call__(self, db: AsyncSession, *, user_id: uuid.UUID) -> set[uuid.UUID]: ...


class NewItemsLoader[SmartItem: SmartSessionItem](Protocol):
    async def __call__(
        self,
        db: AsyncSession,
        *,
        jlpt_level: str,
        count: int,
        exclude_ids: set[uuid.UUID],
    ) -> list[SmartItem]: ...


@dataclass(frozen=True)
class SmartItemLoaders[SmartItem: SmartSessionItem]:
    load_review_items: ProgressItemsLoader[SmartItem]
    load_retry_items: ProgressItemsLoader[SmartItem]
    load_studied_ids: StudiedIdsLoader
    load_new_items: NewItemsLoader[SmartItem]


async def load_selected_smart_items[SmartItem: SmartSessionItem](
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    jlpt_level: str,
    distribution: dict[str, int],
    now: datetime,
    loaders: SmartItemLoaders[SmartItem],
) -> list[SmartItem]:
    review_items = await loaders.load_review_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["review"], now=now)
    retry_items = await loaders.load_retry_items(db, user_id=user_id, jlpt_level=jlpt_level, count=distribution["retry"], now=now)

    studied_ids = await loaders.load_studied_ids(db, user_id=user_id)
    exclude_ids = build_exclude_ids(studied_ids, review_items, retry_items)

    new_count_needed = calculate_new_count_needed(distribution, review_count=len(review_items), retry_count=len(retry_items))
    new_items = await loaders.load_new_items(db, jlpt_level=jlpt_level, count=new_count_needed, exclude_ids=exclude_ids)

    return dedupe_by_meaning(merge_smart_items(review_items, retry_items, new_items))
