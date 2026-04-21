from __future__ import annotations

import contextlib
import uuid
from datetime import datetime
from typing import Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import UserGrammarProgress, UserVocabProgress
from app.services.quiz_policy import apply_srs_update
from app.services.srs import log_review_event

type ProgressRecord = UserVocabProgress | UserGrammarProgress
type ReviewItemType = Literal["WORD", "GRAMMAR"]


async def update_vocab_answer_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    question_id: uuid.UUID,
    session_id: uuid.UUID,
    is_correct: bool,
    time_spent_seconds: int,
    now: datetime,
) -> None:
    result = await db.execute(
        select(UserVocabProgress).where(
            UserVocabProgress.user_id == user_id,
            UserVocabProgress.vocabulary_id == question_id,
        )
    )
    progress = result.scalar_one_or_none()

    if progress is None:
        progress = UserVocabProgress(
            user_id=user_id,
            vocabulary_id=question_id,
        )
        db.add(progress)
        await db.flush()

    await _apply_and_log_progress(
        db,
        progress=progress,
        user_id=user_id,
        question_id=question_id,
        session_id=session_id,
        item_type="WORD",
        is_correct=is_correct,
        time_spent_seconds=time_spent_seconds,
        now=now,
    )


async def update_grammar_answer_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    question_id: uuid.UUID,
    session_id: uuid.UUID,
    is_correct: bool,
    time_spent_seconds: int,
    now: datetime,
) -> None:
    result = await db.execute(
        select(UserGrammarProgress).where(
            UserGrammarProgress.user_id == user_id,
            UserGrammarProgress.grammar_id == question_id,
        )
    )
    progress = result.scalar_one_or_none()

    if progress is None:
        progress = UserGrammarProgress(
            user_id=user_id,
            grammar_id=question_id,
        )
        db.add(progress)
        await db.flush()

    await _apply_and_log_progress(
        db,
        progress=progress,
        user_id=user_id,
        question_id=question_id,
        session_id=session_id,
        item_type="GRAMMAR",
        is_correct=is_correct,
        time_spent_seconds=time_spent_seconds,
        now=now,
    )


async def _apply_and_log_progress(
    db: AsyncSession,
    *,
    progress: ProgressRecord,
    user_id: uuid.UUID,
    question_id: uuid.UUID,
    session_id: uuid.UUID,
    item_type: ReviewItemType,
    is_correct: bool,
    time_spent_seconds: int,
    now: datetime,
) -> None:
    state_before = _progress_state(progress)
    apply_srs_update(progress, is_correct, time_spent_seconds, now)

    with contextlib.suppress(Exception):
        await log_review_event(
            db,
            user_id,
            item_type,
            question_id,
            session_id,
            None,
            "JP_KR",
            is_correct,
            time_spent_seconds * 1000,
            3 if is_correct else 1,
            state_before,
            _progress_state(progress, default=state_before),
            None,
            _progress_state(progress, default="") == "PROVISIONAL",
            state_before == "UNSEEN",
            now.date(),
        )


def _progress_state(progress: ProgressRecord, *, default: str = "UNSEEN") -> str:
    return getattr(progress, "state", default) or default
