from __future__ import annotations

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.lesson import LessonItemLink
from app.models.progress import UserVocabProgress
from app.services.srs import process_answer, register_items_from_lesson


def _scalar_one_or_none_result(item: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = item
    return result


@pytest.mark.asyncio
async def test_register_items_from_lesson_creates_progress_with_python_side_defaults() -> None:
    user_id = uuid.uuid4()
    lesson_id = uuid.uuid4()
    vocabulary_id = uuid.uuid4()
    link = LessonItemLink(
        lesson_id=lesson_id,
        item_type="WORD",
        vocabulary_id=vocabulary_id,
        grammar_id=None,
        item_order=1,
    )
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_scalar_one_or_none_result(None))
    db.add = MagicMock()
    db.flush = AsyncMock()

    registered = await register_items_from_lesson(db, user_id, lesson_id, [link])

    assert registered == 1
    db.add.assert_called_once()
    created = db.add.call_args.args[0]
    assert isinstance(created, UserVocabProgress)
    assert created.user_id == user_id
    assert created.vocabulary_id == vocabulary_id
    assert created.state == "LEARNING"
    assert created.introduced_by == "LESSON"
    assert created.source_lesson_id == lesson_id
    assert created.correct_count == 0
    assert created.incorrect_count == 0
    assert created.fsrs_reps == 0
    assert created.jp_kr_total == 0
    assert created.guess_risk == 0
    assert created.created_at is not None
    assert created.updated_at == created.created_at
    assert created.next_review_at is not None
    db.flush.assert_awaited_once()


@pytest.mark.asyncio
async def test_process_answer_creates_missing_progress_before_srs_arithmetic() -> None:
    user_id = uuid.uuid4()
    item_id = uuid.uuid4()
    session_id = uuid.uuid4()
    lesson_id = uuid.uuid4()
    db = AsyncMock()
    db.execute = AsyncMock(side_effect=[_scalar_one_or_none_result(None), MagicMock()])
    db.add = MagicMock()
    db.flush = AsyncMock()

    result = await process_answer(
        db,
        user_id=user_id,
        item_type="WORD",
        item_id=item_id,
        is_correct=True,
        direction="JP_KR",
        response_ms=1200,
        session_id=session_id,
        lesson_id=lesson_id,
    )

    db.add.assert_called_once()
    created = db.add.call_args.args[0]
    assert isinstance(created, UserVocabProgress)
    assert created.user_id == user_id
    assert created.vocabulary_id == item_id
    assert created.state == "PROVISIONAL"
    assert created.introduced_by == "QUIZ"
    assert created.correct_count == 1
    assert created.incorrect_count == 0
    assert created.fsrs_reps == 1
    assert created.fsrs_lapses == 0
    assert created.jp_kr_total == 1
    assert created.jp_kr_correct == 1
    assert created.created_at is not None
    assert created.updated_at == created.last_reviewed_at
    assert result["state_before"] == "PROVISIONAL"
    assert result["state_after"] == "PROVISIONAL"
    db.flush.assert_awaited_once()
