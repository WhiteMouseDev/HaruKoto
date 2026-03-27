import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.db.session import get_db
from app.enums import SubscriptionStatus


@pytest.fixture
def cron_secret():
    return "test-cron-secret"


@pytest.mark.asyncio
@patch("app.routers.cron.settings")
async def test_subscription_expiry_processes_expired(mock_settings, client, mock_user, test_user_id, cron_secret):
    """Expired subscriptions are set to EXPIRED and users lose premium."""
    from app.main import app

    mock_settings.CRON_SECRET = cron_secret

    # Create mock expired subscription
    mock_sub = MagicMock()
    mock_sub.id = uuid.uuid4()
    mock_sub.user_id = test_user_id
    mock_sub.status = SubscriptionStatus.ACTIVE
    mock_sub.current_period_end = datetime.now(UTC) - timedelta(hours=1)

    mock_session = AsyncMock()

    # First execute: select expired subscriptions
    mock_select_result = MagicMock()
    mock_select_result.scalars.return_value.all.return_value = [mock_sub]

    # Second execute: update User
    mock_update_result = MagicMock()

    mock_session.execute = AsyncMock(side_effect=[mock_select_result, mock_update_result])
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/cron/subscription-renewal",
        headers={"authorization": f"Bearer {cron_secret}"},
    )
    assert response.status_code == 200
    assert response.json()["processed"] == 1
    assert mock_sub.status == SubscriptionStatus.EXPIRED


@pytest.mark.asyncio
@patch("app.routers.cron.settings")
async def test_subscription_expiry_no_expired(mock_settings, client, mock_user, cron_secret):
    """When no subscriptions are expired, returns processed=0."""
    from app.main import app

    mock_settings.CRON_SECRET = cron_secret

    mock_session = AsyncMock()
    mock_select_result = MagicMock()
    mock_select_result.scalars.return_value.all.return_value = []
    mock_session.execute = AsyncMock(return_value=mock_select_result)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/cron/subscription-renewal",
        headers={"authorization": f"Bearer {cron_secret}"},
    )
    assert response.status_code == 200
    assert response.json()["processed"] == 0


@pytest.mark.asyncio
@patch("app.routers.cron.settings")
async def test_subscription_renewal_unauthorized(mock_settings, client, mock_user, cron_secret):
    """Request without valid cron secret is rejected."""
    mock_settings.CRON_SECRET = cron_secret

    response = await client.post(
        "/api/v1/cron/subscription-renewal",
        headers={"authorization": "Bearer wrong-secret"},
    )
    assert response.status_code == 401
    assert response.json()["error"]["message"] == "Unauthorized"


@pytest.mark.asyncio
@patch("app.routers.cron.settings")
async def test_subscription_renewal_no_auth_header(mock_settings, client, mock_user, cron_secret):
    """Request without authorization header is rejected when secret is configured."""
    mock_settings.CRON_SECRET = cron_secret

    response = await client.post("/api/v1/cron/subscription-renewal")
    assert response.status_code == 401


@pytest.mark.asyncio
@patch("app.routers.cron.settings")
async def test_subscription_expiry_cancelled_also_expires(mock_settings, client, mock_user, test_user_id, cron_secret):
    """Cancelled subscriptions past period end are also expired."""
    from app.main import app

    mock_settings.CRON_SECRET = cron_secret

    mock_sub = MagicMock()
    mock_sub.id = uuid.uuid4()
    mock_sub.user_id = test_user_id
    mock_sub.status = SubscriptionStatus.CANCELLED
    mock_sub.current_period_end = datetime.now(UTC) - timedelta(days=1)

    mock_session = AsyncMock()
    mock_select_result = MagicMock()
    mock_select_result.scalars.return_value.all.return_value = [mock_sub]
    mock_update_result = MagicMock()
    mock_session.execute = AsyncMock(side_effect=[mock_select_result, mock_update_result])
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/cron/subscription-renewal",
        headers={"authorization": f"Bearer {cron_secret}"},
    )
    assert response.status_code == 200
    assert response.json()["processed"] == 1
    assert mock_sub.status == SubscriptionStatus.EXPIRED
