"""SRS smart session card selection.

This module owns query construction and card ordering for smart SRS sessions.
The core SRS service keeps answer processing and review-event persistence.
"""

from __future__ import annotations

from collections.abc import Iterable
from datetime import UTC, date, datetime
from typing import Any, TypedDict
from uuid import UUID

from sqlalchemy import case, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Grammar, Vocabulary
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.services.srs_transition import LEARNING, PROVISIONAL, RELEARNING, REVIEW, UNSEEN

type ProgressModel = type[UserVocabProgress] | type[UserGrammarProgress]
type ContentModel = type[Vocabulary] | type[Grammar]


class SessionCard(TypedDict):
    item_id: str
    item_type: str
    direction: str
    is_new: bool


def _get_progress_model(item_type: str) -> ProgressModel:
    """Return the correct progress model class for the given item type."""
    if item_type == "WORD":
        return UserVocabProgress
    if item_type == "GRAMMAR":
        return UserGrammarProgress
    msg = f"Unknown item_type: {item_type!r}. Expected 'WORD' or 'GRAMMAR'."
    raise ValueError(msg)


def _get_content_model(item_type: str) -> ContentModel:
    """Return the content model for joining jlpt_level."""
    if item_type == "WORD":
        return Vocabulary
    if item_type == "GRAMMAR":
        return Grammar
    msg = f"Unknown item_type: {item_type!r}."
    raise ValueError(msg)


def _get_content_join_col(item_type: str) -> tuple[Any, Any]:
    """Return (progress_fk_column, content_pk_column) for joining."""
    if item_type == "WORD":
        return UserVocabProgress.vocabulary_id, Vocabulary.id
    return UserGrammarProgress.grammar_id, Grammar.id


def _assign_direction(index: int) -> str:
    """Alternate direction: even index -> JP_KR, odd -> KR_JP."""
    return "JP_KR" if index % 2 == 0 else "KR_JP"


async def _count_new_cards_today(
    db: AsyncSession,
    user_id: UUID,
    today: date,
) -> int:
    """Count new cards already presented today from review_events."""
    result = await db.execute(
        text("""
            SELECT COUNT(*) FROM review_events
            WHERE user_id = :user_id
              AND reviewed_on = :today
              AND is_new_card = true
        """),
        {"user_id": user_id, "today": today},
    )
    return result.scalar() or 0


async def build_smart_session(
    db: AsyncSession,
    user_id: UUID,
    item_type: str,  # 'WORD' | 'GRAMMAR'
    jlpt_level: str,
    count: int = 20,
    daily_new_cap: int = 10,
) -> list[SessionCard]:
    """Build a smart quiz session with SRS-prioritized card selection.

    Returns list of {item_id, item_type, direction, is_new} dicts.

    Card selection priority:
    1. Due cards (next_review_at <= now) sorted by state priority and overdue amount
    2. New cards with existing UNSEEN progress, capped by daily_new_cap and 20% of session
    3. Fresh content with no progress record, under the same new-card cap
    4. Preview REVIEW cards not yet due

    Rules:
    - No same-day re-presentation (last_presented_on != today)
    - New cards ratio <= 20% of session
    - Due cards always take priority over new cards
    """
    now = datetime.now(UTC)
    today = now.date()

    model = _get_progress_model(item_type)
    content_model = _get_content_model(item_type)
    fk_col, content_pk = _get_content_join_col(item_type)

    not_presented_today = (model.last_presented_on.is_(None)) | (model.last_presented_on < today)

    state_priority = case(
        (model.state == RELEARNING, 0),
        (model.state == LEARNING, 1),
        (model.state == PROVISIONAL, 2),
        else_=3,
    )

    due_stmt = (
        select(fk_col, model.state)
        .join(content_model, fk_col == content_pk)
        .where(
            model.user_id == user_id,
            content_model.jlpt_level == jlpt_level,
            model.state.in_([RELEARNING, LEARNING, REVIEW, PROVISIONAL]),
            model.next_review_at <= now,
            not_presented_today,
        )
        .order_by(state_priority, model.next_review_at.asc())
        .limit(count)
    )
    due_result = await db.execute(due_stmt)
    due_rows = due_result.all()

    cards: list[SessionCard] = []
    seen_ids: set[str] = set()
    _append_rows(
        cards,
        seen_ids,
        due_rows,
        item_type=item_type,
        is_new=False,
    )

    if len(cards) >= count:
        return cards[:count]

    new_cards_today = await _count_new_cards_today(db, user_id, today)
    remaining_new_cap = max(0, daily_new_cap - new_cards_today)
    max_new_in_session = max(1, count // 5)
    new_limit = min(remaining_new_cap, max_new_in_session, count - len(cards))

    if new_limit > 0:
        new_stmt = (
            select(fk_col)
            .join(content_model, fk_col == content_pk)
            .where(
                model.user_id == user_id,
                content_model.jlpt_level == jlpt_level,
                model.state == UNSEEN,
                not_presented_today,
            )
            .order_by(func.random())
            .limit(new_limit)
        )
        new_result = await db.execute(new_stmt)
        _append_rows(
            cards,
            seen_ids,
            new_result.all(),
            item_type=item_type,
            is_new=True,
        )

    if len(cards) >= count:
        return cards[:count]

    new_count = sum(1 for card in cards if card["is_new"])
    unseen_no_record_limit = min(
        max(0, remaining_new_cap - new_count),
        max(0, max_new_in_session - new_count),
        count - len(cards),
    )

    if unseen_no_record_limit > 0:
        existing_ids_subq = select(fk_col).where(model.user_id == user_id).scalar_subquery()

        fresh_stmt = (
            select(content_model.id)
            .where(
                content_model.jlpt_level == jlpt_level,
                content_model.id.notin_(existing_ids_subq),
            )
            .order_by(func.random())
            .limit(unseen_no_record_limit)
        )
        fresh_result = await db.execute(fresh_stmt)
        _append_rows(
            cards,
            seen_ids,
            fresh_result.all(),
            item_type=item_type,
            is_new=True,
        )

    if len(cards) >= count:
        return cards[:count]

    remaining = count - len(cards)
    if remaining > 0:
        preview_stmt = (
            select(fk_col)
            .join(content_model, fk_col == content_pk)
            .where(
                model.user_id == user_id,
                content_model.jlpt_level == jlpt_level,
                model.state == REVIEW,
                model.next_review_at > now,
                not_presented_today,
            )
            .order_by(model.next_review_at.asc())
            .limit(remaining)
        )
        preview_result = await db.execute(preview_stmt)
        _append_rows(
            cards,
            seen_ids,
            preview_result.all(),
            item_type=item_type,
            is_new=False,
        )

    return cards[:count]


def _append_rows(
    cards: list[SessionCard],
    seen_ids: set[str],
    rows: Iterable[Any],
    *,
    item_type: str,
    is_new: bool,
) -> None:
    for row in rows:
        item_id_val = str(row[0])
        if item_id_val in seen_ids:
            continue
        seen_ids.add(item_id_val)
        cards.append(
            SessionCard(
                item_id=item_id_val,
                item_type=item_type,
                direction=_assign_direction(len(cards)),
                is_new=is_new,
            )
        )
