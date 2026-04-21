from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.schemas.kana import KanaQuizCompleteRequest
from app.services import kana_quiz_complete
from app.services.kana_quiz_complete import (
    KanaQuizCompleteServiceError,
    calculate_kana_quiz_accuracy,
    complete_kana_quiz_session,
    resolve_kana_quiz_xp,
)
from app.utils.constants import KANA_REWARDS


def test_calculate_kana_quiz_accuracy_handles_empty_session():
    assert calculate_kana_quiz_accuracy(correct_count=0, total_questions=0) == 0


def test_calculate_kana_quiz_accuracy_rounds_percentage():
    assert calculate_kana_quiz_accuracy(correct_count=2, total_questions=3) == 67


def test_resolve_kana_quiz_xp_uses_perfect_reward_only_for_full_score():
    assert resolve_kana_quiz_xp(100) == KANA_REWARDS.QUIZ_PERFECT_XP
    assert resolve_kana_quiz_xp(99) == KANA_REWARDS.QUIZ_PASS_XP


@pytest.mark.asyncio
async def test_complete_kana_quiz_session_awards_progress_and_marks_completed(monkeypatch):
    user = SimpleNamespace(
        id=uuid.uuid4(),
        level=1,
        experience_points=80,
        last_study_date=None,
        streak_count=0,
        longest_streak=0,
    )
    session = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user.id,
        total_questions=4,
        correct_count=4,
        completed_at=None,
    )
    db = AsyncMock()
    db.get = AsyncMock(return_value=session)
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    achievement_context: dict[str, object] = {}

    async def fake_check_and_grant_achievements(db_arg, user_id, context):
        achievement_context.update(context)
        return [{"type": "level_up"}]

    monkeypatch.setattr(kana_quiz_complete, "get_today_kst", lambda: date(2026, 4, 21))
    monkeypatch.setattr(kana_quiz_complete, "check_and_grant_achievements", fake_check_and_grant_achievements)

    result = await complete_kana_quiz_session(
        db,
        user,
        KanaQuizCompleteRequest(session_id=session.id),
    )

    assert result.accuracy == 100
    assert result.xp_earned == KANA_REWARDS.QUIZ_PERFECT_XP
    assert result.level == 2
    assert result.events == [{"type": "level_up"}]
    assert user.experience_points == 100
    assert user.level == 2
    assert user.streak_count == 1
    assert user.longest_streak == 1
    assert session.completed_at is not None
    assert achievement_context == {
        "total_xp": 100,
        "new_level": 2,
        "old_level": 1,
        "streak_count": 1,
    }
    db.execute.assert_awaited_once()
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_complete_kana_quiz_session_uses_pass_reward_for_non_perfect(monkeypatch):
    user = SimpleNamespace(
        id=uuid.uuid4(),
        level=1,
        experience_points=0,
        last_study_date=None,
        streak_count=0,
        longest_streak=0,
    )
    session = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user.id,
        total_questions=4,
        correct_count=3,
        completed_at=None,
    )
    db = AsyncMock()
    db.get = AsyncMock(return_value=session)
    db.execute = AsyncMock()
    db.commit = AsyncMock()

    async def fake_check_and_grant_achievements(db_arg, user_id, context):
        return []

    monkeypatch.setattr(kana_quiz_complete, "get_today_kst", lambda: date(2026, 4, 21))
    monkeypatch.setattr(kana_quiz_complete, "check_and_grant_achievements", fake_check_and_grant_achievements)

    result = await complete_kana_quiz_session(
        db,
        user,
        KanaQuizCompleteRequest(session_id=session.id),
    )

    assert result.accuracy == 75
    assert result.xp_earned == KANA_REWARDS.QUIZ_PASS_XP


@pytest.mark.asyncio
async def test_complete_kana_quiz_session_rejects_missing_session():
    user = SimpleNamespace(id=uuid.uuid4())
    db = AsyncMock()
    db.get = AsyncMock(return_value=None)

    with pytest.raises(KanaQuizCompleteServiceError) as exc_info:
        await complete_kana_quiz_session(
            db,
            user,
            KanaQuizCompleteRequest(session_id=uuid.uuid4()),
        )

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "세션을 찾을 수 없습니다"
