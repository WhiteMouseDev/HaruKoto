from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import JlptLevel, ReviewStatus
from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary

REVIEW_QUEUE_LIMIT = 200

_MODEL_MAP: dict[str, Any] = {
    "vocabulary": Vocabulary,
    "grammar": Grammar,
    "cloze": ClozeQuestion,
    "sentence_arrange": SentenceArrangeQuestion,
    "conversation": ConversationScenario,
}


class AdminReviewQueueServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(frozen=True, slots=True)
class AdminReviewQueueItem:
    id: str
    quiz_type: str | None = None


@dataclass(frozen=True, slots=True)
class AdminReviewQueueResult:
    items: list[AdminReviewQueueItem]
    total: int
    capped: bool


async def get_admin_review_queue(
    db: AsyncSession,
    content_type: str,
    *,
    jlpt_level: JlptLevel | None = None,
    category: str | None = None,
    limit: int = REVIEW_QUEUE_LIMIT,
) -> AdminReviewQueueResult:
    if content_type == "quiz":
        return await _get_quiz_review_queue(db, jlpt_level=jlpt_level, limit=limit)

    model = _MODEL_MAP.get(content_type)
    if model is None:
        raise AdminReviewQueueServiceError(status_code=400, detail=f"Unknown content type: {content_type}")

    query = select(model.id).where(model.review_status == ReviewStatus.NEEDS_REVIEW)
    if jlpt_level is not None:
        query = query.where(model.jlpt_level == jlpt_level)
    if category is not None and content_type == "conversation":
        query = query.where(ConversationScenario.category == category)

    query = query.order_by(model.created_at.asc()).limit(limit + 1)
    result = await db.execute(query)
    all_ids = [str(row[0]) for row in result.all()]

    capped = len(all_ids) > limit
    ids = all_ids[:limit]

    return AdminReviewQueueResult(
        items=[AdminReviewQueueItem(id=item_id) for item_id in ids],
        total=len(ids),
        capped=capped,
    )


async def _get_quiz_review_queue(
    db: AsyncSession,
    *,
    jlpt_level: JlptLevel | None,
    limit: int,
) -> AdminReviewQueueResult:
    items: list[tuple[str, str, datetime]] = []

    cloze_query = select(ClozeQuestion.id, ClozeQuestion.created_at).where(ClozeQuestion.review_status == ReviewStatus.NEEDS_REVIEW)
    if jlpt_level is not None:
        cloze_query = cloze_query.where(ClozeQuestion.jlpt_level == jlpt_level)
    cloze_result = await db.execute(cloze_query)
    for row in cloze_result.all():
        items.append((str(row[0]), "cloze", row[1]))

    arrange_query = select(SentenceArrangeQuestion.id, SentenceArrangeQuestion.created_at).where(
        SentenceArrangeQuestion.review_status == ReviewStatus.NEEDS_REVIEW
    )
    if jlpt_level is not None:
        arrange_query = arrange_query.where(SentenceArrangeQuestion.jlpt_level == jlpt_level)
    arrange_result = await db.execute(arrange_query)
    for row in arrange_result.all():
        items.append((str(row[0]), "sentence_arrange", row[1]))

    items.sort(key=lambda item: item[2])
    capped = len(items) > limit
    limited_items = items[:limit]

    return AdminReviewQueueResult(
        items=[AdminReviewQueueItem(id=item_id, quiz_type=quiz_type) for item_id, quiz_type, _ in limited_items],
        total=len(limited_items),
        capped=capped,
    )
