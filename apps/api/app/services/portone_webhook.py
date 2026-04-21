from __future__ import annotations

import hashlib
import hmac
import logging
import time
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Payment
from app.services.subscription import PlanSlug
from app.services.subscription_lifecycle import activate_subscription
from app.utils.helpers import enum_value

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class PortoneWebhookError(Exception):
    status_code: int
    detail: str


def verify_portone_signature(
    *,
    body: bytes,
    signature: str,
    timestamp: str,
    secret: str,
    now: float | None = None,
    tolerance_seconds: int = 60,
) -> None:
    if not secret:
        return

    expected = hmac.new(
        secret.encode(),
        f"{timestamp}.{body.decode()}".encode(),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(signature, expected):
        raise PortoneWebhookError(status_code=401, detail="Invalid signature")

    try:
        timestamp_seconds = int(timestamp)
    except ValueError as err:
        raise PortoneWebhookError(status_code=401, detail="Invalid timestamp") from err

    current_time = now if now is not None else time.time()
    if abs(current_time - timestamp_seconds) > tolerance_seconds:
        raise PortoneWebhookError(status_code=401, detail="Timestamp expired")


def extract_portone_payment_id(payload: Any) -> str | None:
    if not isinstance(payload, dict):
        return None

    event_data = payload.get("data", {})
    if not isinstance(event_data, dict):
        return None

    payment_id = event_data.get("paymentId")
    return payment_id if isinstance(payment_id, str) and payment_id else None


async def handle_portone_payment_event(db: AsyncSession, payment_id: str) -> None:
    result = await db.execute(select(Payment).where(Payment.portone_payment_id == payment_id))
    payment = result.scalar_one_or_none()
    if not payment or payment.status.value != "PENDING":
        logger.info(
            "Webhook skipped (idempotent)",
            extra={
                "payment_id": payment_id,
                "status": payment.status.value if payment else "not_found",
            },
        )
        return

    plan_value = enum_value(payment.plan).lower()
    if plan_value not in ("monthly", "yearly"):
        raise PortoneWebhookError(status_code=400, detail="유효하지 않은 플랜입니다")
    plan: PlanSlug = "monthly" if plan_value == "monthly" else "yearly"

    logger.info(
        "Webhook activating subscription",
        extra={
            "payment_id": payment_id,
            "user_id": str(payment.user_id),
            "plan": plan,
            "amount": payment.amount,
        },
    )
    await activate_subscription(db, payment.user_id, plan, payment_id, payment.amount)
    await db.commit()
    logger.info("Webhook subscription activated", extra={"payment_id": payment_id, "user_id": str(payment.user_id)})
