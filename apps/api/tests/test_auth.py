import pytest

from app.services.kakao_auth import KakaoIdTokenMissingError, KakaoTokenExchangeError


@pytest.mark.asyncio
async def test_kakao_token_exchange_success(client, monkeypatch):
    """Test Kakao authorization code exchange response contract."""

    async def fake_exchange(*, code: str, redirect_uri: str) -> str:
        assert code == "authorization-code"
        assert redirect_uri == "harukoto://oauth/kakao"
        return "id-token"

    monkeypatch.setattr("app.routers.auth.exchange_kakao_authorization_code", fake_exchange)

    response = await client.post(
        "/api/v1/auth/kakao/exchange",
        json={
            "code": "authorization-code",
            "redirect_uri": "harukoto://oauth/kakao",
        },
    )

    assert response.status_code == 200
    assert response.json() == {"id_token": "id-token"}


@pytest.mark.asyncio
async def test_kakao_token_exchange_failure_maps_to_unauthorized(client, monkeypatch):
    """Test failed Kakao exchange preserves existing error response."""

    async def fake_exchange(*, code: str, redirect_uri: str) -> str:
        raise KakaoTokenExchangeError

    monkeypatch.setattr("app.routers.auth.exchange_kakao_authorization_code", fake_exchange)

    response = await client.post(
        "/api/v1/auth/kakao/exchange",
        json={
            "code": "bad-code",
            "redirect_uri": "harukoto://oauth/kakao",
        },
    )

    assert response.status_code == 401
    assert response.json()["error"]["message"] == "카카오 토큰 교환에 실패했습니다."


@pytest.mark.asyncio
async def test_kakao_token_exchange_missing_id_token_maps_to_bad_request(client, monkeypatch):
    """Test missing Kakao id_token preserves existing error response."""

    async def fake_exchange(*, code: str, redirect_uri: str) -> str:
        raise KakaoIdTokenMissingError

    monkeypatch.setattr("app.routers.auth.exchange_kakao_authorization_code", fake_exchange)

    response = await client.post(
        "/api/v1/auth/kakao/exchange",
        json={
            "code": "authorization-code",
            "redirect_uri": "harukoto://oauth/kakao",
        },
    )

    assert response.status_code == 400
    assert response.json()["error"]["message"] == "id_token이 없습니다. OpenID Connect가 활성화되어 있는지 확인하세요."


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
