import pytest


@pytest.mark.asyncio
async def test_onboarding_success(client, mock_user):
    """Test successful onboarding with all fields."""
    response = await client.post(
        "/api/v1/auth/onboarding",
        json={
            "nickname": "하루학생",
            "jlptLevel": "N4",
            "dailyGoal": 15,
            "goal": "JLPT_N3",
        },
    )
    assert response.status_code == 200

    data = response.json()
    assert "profile" in data

    # Verify the user object was mutated by the handler
    assert mock_user.nickname == "하루학생"
    assert mock_user.jlpt_level == "N4"
    assert mock_user.daily_goal == 15
    assert mock_user.onboarding_completed is True
    assert mock_user.goal == "JLPT_N3"


@pytest.mark.asyncio
async def test_onboarding_without_goal(client, mock_user):
    """Test onboarding with optional goal field omitted."""
    original_goal = mock_user.goal

    response = await client.post(
        "/api/v1/auth/onboarding",
        json={
            "nickname": "테스트유저",
            "jlptLevel": "N5",
            "dailyGoal": 10,
        },
    )
    assert response.status_code == 200

    data = response.json()
    assert "profile" in data

    assert mock_user.nickname == "테스트유저"
    assert mock_user.jlpt_level == "N5"
    assert mock_user.daily_goal == 10
    # goal should remain unchanged when not provided
    assert mock_user.goal == original_goal
