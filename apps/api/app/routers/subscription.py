from __future__ import annotations

import time
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import Payment
from app.models.user import User
from app.schemas.subscription import (
    ActivateRequest,
    AiUsageInfo,
    CancelRequest,
    CheckoutRequest,
    CheckoutResponse,
    SubscriptionInfo,
    SubscriptionStatusResponse,
)
from app.services.portone import verify_payment_amount
from app.services.subscription import (
    activate_subscription,
    cancel_subscription,
    get_daily_ai_usage,
    get_subscription_status,
    resume_subscription,
)
from app.utils.constants import AI_LIMITS, PRICES

router = APIRouter(prefix="/api/v1/subscription", tags=["subscription"])


@router.get("/status", response_model=SubscriptionStatusResponse)
async def get_status(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    sub_status = await get_subscription_status(db, str(user.id))
    usage = await get_daily_ai_usage(db, str(user.id))
    limits = AI_LIMITS.PREMIUM if sub_status["is_premium"] else AI_LIMITS.FREE

    return SubscriptionStatusResponse(
        subscription=SubscriptionInfo(
            is_premium=sub_status["is_premium"],
            plan=sub_status["plan"],
            expires_at=sub_status["expires_at"],
            cancelled_at=sub_status["cancelled_at"],
        ),
        ai_usage=AiUsageInfo(
            chat_count=usage["chat_count"],
            call_count=usage["call_count"],
            chat_seconds=usage["chat_seconds"],
            call_seconds=usage["call_seconds"],
            chat_limit=limits.CHAT_COUNT,
            call_limit=limits.CALL_COUNT,
            chat_seconds_limit=limits.CHAT_SECONDS,
            call_seconds_limit=limits.CALL_SECONDS,
        ),
    )


@router.post("/checkout", response_model=CheckoutResponse)
async def create_checkout(
    body: CheckoutRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    plan = body.plan.lower()
    if plan not in ("monthly", "yearly"):
        raise HTTPException(status_code=400, detail="유효하지 않은 플랜입니다")

    amount = PRICES.MONTHLY if plan == "monthly" else PRICES.YEARLY
    short_id = uuid.uuid4().hex[:8]
    payment_id = f"hk_{plan}_{short_id}_{int(time.time())}"

    payment = Payment(
        user_id=user.id,
        portone_payment_id=payment_id,
        amount=amount,
        plan=plan.upper(),
        status="PENDING",
    )
    db.add(payment)
    await db.commit()

    return CheckoutResponse(
        payment_id=payment_id,
        store_id=settings.PORTONE_STORE_ID,
        channel_key=settings.PORTONE_CHANNEL_KEY,
        order_name=f"하루코토 {'월간' if plan == 'monthly' else '연간'} 프리미엄",
        total_amount=amount,
        currency="KRW",
        customer_id=str(user.id),
    )


@router.post("/activate")
async def activate(
    body: ActivateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from sqlalchemy import select

    result = await db.execute(
        select(Payment).where(
            Payment.portone_payment_id == body.payment_id,
            Payment.user_id == user.id,
        )
    )
    payment = result.scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="결제 정보를 찾을 수 없습니다")

    try:
        await verify_payment_amount(body.payment_id, payment.amount)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    plan = payment.plan.value.lower() if hasattr(payment.plan, "value") else payment.plan.lower()
    subscription = await activate_subscription(
        db,
        str(user.id),
        plan,
        body.payment_id,
        payment.amount,
    )
    await db.commit()

    return {
        "success": True,
        "subscriptionId": str(subscription.id),
        "currentPeriodEnd": subscription.current_period_end.isoformat(),
    }


@router.post("/cancel")
async def cancel(
    body: CancelRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await cancel_subscription(db, str(user.id), body.reason)
        await db.commit()
        return {"success": True}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@router.post("/resume")
async def resume(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        await resume_subscription(db, str(user.id))
        await db.commit()
        return {"success": True}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
