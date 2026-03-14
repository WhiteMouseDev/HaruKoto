import hashlib
import hmac
import json
import time
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.db.session import get_db
from app.enums import PaymentStatus, SubscriptionPlan


@pytest.fixture
def webhook_secret():
    return "test-webhook-secret"


@pytest.fixture
def make_webhook_request(webhook_secret):
    """Helper to build a signed webhook request body + headers."""

    def _make(payment_id: str, timestamp: int | None = None):
        ts = str(timestamp or int(time.time()))
        body = json.dumps({"data": {"paymentId": payment_id}})
        signature = hmac.new(
            webhook_secret.encode(),
            f"{ts}.{body}".encode(),
            hashlib.sha256,
        ).hexdigest()
        headers = {
            "x-portone-signature": signature,
            "x-portone-timestamp": ts,
            "content-type": "application/json",
        }
        return body, headers

    return _make


@pytest.mark.asyncio
@patch("app.routers.webhook.activate_subscription")
@patch("app.routers.webhook.settings")
async def test_valid_webhook_activates_subscription(
    mock_settings, mock_activate, client, mock_user, test_user_id, webhook_secret, make_webhook_request
):
    """Valid webhook with correct HMAC signature activates a pending payment."""
    from app.main import app

    mock_settings.PORTONE_WEBHOOK_SECRET = webhook_secret

    payment_id = "pay_abc123"
    body_str, headers = make_webhook_request(payment_id)

    mock_payment = MagicMock()
    mock_payment.portone_payment_id = payment_id
    mock_payment.user_id = test_user_id
    mock_payment.amount = 9900
    mock_payment.plan = SubscriptionPlan.MONTHLY
    mock_payment.status = PaymentStatus.PENDING

    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_payment
    mock_session.execute = AsyncMock(return_value=mock_result)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/webhook/portone",
        content=body_str,
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["ok"] is True
    mock_activate.assert_awaited_once()


@pytest.mark.asyncio
@patch("app.routers.webhook.settings")
async def test_expired_timestamp_rejected(mock_settings, client, mock_user, webhook_secret, make_webhook_request):
    """Webhook with timestamp older than 60 seconds is rejected."""
    mock_settings.PORTONE_WEBHOOK_SECRET = webhook_secret

    old_ts = int(time.time()) - 120  # 2 minutes ago
    body_str, headers = make_webhook_request("pay_xyz", timestamp=old_ts)

    response = await client.post(
        "/api/v1/webhook/portone",
        content=body_str,
        headers=headers,
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Timestamp expired"


@pytest.mark.asyncio
@patch("app.routers.webhook.settings")
async def test_already_processed_payment_is_idempotent(
    mock_settings, client, mock_user, test_user_id, webhook_secret, make_webhook_request
):
    """Already processed (non-PENDING) payment returns ok without re-activating."""
    from app.main import app

    mock_settings.PORTONE_WEBHOOK_SECRET = webhook_secret

    payment_id = "pay_already_done"
    body_str, headers = make_webhook_request(payment_id)

    mock_payment = MagicMock()
    mock_payment.portone_payment_id = payment_id
    mock_payment.user_id = test_user_id
    mock_payment.amount = 9900
    mock_payment.plan = SubscriptionPlan.MONTHLY
    mock_payment.status = PaymentStatus.PAID  # Already processed

    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_payment
    mock_session.execute = AsyncMock(return_value=mock_result)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/webhook/portone",
        content=body_str,
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["ok"] is True


@pytest.mark.asyncio
@patch("app.routers.webhook.settings")
async def test_invalid_signature_rejected(mock_settings, client, mock_user, webhook_secret):
    """Webhook with wrong HMAC signature is rejected."""
    mock_settings.PORTONE_WEBHOOK_SECRET = webhook_secret

    body_str = json.dumps({"data": {"paymentId": "pay_bad"}})
    headers = {
        "x-portone-signature": "invalid-signature",
        "x-portone-timestamp": str(int(time.time())),
        "content-type": "application/json",
    }

    response = await client.post(
        "/api/v1/webhook/portone",
        content=body_str,
        headers=headers,
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid signature"


@pytest.mark.asyncio
@patch("app.routers.webhook.settings")
async def test_payment_not_found_is_idempotent(mock_settings, client, mock_user, webhook_secret, make_webhook_request):
    """Webhook for non-existent payment returns ok (idempotent)."""
    from app.main import app

    mock_settings.PORTONE_WEBHOOK_SECRET = webhook_secret

    payment_id = "pay_not_found"
    body_str, headers = make_webhook_request(payment_id)

    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None  # Not found
    mock_session.execute = AsyncMock(return_value=mock_result)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/webhook/portone",
        content=body_str,
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["ok"] is True
