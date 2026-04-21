import hashlib
import hmac
import json
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.enums import PaymentStatus, SubscriptionPlan
from app.services.portone_webhook import (
    PortoneWebhookError,
    extract_portone_payment_id,
    handle_portone_payment_event,
    verify_portone_signature,
)


def _signed_body(secret: str, timestamp: str, payment_id: str) -> tuple[bytes, str]:
    body = json.dumps({"data": {"paymentId": payment_id}}).encode()
    signature = hmac.new(secret.encode(), f"{timestamp}.{body.decode()}".encode(), hashlib.sha256).hexdigest()
    return body, signature


def test_verify_portone_signature_accepts_valid_signature():
    body, signature = _signed_body("secret", "100", "payment-id")

    verify_portone_signature(
        body=body,
        signature=signature,
        timestamp="100",
        secret="secret",
        now=120,
    )


def test_verify_portone_signature_rejects_invalid_signature():
    body, _ = _signed_body("secret", "100", "payment-id")

    with pytest.raises(PortoneWebhookError) as exc_info:
        verify_portone_signature(
            body=body,
            signature="invalid",
            timestamp="100",
            secret="secret",
            now=120,
        )

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "Invalid signature"


def test_verify_portone_signature_rejects_invalid_timestamp():
    body, signature = _signed_body("secret", "not-int", "payment-id")

    with pytest.raises(PortoneWebhookError) as exc_info:
        verify_portone_signature(
            body=body,
            signature=signature,
            timestamp="not-int",
            secret="secret",
            now=120,
        )

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "Invalid timestamp"


def test_extract_portone_payment_id_handles_missing_or_invalid_payloads():
    assert extract_portone_payment_id({"data": {"paymentId": "payment-id"}}) == "payment-id"
    assert extract_portone_payment_id({"data": {"paymentId": ""}}) is None
    assert extract_portone_payment_id({"data": {}}) is None
    assert extract_portone_payment_id([]) is None


@pytest.mark.asyncio
@patch("app.services.portone_webhook.activate_subscription")
async def test_handle_portone_payment_event_activates_pending_payment(mock_activate):
    payment_id = "payment-id"
    user_id = uuid.uuid4()
    payment = MagicMock(
        portone_payment_id=payment_id,
        user_id=user_id,
        amount=9900,
        plan=SubscriptionPlan.MONTHLY,
        status=PaymentStatus.PENDING,
    )
    query_result = MagicMock()
    query_result.scalar_one_or_none.return_value = payment
    db = MagicMock()
    db.execute = AsyncMock(return_value=query_result)
    db.commit = AsyncMock()

    await handle_portone_payment_event(db, payment_id)

    mock_activate.assert_awaited_once_with(db, user_id, "monthly", payment_id, 9900)
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
@patch("app.services.portone_webhook.activate_subscription")
async def test_handle_portone_payment_event_skips_non_pending_payment(mock_activate):
    payment = MagicMock(status=PaymentStatus.PAID)
    query_result = MagicMock()
    query_result.scalar_one_or_none.return_value = payment
    db = MagicMock()
    db.execute = AsyncMock(return_value=query_result)
    db.commit = AsyncMock()

    await handle_portone_payment_event(db, "payment-id")

    mock_activate.assert_not_awaited()
    db.commit.assert_not_awaited()
