from __future__ import annotations

import uuid
from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.schemas.kana import KanaQuizCompleteRequest, KanaStageCompleteRequest
from app.schemas.quiz import QuizCompleteRequest
from app.services import conversation_rewards, kana_quiz_complete, kana_stage_complete, quiz_complete


@pytest.mark.asyncio
@pytest.mark.parametrize("activity", ["quiz", "kana-stage", "kana-quiz", "conversation"])
@pytest.mark.parametrize(
    ("last_study", "now", "expected_streak"),
    [
        (datetime(2026, 9, 28, 15, 30, tzinfo=UTC), datetime(2026, 9, 28, 16, tzinfo=UTC), 4),
        (datetime(2026, 9, 27, 23, tzinfo=UTC), datetime(2026, 9, 28, 23, tzinfo=UTC), 5),
        (datetime(2026, 9, 28, 14, 59, tzinfo=UTC), datetime(2026, 9, 28, 15, tzinfo=UTC), 5),
    ],
    ids=["same-kst-day", "consecutive-kst-mornings", "kst-midnight"],
)
async def test_completion_paths_share_kst_streak_days(monkeypatch, activity, last_study, now, expected_streak):
    """Exercise actual completion writers without touching a database or learning records."""

    class FrozenDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return now.astimezone(tz) if tz is not None else now.replace(tzinfo=None)

    user = SimpleNamespace(
        id=uuid.uuid4(),
        level=1,
        experience_points=0,
        last_study_date=last_study,
        streak_count=4,
        longest_streak=9,
        show_kana=True,
    )
    db = AsyncMock()
    db.add = MagicMock()
    modules = {
        "quiz": quiz_complete,
        "kana-stage": kana_stage_complete,
        "kana-quiz": kana_quiz_complete,
        "conversation": conversation_rewards,
    }
    module = modules[activity]
    monkeypatch.setattr(module, "get_today_kst", lambda: date(2026, 9, 29))

    if activity == "quiz":
        monkeypatch.setattr(module, "datetime", FrozenDatetime)
        question_id = uuid.uuid4()
        session = SimpleNamespace(
            id=uuid.uuid4(),
            user_id=user.id,
            total_questions=1,
            correct_count=0,
            completed_at=None,
            started_at=now,
            questions_data=[{"id": str(question_id)}],
        )
        db.get.return_value = session
        answers = MagicMock()
        answers.all.return_value = [(question_id, True)]
        db.execute.return_value = answers
        monkeypatch.setattr(module, "_update_daily_progress", AsyncMock())
        monkeypatch.setattr(module, "_build_achievement_events", AsyncMock(return_value=[]))
        monkeypatch.setattr(module, "_update_stage_progress", AsyncMock())

        await quiz_complete.complete_quiz_session(db, user, QuizCompleteRequest(session_id=session.id))
        db.commit.assert_awaited_once()
    elif activity == "kana-stage":
        monkeypatch.setattr(module, "datetime", FrozenDatetime)
        stage = SimpleNamespace(id=uuid.uuid4())
        db.get.return_value = stage
        monkeypatch.setattr(module, "mark_kana_stage_complete", AsyncMock())
        monkeypatch.setattr(module, "unlock_next_kana_stage", AsyncMock(return_value=False))
        monkeypatch.setattr(module, "apply_daily_progress_increment", AsyncMock())
        monkeypatch.setattr(
            module,
            "get_kana_completion_status",
            AsyncMock(return_value=kana_stage_complete.KanaCompletionStatus(46, 0, 46, 0)),
        )
        monkeypatch.setattr(module, "grant_kana_stage_achievements", AsyncMock(return_value=[]))

        await kana_stage_complete.complete_kana_stage(db, user, KanaStageCompleteRequest(stage_id=stage.id))
        db.commit.assert_awaited_once()
    elif activity == "kana-quiz":
        monkeypatch.setattr(module, "datetime", FrozenDatetime)
        session = SimpleNamespace(id=uuid.uuid4(), user_id=user.id, total_questions=1, correct_count=1)
        db.get.return_value = session
        monkeypatch.setattr(module, "apply_daily_progress_increment", AsyncMock())
        monkeypatch.setattr(module, "grant_kana_quiz_achievements", AsyncMock(return_value=[]))

        await kana_quiz_complete.complete_kana_quiz_session(db, user, KanaQuizCompleteRequest(session_id=session.id))
        db.commit.assert_awaited_once()
    else:
        monkeypatch.setattr(module, "_update_daily_conversation_progress", AsyncMock())
        monkeypatch.setattr(module, "_count_completed_conversations", AsyncMock(return_value=1))
        monkeypatch.setattr(module, "track_ai_usage", AsyncMock())
        monkeypatch.setattr(module, "check_and_grant_achievements", AsyncMock(return_value=[]))

        await conversation_rewards.grant_conversation_completion_rewards(db, user, now=now, duration_seconds=60, usage_type="chat")

    assert user.streak_count == expected_streak
    assert user.longest_streak == 9
    assert user.last_study_date == now
