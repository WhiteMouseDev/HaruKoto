from __future__ import annotations

import math
import uuid
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import JlptLevel, ReviewStatus, ScenarioCategory
from app.models import ConversationScenario

_CONVERSATION_SORT_COLS = {
    "created_at": ConversationScenario.created_at,
    "review_status": ConversationScenario.review_status,
    "category": ConversationScenario.category,
}


@dataclass(frozen=True, slots=True)
class AdminConversationListItem:
    id: uuid.UUID
    title: str
    category: str
    jlpt_level: None
    review_status: str
    created_at: datetime


@dataclass(frozen=True, slots=True)
class AdminConversationListResult:
    items: list[AdminConversationListItem]
    total: int
    page: int
    page_size: int
    total_pages: int


async def list_admin_conversation(
    db: AsyncSession,
    *,
    page: int,
    page_size: int,
    jlpt_level: JlptLevel | None = None,
    review_status: ReviewStatus | None = None,
    search: str | None = None,
    category: ScenarioCategory | None = None,
    sort_by: str | None = None,
    sort_order: str = "desc",
) -> AdminConversationListResult:
    # ConversationScenario has no jlpt_level column; keep the parameter for list API parity.
    _ = jlpt_level
    q = select(ConversationScenario)

    if category is not None:
        q = q.where(ConversationScenario.category == category)
    if review_status is not None:
        q = q.where(ConversationScenario.review_status == review_status)
    if search:
        q = q.where(
            or_(
                ConversationScenario.title.ilike(f"%{search}%"),
                ConversationScenario.title_ja.ilike(f"%{search}%"),
                ConversationScenario.description.ilike(f"%{search}%"),
            )
        )

    total_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = int(total_result.scalar_one())

    sort_col = _CONVERSATION_SORT_COLS.get(sort_by or "", ConversationScenario.created_at)
    order_expr = sort_col.asc() if sort_order == "asc" else sort_col.desc()

    offset = (page - 1) * page_size
    items_result = await db.execute(q.order_by(order_expr).offset(offset).limit(page_size))
    items = list(items_result.scalars().all())

    return AdminConversationListResult(
        items=[
            AdminConversationListItem(
                id=item.id,
                title=item.title,
                category=_enum_value(item.category),
                jlpt_level=None,
                review_status=_enum_value(item.review_status),
                created_at=item.created_at,
            )
            for item in items
        ],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )


def _enum_value(value: object) -> str:
    if hasattr(value, "value"):
        return str(value.value)
    return str(value)
