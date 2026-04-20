"""SRS (Spaced Repetition System) core service.

State machine: UNSEEN → PROVISIONAL → LEARNING → REVIEW → MASTERED
                                                   ↓
                                             RELEARNING → REVIEW

Scheduler version 1: SM-2 interval calculation.
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Any, TypedDict, cast
from uuid import UUID

from sqlalchemy import case, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Grammar, Vocabulary
from app.models.lesson import LessonItemLink
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.services.srs_transition import (
    AGAIN,
    HARD,
    LEARNING,
    LEARNING_INTERVALS,
    PROVISIONAL,
    RELEARNING,
    REVIEW,
    UNSEEN,
    apply_transition,
    calculate_rating,
)

type ProgressRecord = UserVocabProgress | UserGrammarProgress
type ProgressModel = type[UserVocabProgress] | type[UserGrammarProgress]
type ContentModel = type[Vocabulary] | type[Grammar]

# ---------------------------------------------------------------------------
# Return types
# ---------------------------------------------------------------------------


class AnswerResult(TypedDict):
    state_before: str
    state_after: str
    next_review_at: str | None
    is_provisional_phase: bool


def _get_progress_model(item_type: str) -> ProgressModel:
    """Return the correct progress model class for the given item type."""
    if item_type == "WORD":
        return UserVocabProgress
    if item_type == "GRAMMAR":
        return UserGrammarProgress
    msg = f"Unknown item_type: {item_type!r}. Expected 'WORD' or 'GRAMMAR'."
    raise ValueError(msg)


def _get_item_fk_column(item_type: str) -> str:
    """Return the foreign key column name for the given item type."""
    if item_type == "WORD":
        return "vocabulary_id"
    if item_type == "GRAMMAR":
        return "grammar_id"
    msg = f"Unknown item_type: {item_type!r}."
    raise ValueError(msg)


# ---------------------------------------------------------------------------
# Core service functions
# ---------------------------------------------------------------------------


async def register_items_from_lesson(
    db: AsyncSession,
    user_id: UUID,
    lesson_id: UUID,
    item_links: list[LessonItemLink],
) -> int:
    """Register lesson items into SRS. Returns count of newly registered items.

    For each WORD/GRAMMAR link:
    - If UNSEEN → set state=PROVISIONAL, introduced_by=LESSON, source_lesson_id
    - If already registered (state != UNSEEN) → skip (no duplicate)
    """
    registered = 0

    for link in item_links:
        if link.item_type not in ("WORD", "GRAMMAR"):
            continue

        model = _get_progress_model(link.item_type)
        fk_col = _get_item_fk_column(link.item_type)
        item_id = link.vocabulary_id if link.item_type == "WORD" else link.grammar_id

        if item_id is None:
            continue

        # Check if progress record already exists
        stmt = select(model).where(
            model.user_id == user_id,
            getattr(model, fk_col) == item_id,
        )
        result = await db.execute(stmt)
        progress = cast(ProgressRecord | None, result.scalar_one_or_none())

        if progress is not None:
            # Already registered — upgrade if UNSEEN, otherwise skip
            if progress.state == UNSEEN:
                progress.state = LEARNING
                progress.introduced_by = "LESSON"
                progress.source_lesson_id = lesson_id
                progress.learning_step = 0
                progress.next_review_at = datetime.now(UTC) + timedelta(days=LEARNING_INTERVALS[0])
                registered += 1
        else:
            # Create new progress record
            new_progress = model(
                id=uuid.uuid4(),
                user_id=user_id,
                **{fk_col: item_id},
                state=LEARNING,
                introduced_by="LESSON",
                source_lesson_id=lesson_id,
                learning_step=0,
                next_review_at=datetime.now(UTC) + timedelta(days=LEARNING_INTERVALS[0]),
            )
            db.add(new_progress)
            registered += 1

    await db.flush()
    return registered


async def log_review_event(
    db: AsyncSession,
    user_id: UUID,
    item_type: str,
    item_id: UUID,
    session_id: UUID | None,
    lesson_id: UUID | None,
    direction: str,
    is_correct: bool,
    response_ms: int,
    rating: int,
    state_before: str,
    state_after: str,
    distractor_difficulty: str | None,
    is_provisional_phase: bool,
    is_new_card: bool,
    reviewed_on: date,
) -> None:
    """Insert a row into the partitioned review_events table (raw SQL)."""
    vocab_id = item_id if item_type == "WORD" else None
    grammar_id = item_id if item_type == "GRAMMAR" else None

    await db.execute(
        text("""
            INSERT INTO review_events (
                user_id, item_type, vocabulary_id, grammar_id,
                session_id, lesson_id, direction, is_correct,
                response_ms, rating, state_before, state_after,
                distractor_difficulty, is_provisional_phase,
                is_new_card, reviewed_on
            ) VALUES (
                :user_id, :item_type, :vocabulary_id, :grammar_id,
                :session_id, :lesson_id, :direction, :is_correct,
                :response_ms, :rating, :state_before, :state_after,
                :distractor_difficulty, :is_provisional_phase,
                :is_new_card, :reviewed_on
            )
        """),
        {
            "user_id": user_id,
            "item_type": item_type,
            "vocabulary_id": vocab_id,
            "grammar_id": grammar_id,
            "session_id": session_id,
            "lesson_id": lesson_id,
            "direction": direction,
            "is_correct": is_correct,
            "response_ms": response_ms,
            "rating": rating,
            "state_before": state_before,
            "state_after": state_after,
            "distractor_difficulty": distractor_difficulty,
            "is_provisional_phase": is_provisional_phase,
            "is_new_card": is_new_card,
            "reviewed_on": reviewed_on,
        },
    )


async def process_answer(
    db: AsyncSession,
    user_id: UUID,
    item_type: str,  # 'WORD' | 'GRAMMAR'
    item_id: UUID,
    is_correct: bool,
    direction: str,  # 'JP_KR' | 'KR_JP'
    response_ms: int,
    session_id: UUID | None = None,
    lesson_id: UUID | None = None,
) -> AnswerResult:
    """Process a quiz answer and update SRS state.

    Returns state transition info including before/after states and next review.
    """
    model = _get_progress_model(item_type)
    fk_col = _get_item_fk_column(item_type)

    # 1. Get current progress record
    stmt = select(model).where(
        model.user_id == user_id,
        getattr(model, fk_col) == item_id,
    )
    result = await db.execute(stmt)
    progress = cast(ProgressRecord | None, result.scalar_one_or_none())

    # If no progress record exists, create one (quiz tab first encounter)
    if progress is None:
        progress = model(
            id=uuid.uuid4(),
            user_id=user_id,
            **{fk_col: item_id},
            state=PROVISIONAL,
            introduced_by="QUIZ",
            learning_step=0,
        )
        db.add(progress)

    state_before = progress.state

    # 2. Calculate rating
    rating = calculate_rating(is_correct, response_ms)

    # For PROVISIONAL first correct answer, force rating to HARD (찍기 방지)
    if state_before == UNSEEN:
        rating = HARD if is_correct else AGAIN

    # Handle UNSEEN → PROVISIONAL transition (quiz tab first encounter)
    if state_before == UNSEEN:
        progress.state = PROVISIONAL
        progress.introduced_by = "QUIZ"
        progress.learning_step = 0
        state_before = UNSEEN  # keep original for return value

    # 3. Apply state transition
    now = datetime.now(UTC)
    apply_transition(progress, is_correct, rating, now)

    # 4. Update directional stats
    _update_direction_stats(progress, direction, is_correct)

    # 5. Update common fields
    progress.last_reviewed_at = now
    progress.last_presented_on = now.date()
    progress.fsrs_last_rating = rating
    progress.fsrs_reps += 1

    if is_correct:
        progress.correct_count += 1
        progress.streak += 1
    else:
        progress.incorrect_count += 1
        progress.streak = 0
        progress.fsrs_lapses += 1

    # 6. Log review event (before flush — both go in same transaction)
    is_new_card = state_before in (UNSEEN, PROVISIONAL)
    await log_review_event(
        db=db,
        user_id=user_id,
        item_type=item_type,
        item_id=item_id,
        session_id=session_id,
        lesson_id=lesson_id,
        direction=direction,
        is_correct=is_correct,
        response_ms=response_ms,
        rating=rating,
        state_before=state_before,
        state_after=progress.state,
        distractor_difficulty=None,
        is_provisional_phase=progress.state == PROVISIONAL,
        is_new_card=is_new_card,
        reviewed_on=now.date(),
    )

    # Flush both progress update + review event atomically
    await db.flush()

    return AnswerResult(
        state_before=state_before,
        state_after=progress.state,
        next_review_at=progress.next_review_at.isoformat() if progress.next_review_at else None,
        is_provisional_phase=progress.state == PROVISIONAL,
    )


def _update_direction_stats(
    progress: ProgressRecord,
    direction: str,
    is_correct: bool,
) -> None:
    """Update directional statistics (JP→KR / KR→JP)."""
    if direction == "JP_KR":
        progress.jp_kr_total += 1
        if is_correct:
            progress.jp_kr_correct += 1
    elif direction == "KR_JP":
        progress.kr_jp_total += 1
        if is_correct:
            progress.kr_jp_correct += 1


# ---------------------------------------------------------------------------
# Smart session builder
# ---------------------------------------------------------------------------


class SessionCard(TypedDict):
    item_id: str
    item_type: str
    direction: str
    is_new: bool


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
    """Alternate direction: even index → JP_KR, odd → KR_JP."""
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
    1. Due cards (next_review_at <= now) — sorted by overdue amount
    2. RELEARNING cards — highest priority within due
    3. LEARNING cards — next priority
    4. New cards (UNSEEN/PROVISIONAL) — capped by daily_new_cap
    5. Fill remaining with REVIEW cards not yet due (preview)

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

    # Shared filter: exclude items already presented today
    not_presented_today = (model.last_presented_on.is_(None)) | (model.last_presented_on < today)

    # -------------------------------------------------------------------
    # 1. Due cards: RELEARNING > LEARNING > REVIEW/PROVISIONAL, then by
    #    overdue amount (next_review_at ASC = most overdue first)
    # -------------------------------------------------------------------
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

    for row in due_rows:
        item_id_val = str(row[0])
        if item_id_val in seen_ids:
            continue
        seen_ids.add(item_id_val)
        cards.append(
            SessionCard(
                item_id=item_id_val,
                item_type=item_type,
                direction=_assign_direction(len(cards)),
                is_new=False,
            )
        )

    if len(cards) >= count:
        return cards[:count]

    # -------------------------------------------------------------------
    # 2. New cards (UNSEEN) — capped by daily_new_cap and 20% of session
    # -------------------------------------------------------------------
    new_cards_today = await _count_new_cards_today(db, user_id, today)
    remaining_new_cap = max(0, daily_new_cap - new_cards_today)
    max_new_in_session = max(1, count // 5)  # 20% of session
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
        new_rows = new_result.all()

        for row in new_rows:
            item_id_val = str(row[0])
            if item_id_val in seen_ids:
                continue
            seen_ids.add(item_id_val)
            cards.append(
                SessionCard(
                    item_id=item_id_val,
                    item_type=item_type,
                    direction=_assign_direction(len(cards)),
                    is_new=True,
                )
            )

    if len(cards) >= count:
        return cards[:count]

    # -------------------------------------------------------------------
    # 3. Also pick UNSEEN items that have no progress record at all
    #    (items in the content table but not yet in the progress table)
    # -------------------------------------------------------------------
    unseen_no_record_limit = min(
        max(0, remaining_new_cap - sum(1 for c in cards if c["is_new"])),
        max(0, max_new_in_session - sum(1 for c in cards if c["is_new"])),
        count - len(cards),
    )

    if unseen_no_record_limit > 0:
        # Subquery: item IDs the user already has progress for
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
        fresh_rows = fresh_result.all()

        for row in fresh_rows:
            item_id_val = str(row[0])
            if item_id_val in seen_ids:
                continue
            seen_ids.add(item_id_val)
            cards.append(
                SessionCard(
                    item_id=item_id_val,
                    item_type=item_type,
                    direction=_assign_direction(len(cards)),
                    is_new=True,
                )
            )

    if len(cards) >= count:
        return cards[:count]

    # -------------------------------------------------------------------
    # 4. Fill remaining with preview cards (REVIEW not yet due)
    # -------------------------------------------------------------------
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
        preview_rows = preview_result.all()

        for row in preview_rows:
            item_id_val = str(row[0])
            if item_id_val in seen_ids:
                continue
            seen_ids.add(item_id_val)
            cards.append(
                SessionCard(
                    item_id=item_id_val,
                    item_type=item_type,
                    direction=_assign_direction(len(cards)),
                    is_new=False,
                )
            )

    return cards[:count]
