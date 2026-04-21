from __future__ import annotations

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models import UserGrammarProgress, UserVocabProgress
from app.services import quiz_answer_progress
from app.services.quiz_answer_progress import update_grammar_answer_progress, update_vocab_answer_progress


def _scalar_one_or_none_result(item: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = item
    return result


@pytest.mark.asyncio
async def test_update_vocab_answer_progress_applies_srs_and_logs_review_event(monkeypatch: pytest.MonkeyPatch):
    user_id = uuid.uuid4()
    question_id = uuid.uuid4()
    session_id = uuid.uuid4()
    now = datetime(2026, 4, 21, 12, 0, tzinfo=UTC)
    progress = UserVocabProgress(
        user_id=user_id,
        vocabulary_id=question_id,
        correct_count=0,
        incorrect_count=0,
        streak=0,
        ease_factor=2.5,
        interval=0,
        mastered=False,
        state="UNSEEN",
        introduced_by=None,
        learning_step=0,
    )
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_scalar_one_or_none_result(progress))
    db.add = MagicMock()
    db.flush = AsyncMock()
    log_review_event = AsyncMock()
    monkeypatch.setattr(quiz_answer_progress, "log_review_event", log_review_event)

    await update_vocab_answer_progress(
        db,
        user_id=user_id,
        question_id=question_id,
        session_id=session_id,
        is_correct=True,
        time_spent_seconds=8,
        now=now,
    )

    assert progress.correct_count == 1
    assert progress.state == "PROVISIONAL"
    db.add.assert_not_called()
    db.flush.assert_not_awaited()
    log_review_event.assert_awaited_once()
    args = log_review_event.await_args.args
    assert args[2] == "WORD"
    assert args[3] == question_id
    assert args[4] == session_id
    assert args[8] == 8000
    assert args[10] == "UNSEEN"
    assert args[11] == "PROVISIONAL"
    assert args[13] is True
    assert args[14] is True


@pytest.mark.asyncio
async def test_update_grammar_answer_progress_creates_missing_record_and_logs(monkeypatch: pytest.MonkeyPatch):
    user_id = uuid.uuid4()
    question_id = uuid.uuid4()
    session_id = uuid.uuid4()
    now = datetime(2026, 4, 21, 12, 0, tzinfo=UTC)
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_scalar_one_or_none_result(None))
    db.add = MagicMock()
    db.flush = AsyncMock()
    log_review_event = AsyncMock()
    monkeypatch.setattr(quiz_answer_progress, "log_review_event", log_review_event)

    def fake_apply_srs_update(
        progress: UserVocabProgress | UserGrammarProgress, is_correct: bool, time_spent_seconds: int, now: datetime
    ) -> None:
        progress.state = "REVIEW"

    monkeypatch.setattr(quiz_answer_progress, "apply_srs_update", fake_apply_srs_update)

    await update_grammar_answer_progress(
        db,
        user_id=user_id,
        question_id=question_id,
        session_id=session_id,
        is_correct=False,
        time_spent_seconds=5,
        now=now,
    )

    db.add.assert_called_once()
    created = db.add.call_args.args[0]
    assert isinstance(created, UserGrammarProgress)
    assert created.user_id == user_id
    assert created.grammar_id == question_id
    db.flush.assert_awaited_once()
    log_review_event.assert_awaited_once()
    args = log_review_event.await_args.args
    assert args[2] == "GRAMMAR"
    assert args[3] == question_id
    assert args[7] is False
    assert args[9] == 1
    assert args[10] == "UNSEEN"
    assert args[11] == "REVIEW"
