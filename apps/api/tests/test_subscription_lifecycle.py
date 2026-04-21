import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.enums import SubscriptionStatus
from app.services.subscription_lifecycle import activate_subscription, cancel_subscription, resume_subscription


@pytest.mark.asyncio
async def test_activate_subscription_returns_existing_subscription_for_paid_payment():
    user_id = uuid.uuid4()
    subscription_id = uuid.uuid4()
    existing_payment = MagicMock(subscription_id=subscription_id)
    existing_subscription = MagicMock()

    payment_result = MagicMock()
    payment_result.scalar_one_or_none.return_value = existing_payment
    subscription_result = MagicMock()
    subscription_result.scalar_one_or_none.return_value = existing_subscription

    db = MagicMock()
    db.execute = AsyncMock(side_effect=[payment_result, subscription_result])
    db.flush = AsyncMock()

    result = await activate_subscription(db, user_id, "monthly", "payment-id", 9900)

    assert result is existing_subscription
    db.add.assert_not_called()
    db.flush.assert_not_awaited()


@pytest.mark.asyncio
async def test_cancel_subscription_raises_when_no_active_subscription():
    db = MagicMock()
    query_result = MagicMock()
    query_result.scalar_one_or_none.return_value = None
    db.execute = AsyncMock(return_value=query_result)

    with pytest.raises(ValueError, match="활성 구독이 없습니다."):
        await cancel_subscription(db, uuid.uuid4())


@pytest.mark.asyncio
async def test_resume_subscription_restores_cancelled_subscription():
    subscription = MagicMock()
    subscription.status = SubscriptionStatus.CANCELLED
    subscription.cancelled_at = MagicMock()
    subscription.cancel_reason = "reason"

    query_result = MagicMock()
    query_result.scalar_one_or_none.return_value = subscription
    db = MagicMock()
    db.execute = AsyncMock(return_value=query_result)
    db.flush = AsyncMock()

    result = await resume_subscription(db, uuid.uuid4())

    assert result is subscription
    assert subscription.status == SubscriptionStatus.ACTIVE
    assert subscription.cancelled_at is None
    assert subscription.cancel_reason is None
    db.flush.assert_awaited_once()
