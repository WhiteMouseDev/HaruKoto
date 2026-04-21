from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import JlptLevel, ReviewStatus
from app.models import Grammar

_GRAMMAR_SORT_COLS = {
    "created_at": Grammar.created_at,
    "review_status": Grammar.review_status,
    "jlpt_level": Grammar.jlpt_level,
}


@dataclass(frozen=True, slots=True)
class AdminGrammarListResult:
    items: list[Any]
    total: int
    page: int
    page_size: int
    total_pages: int


async def list_admin_grammar(
    db: AsyncSession,
    *,
    page: int,
    page_size: int,
    jlpt_level: JlptLevel | None = None,
    review_status: ReviewStatus | None = None,
    search: str | None = None,
    sort_by: str | None = None,
    sort_order: str = "desc",
) -> AdminGrammarListResult:
    q = select(Grammar)

    if jlpt_level is not None:
        q = q.where(Grammar.jlpt_level == jlpt_level)
    if review_status is not None:
        q = q.where(Grammar.review_status == review_status)
    if search:
        q = q.where(
            or_(
                Grammar.pattern.ilike(f"%{search}%"),
                Grammar.meaning_ko.ilike(f"%{search}%"),
            )
        )

    total_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = int(total_result.scalar_one())

    sort_col = _GRAMMAR_SORT_COLS.get(sort_by or "", Grammar.created_at)
    order_expr = sort_col.asc() if sort_order == "asc" else sort_col.desc()

    offset = (page - 1) * page_size
    items_result = await db.execute(q.order_by(order_expr).offset(offset).limit(page_size))
    items = list(items_result.scalars().all())

    return AdminGrammarListResult(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )
