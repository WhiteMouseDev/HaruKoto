import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.db.session import get_db
from app.models import Payment
from app.models.enums import PaymentStatus, SubscriptionPlan


@pytest.mark.asyncio
@patch("app.routers.subscription.get_daily_ai_usage")
@patch("app.routers.subscription.get_subscription_status")
async def test_get_subscription_status_free(mock_get_status, mock_get_usage, client, mock_user):
    """Test GET /api/v1/subscription/status returns free tier status."""
    mock_get_status.return_value = {
        "is_premium": False,
        "plan": "FREE",
        "expires_at": None,
        "cancelled_at": None,
    }
    mock_get_usage.return_value = {
        "chat_count": 2,
        "chat_seconds": 120,
        "call_count": 0,
        "call_seconds": 0,
    }

    response = await client.get("/api/v1/subscription/status")
    assert response.status_code == 200

    data = response.json()
    assert data["subscription"]["isPremium"] is False
    assert data["subscription"]["plan"] == "FREE"
    assert data["aiUsage"]["chatCount"] == 2


@pytest.mark.asyncio
@patch("app.routers.subscription.verify_payment_amount")
@patch("app.routers.subscription.activate_subscription")
async def test_activate_subscription(mock_activate, mock_verify, client, mock_user, test_user_id):
    """Test POST /api/v1/subscription/activate verifies payment and activates subscription."""
    from app.main import app

    payment_id = "hk_monthly_abc12345_1700000000"

    mock_payment = MagicMock(spec=Payment)
    mock_payment.portone_payment_id = payment_id
    mock_payment.user_id = test_user_id
    mock_payment.amount = 9900
    mock_payment.plan = SubscriptionPlan.MONTHLY
    mock_payment.status = PaymentStatus.PENDING

    mock_verify.return_value = None  # no exception means success

    mock_subscription = MagicMock()
    mock_subscription.id = uuid.uuid4()
    mock_subscription.current_period_end = datetime(2026, 4, 11, 0, 0, 0, tzinfo=UTC)
    mock_activate.return_value = mock_subscription

    mock_session = AsyncMock()

    # execute: select Payment
    mock_payment_result = MagicMock()
    mock_payment_result.scalar_one_or_none.return_value = mock_payment

    mock_session.execute = AsyncMock(return_value=mock_payment_result)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/subscription/activate",
        json={"paymentId": payment_id},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["ok"] is True
    assert "subscriptionId" in data
    assert "currentPeriodEnd" in data


@pytest.mark.asyncio
@patch("app.routers.subscription.cancel_subscription")
async def test_cancel_subscription(mock_cancel, client, mock_user):
    """Test POST /api/v1/subscription/cancel cancels the active subscription."""
    mock_cancel.return_value = MagicMock()

    response = await client.post(
        "/api/v1/subscription/cancel",
        json={"reason": "더 이상 필요하지 않습니다"},
    )
    assert response.status_code == 200
    assert response.json()["ok"] is True


@pytest.mark.asyncio
@patch("app.routers.subscription.cancel_subscription")
async def test_cancel_subscription_no_active(mock_cancel, client, mock_user):
    """Test POST /api/v1/subscription/cancel returns 400 when no active subscription."""
    mock_cancel.side_effect = ValueError("활성 구독이 없습니다.")

    response = await client.post(
        "/api/v1/subscription/cancel",
        json={},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "활성 구독이 없습니다."


@pytest.mark.asyncio
@patch("app.routers.subscription.resume_subscription")
async def test_resume_subscription(mock_resume, client, mock_user):
    """Test POST /api/v1/subscription/resume reactivates a cancelled subscription."""
    mock_resume.return_value = MagicMock()

    response = await client.post("/api/v1/subscription/resume")
    assert response.status_code == 200
    assert response.json()["ok"] is True


@pytest.mark.asyncio
@patch("app.routers.subscription.resume_subscription")
async def test_resume_subscription_no_cancelled(mock_resume, client, mock_user):
    """Test POST /api/v1/subscription/resume returns 400 when no cancelled subscription."""
    mock_resume.side_effect = ValueError("취소된 구독이 없거나 이미 만료되었습니다.")

    response = await client.post("/api/v1/subscription/resume")
    assert response.status_code == 400
    assert response.json()["detail"] == "취소된 구독이 없거나 이미 만료되었습니다."
