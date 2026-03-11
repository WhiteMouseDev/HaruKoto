from unittest.mock import AsyncMock, MagicMock

import pytest

from app.db.session import get_db


@pytest.mark.asyncio
async def test_get_profile(client, mock_user):
    """Test GET /api/v1/user/profile with mocked DB scalar results."""
    from app.main import app

    mock_session = AsyncMock()

    # Mock the 4 db.execute() calls in order:
    # 1) total_words  2) total_quizzes  3) total_study_days  4) achievement_rows
    mock_scalar_result_5 = MagicMock()
    mock_scalar_result_5.scalar_one.return_value = 5

    mock_scalar_result_3 = MagicMock()
    mock_scalar_result_3.scalar_one.return_value = 3

    mock_scalar_result_7 = MagicMock()
    mock_scalar_result_7.scalar_one.return_value = 7

    mock_achievement_result = MagicMock()
    mock_achievement_result.scalars.return_value.all.return_value = []

    mock_session.execute = AsyncMock(
        side_effect=[
            mock_scalar_result_5,
            mock_scalar_result_3,
            mock_scalar_result_7,
            mock_achievement_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/user/profile")
    assert response.status_code == 200

    data = response.json()
    assert data["profile"]["nickname"] == mock_user.nickname
    assert data["profile"]["email"] == mock_user.email
    assert data["stats"]["totalWordsStudied"] == 5
    assert data["stats"]["totalQuizzesCompleted"] == 3
    assert data["stats"]["totalStudyDays"] == 7
    assert data["stats"]["achievements"] == []


@pytest.mark.asyncio
async def test_update_avatar(client, mock_user):
    """Test PATCH /api/v1/user/avatar."""
    response = await client.patch(
        "/api/v1/user/avatar",
        json={"avatar_url": "https://example.com/avatar.png"},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["avatarUrl"] == "https://example.com/avatar.png"
    assert mock_user.avatar_url == "https://example.com/avatar.png"


@pytest.mark.asyncio
async def test_update_account_nickname(client, mock_user):
    """Test PATCH /api/v1/user/account with nickname."""
    response = await client.patch(
        "/api/v1/user/account",
        json={"nickname": "새닉네임"},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["nickname"] == "새닉네임"
    assert mock_user.nickname == "새닉네임"


@pytest.mark.asyncio
async def test_update_account_email(client, mock_user):
    """Test PATCH /api/v1/user/account with email."""
    response = await client.patch(
        "/api/v1/user/account",
        json={"email": "new@example.com"},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["email"] == "new@example.com"
    assert mock_user.email == "new@example.com"


@pytest.mark.asyncio
async def test_update_account_both_fields(client, mock_user):
    """Test PATCH /api/v1/user/account with both nickname and email."""
    response = await client.patch(
        "/api/v1/user/account",
        json={"nickname": "둘다변경", "email": "both@example.com"},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["nickname"] == "둘다변경"
    assert data["email"] == "both@example.com"
