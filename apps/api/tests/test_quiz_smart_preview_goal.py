from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

from app.schemas.stats import VocabularyGoal
from app.services import quiz_smart
from app.services.quiz_policy import calculate_smart_distribution


@pytest.mark.asyncio
@pytest.mark.parametrize(("answered_count", "remaining"), [(0, 10), (4, 6), (10, 1), (15, 1)])
async def test_vocabulary_preview_uses_shared_daily_word_count_and_preserves_distribution(
    monkeypatch: pytest.MonkeyPatch, answered_count: int, remaining: int
) -> None:
    today = date(2026, 10, 30)
    user = SimpleNamespace(id=uuid.uuid4(), daily_goal=10)
    db = SimpleNamespace()
    pool = quiz_smart.SmartPoolStats(total=12, studied=5, mastered=2, new_ready=7, review_due=3, retry_due=1)
    load_pool = AsyncMock(return_value=pool)
    vocabulary_goal = AsyncMock(return_value=VocabularyGoal(date=today, answered_count=answered_count))
    legacy_count = AsyncMock(return_value=99)
    distribution = Mock(wraps=calculate_smart_distribution)
    monkeypatch.setattr(quiz_smart, "get_today_kst", lambda: today)
    monkeypatch.setattr(quiz_smart, "load_smart_pool_stats", load_pool)
    monkeypatch.setattr(quiz_smart, "get_vocabulary_goal", vocabulary_goal, raising=False)
    monkeypatch.setattr(quiz_smart, "load_today_completed_count", legacy_count)
    monkeypatch.setattr(quiz_smart, "calculate_smart_distribution", distribution)

    preview = await quiz_smart.build_smart_preview_data(db, user, category="VOCABULARY", jlpt_level="N4")

    assert preview.today_completed == answered_count
    assert preview.daily_goal == 10
    assert preview.pool_stats is pool
    load_pool.assert_awaited_once_with(db, user_id=user.id, category="VOCABULARY", jlpt_level="N4")
    vocabulary_goal.assert_awaited_once_with(db, user_id=user.id, day=today)
    legacy_count.assert_not_awaited()
    distribution.assert_called_once_with(remaining, 3, 1)
    if answered_count >= 10:
        # The existing distribution policy has a two-new-word floor even when
        # the remaining-goal input is clamped to one for extra study.
        assert preview.distribution == {"new": 2, "review": 0, "retry": 0}


@pytest.mark.asyncio
async def test_grammar_preview_preserves_legacy_count_pool_and_distribution(monkeypatch: pytest.MonkeyPatch) -> None:
    user = SimpleNamespace(id=uuid.uuid4(), daily_goal=20)
    db = SimpleNamespace()
    pool = quiz_smart.SmartPoolStats(total=50, studied=12, mastered=2, new_ready=38, review_due=6, retry_due=2)
    load_pool = AsyncMock(return_value=pool)
    vocabulary_goal = AsyncMock(return_value=VocabularyGoal(date=date(2026, 10, 30), answered_count=0))
    legacy_count = AsyncMock(return_value=7)
    distribution = Mock(wraps=calculate_smart_distribution)
    monkeypatch.setattr(quiz_smart, "load_smart_pool_stats", load_pool)
    monkeypatch.setattr(quiz_smart, "get_vocabulary_goal", vocabulary_goal, raising=False)
    monkeypatch.setattr(quiz_smart, "load_today_completed_count", legacy_count)
    monkeypatch.setattr(quiz_smart, "calculate_smart_distribution", distribution)

    preview = await quiz_smart.build_smart_preview_data(db, user, category="GRAMMAR", jlpt_level="N3")

    assert preview.today_completed == 7
    assert preview.daily_goal == 20
    assert preview.pool_stats is pool
    assert preview.distribution == {"new": 5, "review": 6, "retry": 2}
    load_pool.assert_awaited_once_with(db, user_id=user.id, category="GRAMMAR", jlpt_level="N3")
    legacy_count.assert_awaited_once_with(db, user_id=user.id)
    vocabulary_goal.assert_not_awaited()
    distribution.assert_called_once_with(13, 6, 2)


@pytest.mark.asyncio
async def test_grammar_legacy_count_query_is_unchanged(monkeypatch: pytest.MonkeyPatch) -> None:
    today = date(2026, 10, 30)
    user_id = uuid.uuid4()
    db = SimpleNamespace(execute=AsyncMock(return_value=SimpleNamespace(scalar=lambda: 7)))
    monkeypatch.setattr(quiz_smart, "get_today_kst", lambda: today)

    assert await quiz_smart.load_today_completed_count(db, user_id=user_id) == 7

    query = db.execute.await_args.args[0]
    assert " ".join(str(query).split()) == (
        "SELECT count(quiz_answers.id) AS count_1 FROM quiz_answers "
        "JOIN quiz_sessions ON quiz_sessions.id = quiz_answers.session_id "
        "WHERE quiz_sessions.user_id = :user_id_1 AND quiz_answers.answered_at >= :answered_at_1"
    )
    assert query.compile().params == {"user_id_1": user_id, "answered_at_1": today}
