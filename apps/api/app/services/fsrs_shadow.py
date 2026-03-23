"""FSRS Shadow Calculator — computes FSRS scheduling alongside SM-2 for comparison.

This service reads review_events and computes what FSRS *would* schedule,
without affecting actual SRS state. Used for data-driven migration decisions.
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fsrs import Card, Rating, Scheduler
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

# Map our internal ratings to FSRS Rating enum
_RATING_MAP = {
    0: Rating.Again,
    1: Rating.Again,
    2: Rating.Hard,
    3: Rating.Good,
    4: Rating.Easy,
    5: Rating.Easy,
}

# Singleton FSRS scheduler with default parameters
_fsrs = Scheduler()


async def compute_shadow_for_user(
    db: AsyncSession,
    user_id: UUID,
    item_type: str = "WORD",
    limit: int = 100,
) -> list[dict]:
    """Compute FSRS shadow scheduling for a user's review history.

    Returns list of items with SM-2 vs FSRS interval comparison.
    """
    # Get review events for this user filtered by item_type, ordered by time
    id_col = "vocabulary_id" if item_type == "WORD" else "grammar_id"
    result = await db.execute(
        text(f"""
            SELECT {id_col} as item_id, rating, is_correct, created_at
            FROM review_events
            WHERE user_id = :user_id AND {id_col} IS NOT NULL
            ORDER BY created_at ASC
            LIMIT :limit
        """),
        {"user_id": user_id, "limit": limit * 10},
    )
    rows = result.fetchall()

    if not rows:
        return []

    # Group events by item
    item_events: dict[str, list] = {}
    for row in rows:
        iid = str(row.item_id)
        if iid not in item_events:
            item_events[iid] = []
        item_events[iid].append(row)

    # For each item, replay through FSRS
    comparisons = []
    for item_id, events in list(item_events.items())[:limit]:
        card = Card()
        fsrs_interval = 0

        for event in events:
            rating = _RATING_MAP.get(event.rating, Rating.Good)
            review_time = event.created_at if event.created_at.tzinfo else event.created_at.replace(tzinfo=UTC)
            card, _review_log = _fsrs.review_card(card, rating, review_time)

        # Calculate interval from due - last_review
        fsrs_interval = 0
        if card.due and card.last_review:
            fsrs_interval = (card.due - card.last_review).days

        comparisons.append(
            {
                "item_id": item_id,
                "item_type": item_type,
                "review_count": len(events),
                "fsrs_interval_days": fsrs_interval,
                "fsrs_stability": round(card.stability, 2),
                "fsrs_difficulty": round(card.difficulty, 2),
            }
        )

    return comparisons


async def get_shadow_report(db: AsyncSession, user_id: UUID) -> dict:
    """Generate a summary report comparing SM-2 and FSRS scheduling."""
    vocab_shadows = await compute_shadow_for_user(db, user_id, "WORD", limit=50)
    grammar_shadows = await compute_shadow_for_user(db, user_id, "GRAMMAR", limit=50)

    all_shadows = vocab_shadows + grammar_shadows

    if not all_shadows:
        return {
            "total_items": 0,
            "avg_fsrs_interval": 0,
            "avg_fsrs_stability": 0,
            "items": [],
        }

    avg_interval = sum(s["fsrs_interval_days"] for s in all_shadows) / len(all_shadows)
    avg_stability = sum(s["fsrs_stability"] for s in all_shadows) / len(all_shadows)

    return {
        "total_items": len(all_shadows),
        "avg_fsrs_interval": round(avg_interval, 1),
        "avg_fsrs_stability": round(avg_stability, 2),
        "computed_at": datetime.now(UTC).isoformat(),
        "items": all_shadows[:20],  # Top 20 for preview
    }
