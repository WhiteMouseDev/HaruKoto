import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.enums import PaymentStatus, SubscriptionPlan
from app.services.subscription_payments import get_payment_history


@pytest.mark.asyncio
async def test_get_payment_history_formats_paginated_payments():
    user_id = uuid.uuid4()
    paid_at = datetime(2026, 4, 1, 12, 0, tzinfo=UTC)
    created_at = datetime(2026, 4, 1, 11, 30, tzinfo=UTC)
    payment = MagicMock(
        id=uuid.uuid4(),
        amount=9900,
        currency="KRW",
        status=PaymentStatus.PAID,
        plan=SubscriptionPlan.MONTHLY,
        paid_at=paid_at,
        created_at=created_at,
    )

    payments_result = MagicMock()
    payments_result.scalars.return_value.all.return_value = [payment]
    count_result = MagicMock()
    count_result.scalar_one.return_value = 11
    db = MagicMock()
    db.execute = AsyncMock(side_effect=[payments_result, count_result])

    result = await get_payment_history(db, str(user_id), page=2, page_size=10)

    assert result == {
        "payments": [
            {
                "id": str(payment.id),
                "amount": 9900,
                "currency": "KRW",
                "status": "paid",
                "plan": "monthly",
                "paidAt": paid_at.isoformat(),
                "createdAt": created_at.isoformat(),
            }
        ],
        "total": 11,
        "page": 2,
        "pageSize": 10,
        "totalPages": 2,
    }


@pytest.mark.asyncio
async def test_get_payment_history_returns_zero_pages_when_empty():
    user_id = uuid.uuid4()
    payments_result = MagicMock()
    payments_result.scalars.return_value.all.return_value = []
    count_result = MagicMock()
    count_result.scalar_one.return_value = 0
    db = MagicMock()
    db.execute = AsyncMock(side_effect=[payments_result, count_result])

    result = await get_payment_history(db, str(user_id), page=1, page_size=10)

    assert result == {
        "payments": [],
        "total": 0,
        "page": 1,
        "pageSize": 10,
        "totalPages": 0,
    }
