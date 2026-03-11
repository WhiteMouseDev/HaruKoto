import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.db.session import get_db
from app.models import DailyMission


@pytest.fixture
def mock_daily_mission(test_user_id):
    mission = MagicMock(spec=DailyMission)
    mission.id = uuid.uuid4()
    mission.user_id = test_user_id
    mission.mission_type = "words_5"
    mission.target_count = 5
    mission.current_count = 0
    mission.is_completed = False
    mission.reward_claimed = False
    return mission


@pytest.mark.asyncio
async def test_get_today_missions(client, mock_user, test_user_id):
    """Test GET /api/v1/missions/today returns daily missions."""
    from app.main import app

    mock_session = AsyncMock()

    # First execute: select existing missions - return empty (will generate)
    mock_existing_result = MagicMock()
    mock_existing_result.scalars.return_value.all.return_value = []

    # After generation: flush + re-select missions
    mission1 = MagicMock()
    mission1.id = uuid.uuid4()
    mission1.user_id = test_user_id
    mission1.mission_type = "words_5"
    mission1.target_count = 5
    mission1.current_count = 0
    mission1.is_completed = False
    mission1.reward_claimed = False

    mission2 = MagicMock()
    mission2.id = uuid.uuid4()
    mission2.user_id = test_user_id
    mission2.mission_type = "quiz_1"
    mission2.target_count = 1
    mission2.current_count = 0
    mission2.is_completed = False
    mission2.reward_claimed = False

    mission3 = MagicMock()
    mission3.id = uuid.uuid4()
    mission3.user_id = test_user_id
    mission3.mission_type = "correct_10"
    mission3.target_count = 10
    mission3.current_count = 0
    mission3.is_completed = False
    mission3.reward_claimed = False

    mock_generated_result = MagicMock()
    mock_generated_result.scalars.return_value.all.return_value = [mission1, mission2, mission3]

    # DailyProgress select - no progress yet
    mock_dp_result = MagicMock()
    mock_dp_result.scalar_one_or_none.return_value = None

    mock_session.execute = AsyncMock(side_effect=[mock_existing_result, mock_generated_result, mock_dp_result])
    mock_session.add = MagicMock()
    mock_session.flush = AsyncMock()
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/missions/today")
    assert response.status_code == 200

    data = response.json()
    assert len(data) == 3
    assert all("missionType" in m for m in data)
    assert all("targetCount" in m for m in data)
    assert all("xpReward" in m for m in data)


@pytest.mark.asyncio
@patch("app.routers.missions.check_and_grant_achievements")
async def test_claim_mission_success(mock_achievements, client, mock_user, mock_daily_mission, test_user_id):
    """Test POST /api/v1/missions/claim successfully claims a completed mission reward."""
    from app.main import app

    mock_daily_mission.is_completed = True
    mock_daily_mission.reward_claimed = False
    mock_achievements.return_value = []

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_daily_mission)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/missions/claim",
        json={"missionId": str(mock_daily_mission.id)},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["xpReward"] == 15  # words_5 mission gives 15 XP
    assert "totalXp" in data
    assert "events" in data


@pytest.mark.asyncio
async def test_claim_mission_already_claimed(client, mock_user, mock_daily_mission, test_user_id):
    """Test POST /api/v1/missions/claim returns 400 for already claimed mission."""
    from app.main import app

    mock_daily_mission.is_completed = True
    mock_daily_mission.reward_claimed = True

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_daily_mission)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/missions/claim",
        json={"missionId": str(mock_daily_mission.id)},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "이미 보상을 받았습니다"


@pytest.mark.asyncio
async def test_claim_mission_not_completed(client, mock_user, mock_daily_mission, test_user_id):
    """Test POST /api/v1/missions/claim returns 400 for incomplete mission."""
    from app.main import app

    mock_daily_mission.is_completed = False
    mock_daily_mission.reward_claimed = False

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_daily_mission)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/missions/claim",
        json={"missionId": str(mock_daily_mission.id)},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "미션이 완료되지 않았습니다"
