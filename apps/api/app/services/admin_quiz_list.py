from __future__ import annotations

import math
import uuid
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import func, literal, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import JlptLevel, ReviewStatus
from app.models import ClozeQuestion, SentenceArrangeQuestion

_QUIZ_SORT_COLS = {"created_at", "review_status", "jlpt_level"}


@dataclass(frozen=True, slots=True)
class AdminQuizListItem:
    id: uuid.UUID
    sentence: str
    quiz_type: str
    jlpt_level: str
    review_status: str
    created_at: datetime


@dataclass(frozen=True, slots=True)
class AdminQuizListResult:
    items: list[AdminQuizListItem]
    total: int
    page: int
    page_size: int
    total_pages: int


async def list_admin_quiz(
    db: AsyncSession,
    *,
    page: int,
    page_size: int,
    jlpt_level: JlptLevel | None = None,
    review_status: ReviewStatus | None = None,
    search: str | None = None,
    quiz_type: str | None = None,
    sort_by: str | None = None,
    sort_order: str = "desc",
) -> AdminQuizListResult:
    cloze_proj = select(
        ClozeQuestion.id,
        ClozeQuestion.sentence.label("sentence"),
        literal("cloze").label("quiz_type"),
        ClozeQuestion.jlpt_level.label("jlpt_level"),
        ClozeQuestion.review_status.label("review_status"),
        ClozeQuestion.created_at,
    )
    if jlpt_level is not None:
        cloze_proj = cloze_proj.where(ClozeQuestion.jlpt_level == jlpt_level)
    if review_status is not None:
        cloze_proj = cloze_proj.where(ClozeQuestion.review_status == review_status)
    if search:
        cloze_proj = cloze_proj.where(ClozeQuestion.sentence.ilike(f"%{search}%"))

    arrange_proj = select(
        SentenceArrangeQuestion.id,
        SentenceArrangeQuestion.korean_sentence.label("sentence"),
        literal("sentence_arrange").label("quiz_type"),
        SentenceArrangeQuestion.jlpt_level.label("jlpt_level"),
        SentenceArrangeQuestion.review_status.label("review_status"),
        SentenceArrangeQuestion.created_at,
    )
    if jlpt_level is not None:
        arrange_proj = arrange_proj.where(SentenceArrangeQuestion.jlpt_level == jlpt_level)
    if review_status is not None:
        arrange_proj = arrange_proj.where(SentenceArrangeQuestion.review_status == review_status)
    if search:
        arrange_proj = arrange_proj.where(SentenceArrangeQuestion.korean_sentence.ilike(f"%{search}%"))

    if quiz_type == "cloze":
        combined = cloze_proj.subquery()
    elif quiz_type == "sentence_arrange":
        combined = arrange_proj.subquery()
    else:
        combined = union_all(cloze_proj, arrange_proj).subquery()

    total_result = await db.execute(select(func.count()).select_from(combined))
    total = int(total_result.scalar_one())

    effective_sort_by = sort_by if sort_by in _QUIZ_SORT_COLS else "created_at"
    sort_col = combined.c[effective_sort_by]
    order_expr = sort_col.asc() if sort_order == "asc" else sort_col.desc()

    offset = (page - 1) * page_size
    items_result = await db.execute(select(combined).order_by(order_expr).offset(offset).limit(page_size))
    rows = items_result.all()

    return AdminQuizListResult(
        items=[
            AdminQuizListItem(
                id=row.id,
                sentence=row.sentence,
                quiz_type=row.quiz_type,
                jlpt_level=_enum_value(row.jlpt_level),
                review_status=_enum_value(row.review_status),
                created_at=row.created_at,
            )
            for row in rows
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
