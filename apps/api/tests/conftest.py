import os
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock

# Set required env vars before any app imports
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost:5432/test")
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User


@pytest.fixture
def test_user_id():
    return uuid.UUID("00000000-0000-0000-0000-000000000001")


@pytest.fixture
def mock_user(test_user_id):
    user = User(
        id=test_user_id,
        email="test@example.com",
        nickname="테스터",
        jlpt_level="N5",
        daily_goal=10,
        experience_points=0,
        level=1,
        streak_count=0,
        longest_streak=0,
        is_premium=False,
        show_kana=False,
        onboarding_completed=True,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    return user


@pytest_asyncio.fixture
async def client(mock_user):
    from app.main import app

    async def override_get_current_user():
        return mock_user

    async def override_get_db():
        mock_session = AsyncMock()
        yield mock_session

    app.dependency_overrides[get_current_user] = override_get_current_user
    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac

    app.dependency_overrides.clear()
