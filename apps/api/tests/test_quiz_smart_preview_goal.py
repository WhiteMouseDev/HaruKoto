from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

from app.models.enums import QuizType
from app.services import quiz_smart
from app.services.quiz_policy import calculate_smart_distribution
from app.utils.constants import DAILY_CATEGORY_GOALS_KEY


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
    counts = AsyncMock(return_value={QuizType.VOCABULARY: answered_count, QuizType.GRAMMAR: 99})
    distribution = Mock(wraps=calculate_smart_distribution)
    monkeypatch.setattr(quiz_smart, "get_today_kst", lambda: today)
    monkeypatch.setattr(quiz_smart, "load_smart_pool_stats", load_pool)
    monkeypatch.setattr(quiz_smart, "get_goal_answered_counts", counts)
    monkeypatch.setattr(quiz_smart, "calculate_smart_distribution", distribution)

    preview = await quiz_smart.build_smart_preview_data(db, user, category="VOCABULARY", jlpt_level="N4")

    assert preview.today_completed == answered_count
    assert preview.daily_goal == 10
    assert preview.pool_stats is pool
    load_pool.assert_awaited_once_with(db, user_id=user.id, category="VOCABULARY", jlpt_level="N4")
    counts.assert_awaited_once_with(db, user_id=user.id, day=today, quiz_type=QuizType.VOCABULARY)
    distribution.assert_called_once_with(remaining, 3, 1)
    if answered_count >= 10:
        # The existing distribution policy has a two-new-word floor even when
        # the remaining-goal input is clamped to one for extra study.
        assert preview.distribution == {"new": 2, "review": 0, "retry": 0}


@pytest.mark.asyncio
async def test_grammar_preview_uses_only_grammar_target_and_answer_count(monkeypatch: pytest.MonkeyPatch) -> None:
    today = date(2026, 10, 30)
    user = SimpleNamespace(id=uuid.uuid4(), daily_goal=20, app_settings={DAILY_CATEGORY_GOALS_KEY: {"grammar": 12}})
    db = SimpleNamespace()
    pool = quiz_smart.SmartPoolStats(total=50, studied=12, mastered=2, new_ready=38, review_due=6, retry_due=2)
    load_pool = AsyncMock(return_value=pool)
    counts = AsyncMock(return_value={QuizType.VOCABULARY: 18, QuizType.GRAMMAR: 3, QuizType.SENTENCE_ARRANGE: 10})
    distribution = Mock(wraps=calculate_smart_distribution)
    monkeypatch.setattr(quiz_smart, "get_today_kst", lambda: today)
    monkeypatch.setattr(quiz_smart, "load_smart_pool_stats", load_pool)
    monkeypatch.setattr(quiz_smart, "get_goal_answered_counts", counts)
    monkeypatch.setattr(quiz_smart, "calculate_smart_distribution", distribution)

    preview = await quiz_smart.build_smart_preview_data(db, user, category="GRAMMAR", jlpt_level="N3")

    assert preview.today_completed == 3
    assert preview.daily_goal == 12
    assert preview.pool_stats is pool
    load_pool.assert_awaited_once_with(db, user_id=user.id, category="GRAMMAR", jlpt_level="N3")
    counts.assert_awaited_once_with(db, user_id=user.id, day=today, quiz_type=QuizType.GRAMMAR)
    distribution.assert_called_once_with(9, 6, 2)
