from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import ReviewStatus
from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary

_CONTENT_STAT_MODELS: tuple[tuple[str, Any], ...] = (
    ("vocabulary", Vocabulary),
    ("grammar", Grammar),
    ("cloze", ClozeQuestion),
    ("sentence_arrange", SentenceArrangeQuestion),
    ("conversation", ConversationScenario),
)


@dataclass(frozen=True, slots=True)
class AdminContentStatsItem:
    content_type: str
    needs_review: int
    approved: int
    rejected: int
    total: int


async def get_admin_content_stats(db: AsyncSession) -> list[AdminContentStatsItem]:
    stats: list[AdminContentStatsItem] = []

    for content_type, model in _CONTENT_STAT_MODELS:
        count_q = select(model.review_status, func.count().label("cnt")).group_by(model.review_status)
        result = await db.execute(count_q)
        counts = {_review_status_key(row[0]): int(row[1]) for row in result.all()}

        needs_review = counts.get(ReviewStatus.NEEDS_REVIEW.value, 0)
        approved = counts.get(ReviewStatus.APPROVED.value, 0)
        rejected = counts.get(ReviewStatus.REJECTED.value, 0)

        stats.append(
            AdminContentStatsItem(
                content_type=content_type,
                needs_review=needs_review,
                approved=approved,
                rejected=rejected,
                total=needs_review + approved + rejected,
            )
        )

    return stats


def _review_status_key(value: object) -> str:
    if isinstance(value, ReviewStatus):
        return value.value
    return str(value)
