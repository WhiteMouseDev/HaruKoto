from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import ReviewStatus
from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary
from app.models.admin import AuditLog

type AdminBatchReviewAction = Literal["approve", "reject"]

_MODEL_MAP: dict[str, type] = {
    "vocabulary": Vocabulary,
    "grammar": Grammar,
    "cloze": ClozeQuestion,
    "sentence_arrange": SentenceArrangeQuestion,
    "conversation": ConversationScenario,
}


class AdminBatchReviewServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(frozen=True, slots=True)
class AdminBatchReviewResult:
    count: int


async def batch_review_content(
    db: AsyncSession,
    *,
    content_type: str,
    item_ids: list[uuid.UUID],
    action: AdminBatchReviewAction,
    reviewer_id: uuid.UUID,
    reason: str | None = None,
) -> AdminBatchReviewResult:
    if action == "reject" and not reason:
        raise AdminBatchReviewServiceError(status_code=422, detail="reason required for reject")

    model_class = _MODEL_MAP.get(content_type)
    if model_class is None:
        raise AdminBatchReviewServiceError(status_code=400, detail=f"Unknown content_type: {content_type}")

    new_status = ReviewStatus.APPROVED if action == "approve" else ReviewStatus.REJECTED

    for item_id in item_ids:
        result: Any = await db.execute(select(model_class).where(model_class.id == item_id))  # type: ignore[attr-defined]
        item = result.scalar_one_or_none()
        if item is None:
            raise AdminBatchReviewServiceError(status_code=404, detail=f"Item {item_id} not found")

        item.review_status = new_status
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
    return AdminBatchReviewResult(count=len(item_ids))
