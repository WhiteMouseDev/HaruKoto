from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary

_CONTENT_MODEL_MAP: dict[str, type] = {
    "vocabulary": Vocabulary,
    "grammar": Grammar,
    "cloze": ClozeQuestion,
    "sentence_arrange": SentenceArrangeQuestion,
    "conversation": ConversationScenario,
}


class AdminContentDetailServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


async def get_admin_content_item(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: uuid.UUID,
) -> Any:
    model_class = _CONTENT_MODEL_MAP.get(content_type)
    if model_class is None:
        raise AdminContentDetailServiceError(status_code=400, detail=f"Unknown content_type: {content_type}")

    result: Any = await db.execute(select(model_class).where(model_class.id == item_id))  # type: ignore[attr-defined]
    item = result.scalar_one_or_none()
    if item is None:
        raise AdminContentDetailServiceError(status_code=404, detail="Not found")

    return item
