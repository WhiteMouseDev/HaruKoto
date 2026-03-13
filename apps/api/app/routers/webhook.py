from __future__ import annotations

import hashlib
import hmac
import time

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.models import Payment
from app.services.subscription import activate_subscription

router = APIRouter(prefix="/api/v1/webhook", tags=["webhook"])


@router.post("/portone")
async def portone_webhook(request: Request, db: AsyncSession = Depends(get_db)):
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

    data = await request.json()
    payment_id = data.get("data", {}).get("paymentId")
    if not payment_id:
        return {"ok": True}

    # Find payment
    result = await db.execute(select(Payment).where(Payment.portone_payment_id == payment_id))
    payment = result.scalar_one_or_none()
    if not payment or payment.status.value != "PENDING":
        return {"ok": True}  # Idempotent

    plan = payment.plan.value.lower() if hasattr(payment.plan, "value") else payment.plan.lower()
    await activate_subscription(db, str(payment.user_id), plan, payment_id, payment.amount)
    await db.commit()
    return {"ok": True}
