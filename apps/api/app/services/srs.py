"""SRS (Spaced Repetition System) core service.

State machine: UNSEEN → PROVISIONAL → LEARNING → REVIEW → MASTERED
                                                   ↓
                                             RELEARNING → REVIEW

Scheduler version 1: SM-2 interval calculation.
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from typing import TypedDict, cast
from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import LessonItemLink
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.services.progress_defaults import new_progress_defaults
from app.services.srs_session_builder import SessionCard as SessionCard
from app.services.srs_session_builder import build_smart_session as build_smart_session
from app.services.srs_transition import (
    AGAIN,
    HARD,
    LEARNING,
    LEARNING_INTERVALS,
    PROVISIONAL,
    UNSEEN,
    apply_transition,
    calculate_rating,
)

type ProgressRecord = UserVocabProgress | UserGrammarProgress
type ProgressModel = type[UserVocabProgress] | type[UserGrammarProgress]

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
        now = datetime.now(UTC)
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
                progress.next_review_at = now + timedelta(days=LEARNING_INTERVALS[0])
                progress.updated_at = now
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
                next_review_at=now + timedelta(days=LEARNING_INTERVALS[0]),
                **new_progress_defaults(now),
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
    now = datetime.now(UTC)

    # If no progress record exists, create one (quiz tab first encounter)
    if progress is None:
        progress = model(
            id=uuid.uuid4(),
            user_id=user_id,
            **{fk_col: item_id},
            state=PROVISIONAL,
            introduced_by="QUIZ",
            learning_step=0,
            **new_progress_defaults(now),
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
    apply_transition(progress, is_correct, rating, now)

    # 4. Update directional stats
    _update_direction_stats(progress, direction, is_correct)

    # 5. Update common fields
    progress.last_reviewed_at = now
    progress.last_presented_on = now.date()
    progress.fsrs_last_rating = rating
    progress.fsrs_reps += 1
    progress.updated_at = now

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
