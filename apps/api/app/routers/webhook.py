from __future__ import annotations

import hashlib
import hmac
import logging
import time
from typing import Any, cast

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.models import Payment
from app.schemas.subscription import StoreNotificationAck, StoreNotificationRequest
from app.services.subscription import PlanSlug, activate_subscription
from app.utils.helpers import enum_value

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/webhook", tags=["webhook"])


@router.post("/portone", status_code=200)
async def portone_webhook(request: Request, db: AsyncSession = Depends(get_db)) -> dict[str, bool]:
    body = await request.body()
    signature = request.headers.get("x-portone-signature", "")
    timestamp = request.headers.get("x-portone-timestamp", "")

    # Verify HMAC signature
    if settings.PORTONE_WEBHOOK_SECRET:
        expected = hmac.new(
            settings.PORTONE_WEBHOOK_SECRET.encode(),
            f"{timestamp}.{body.decode()}".encode(),
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise HTTPException(status_code=401, detail="Invalid signature")

        # Check timestamp tolerance (60 seconds)
        try:
            ts = int(timestamp)
            if abs(time.time() - ts) > 60:
                raise HTTPException(status_code=401, detail="Timestamp expired")
        except ValueError as err:
            raise HTTPException(status_code=401, detail="Invalid timestamp") from err

    data = cast(dict[str, Any], await request.json())
    event_data = cast(dict[str, Any], data.get("data", {}))
    payment_id = event_data.get("paymentId")
    if not isinstance(payment_id, str) or not payment_id:
        logger.info("Webhook received without paymentId, skipping")
        return {"ok": True}

    logger.info("Webhook received", extra={"payment_id": payment_id})

    # Find payment
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
        return {"ok": True}  # Idempotent

    plan_value = enum_value(payment.plan).lower()
    if plan_value not in ("monthly", "yearly"):
        raise HTTPException(status_code=400, detail="유효하지 않은 플랜입니다")
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
    return {"ok": True}


@router.post("/apple/app-store-server", response_model=StoreNotificationAck, status_code=202)
async def apple_app_store_server_notification(body: StoreNotificationRequest) -> StoreNotificationAck:
    logger.info(
        "Apple App Store Server notification received",
        extra={"has_signed_payload": bool(body.signed_payload), "payload_size": len(body.signed_payload)},
    )
    return StoreNotificationAck(ok=True, accepted=True, source="apple")


@router.post("/google/play", response_model=StoreNotificationAck, status_code=202)
async def google_play_notification(body: StoreNotificationRequest) -> StoreNotificationAck:
    logger.info(
        "Google Play subscription notification received",
        extra={"has_signed_payload": bool(body.signed_payload), "payload_size": len(body.signed_payload)},
    )
    return StoreNotificationAck(ok=True, accepted=True, source="google")
