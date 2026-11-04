from __future__ import annotations

from contextlib import nullcontext
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.study_daily_goal import StudyDailyGoalServiceError, update_daily_goal_data
from app.utils.constants import DAILY_CATEGORY_GOALS_KEY


@pytest.mark.asyncio
async def test_update_daily_goal_data_persists_valid_goal() -> None:
    user = SimpleNamespace(id="account", daily_goal=10, app_settings=None)
    db = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock(), no_autoflush=nullcontext(), scalar=AsyncMock(return_value=None))

    result = await update_daily_goal_data(db, user, daily_goal=25)

    assert result.daily_goal == 25
    assert user.daily_goal == 25
    db.commit.assert_awaited_once()
    assert db.refresh.await_count == 2


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


@pytest.mark.asyncio
async def test_category_goal_patch_persists_one_category(client, mock_user) -> None:
    from app.db.session import get_db
    from app.main import app

    async def override_get_db():
        yield SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock(), no_autoflush=nullcontext(), scalar=AsyncMock(return_value=None))

    app.dependency_overrides[get_db] = override_get_db
    mock_user.daily_goal = 65
    mock_user.app_settings = {"theme": "dark", DAILY_CATEGORY_GOALS_KEY: {"sentence": 15}}

    response = await client.patch("/api/v1/study/category-goal", json={"category": "GRAMMAR", "dailyGoal": 5})
    assert response.status_code == 200
    assert response.json() == {"dailyGoal": 5}
    assert mock_user.daily_goal == 65
    assert mock_user.app_settings == {"theme": "dark", DAILY_CATEGORY_GOALS_KEY: {"sentence": 15, "grammar": 5}}

    for payload in ({"category": "KANA", "dailyGoal": 5}, {"category": "SENTENCE", "dailyGoal": 4}):
        assert (await client.patch("/api/v1/study/category-goal", json=payload)).status_code == 422


@pytest.mark.asyncio
async def test_profile_settings_hide_preserve_and_reject_reserved_goal_state(client, mock_user) -> None:
    from app.db.session import get_db
    from app.main import app

    async def override_get_db():
        yield SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock(), no_autoflush=nullcontext())

    app.dependency_overrides[get_db] = override_get_db
    private = {"grammar": 15, "earnedByMonth": {"2026-11": [3]}}
    mock_user.app_settings = {"theme": "dark", DAILY_CATEGORY_GOALS_KEY: private}

    response = await client.patch("/api/v1/user/profile", json={"appSettings": {"theme": "light"}})
    assert response.status_code == 200
    assert response.json()["appSettings"] == {"theme": "light"}
    assert mock_user.app_settings == {"theme": "light", DAILY_CATEGORY_GOALS_KEY: private}

    forged = await client.patch("/api/v1/user/profile", json={"appSettings": {DAILY_CATEGORY_GOALS_KEY: False}})
    assert forged.status_code == 400
    assert mock_user.app_settings[DAILY_CATEGORY_GOALS_KEY] == private

    cleared = await client.patch("/api/v1/user/profile", json={"appSettings": None})
    assert cleared.status_code == 200 and cleared.json()["appSettings"] is None
    assert mock_user.app_settings == {DAILY_CATEGORY_GOALS_KEY: private}
