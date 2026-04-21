from __future__ import annotations

import uuid
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import ReviewStatus
from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary
from app.models.admin import AuditLog

type AdminContentReviewAction = Literal["approve", "reject"]

_CONTENT_MODEL_MAP: dict[str, type] = {
    "vocabulary": Vocabulary,
    "grammar": Grammar,
    "cloze": ClozeQuestion,
    "sentence_arrange": SentenceArrangeQuestion,
    "conversation": ConversationScenario,
}


class AdminContentReviewServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


async def review_admin_content_item(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: uuid.UUID,
    action: AdminContentReviewAction,
    reviewer_id: uuid.UUID,
    reason: str | None = None,
) -> Any:
    if action == "reject" and not reason:
        raise AdminContentReviewServiceError(status_code=422, detail="reason required for reject")

    model_class = _CONTENT_MODEL_MAP.get(content_type)
    if model_class is None:
        raise AdminContentReviewServiceError(status_code=400, detail=f"Unknown content_type: {content_type}")

    result: Any = await db.execute(select(model_class).where(model_class.id == item_id))  # type: ignore[attr-defined]
    item = result.scalar_one_or_none()
    if item is None:
        raise AdminContentReviewServiceError(status_code=404, detail="Not found")

    item.review_status = ReviewStatus.APPROVED if action == "approve" else ReviewStatus.REJECTED
    db.add(
        AuditLog(
            content_type=content_type,
            content_id=item_id,
            action=action,
            reason=reason,
            reviewer_id=reviewer_id,
        )
    )
    await db.commit()
    await db.refresh(item)

    return item
