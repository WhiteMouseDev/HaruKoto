from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.study_daily_goal import StudyDailyGoalServiceError, update_daily_goal_data


@pytest.mark.asyncio
async def test_update_daily_goal_data_persists_valid_goal() -> None:
    user = SimpleNamespace(daily_goal=10)
    db = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())

    result = await update_daily_goal_data(db, user, daily_goal=25)

    assert result.daily_goal == 25
    assert user.daily_goal == 25
    db.commit.assert_awaited_once()
    db.refresh.assert_awaited_once_with(user)


@pytest.mark.asyncio
@pytest.mark.parametrize("daily_goal", [4, 51])
async def test_update_daily_goal_data_rejects_out_of_range_goal(daily_goal: int) -> None:
    user = SimpleNamespace(daily_goal=10)
    db = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())

    with pytest.raises(StudyDailyGoalServiceError) as exc_info:
        await update_daily_goal_data(db, user, daily_goal=daily_goal)

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "dailyGoal must be between 5 and 50"
    assert user.daily_goal == 10
    db.commit.assert_not_awaited()
    db.refresh.assert_not_awaited()
