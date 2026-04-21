from __future__ import annotations

import logging
import time
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

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
    StoreVerifyRequest,
    StoreVerifyResponse,
    SubscriptionInfo,
    SubscriptionStatusResponse,
)
from app.services.portone import verify_payment_amount
from app.services.subscription import (
    PlanSlug,
    activate_subscription,
    cancel_subscription,
    get_subscription_status,
    resume_subscription,
)
from app.services.subscription_ai_usage import get_daily_ai_usage
from app.utils.constants import AI_LIMITS, PRICES
from app.utils.helpers import enum_value

router = APIRouter(prefix="/api/v1/subscription", tags=["subscription"])


@router.get("/status", response_model=SubscriptionStatusResponse, status_code=200)
async def get_status(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SubscriptionStatusResponse:
    sub_status = await get_subscription_status(db, user.id)
    usage = await get_daily_ai_usage(db, user.id)
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


@router.post("/checkout", response_model=CheckoutResponse, status_code=200)
async def create_checkout(
    body: CheckoutRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> CheckoutResponse:
    plan_value = body.plan.lower()
    if plan_value == "monthly":
        plan: PlanSlug = "monthly"
    elif plan_value == "yearly":
        plan = "yearly"
    else:
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
    logger.info("Subscription checkout created", extra={"user_id": str(user.id), "payment_id": payment_id, "plan": plan, "amount": amount})

    return CheckoutResponse(
        payment_id=payment_id,
        store_id=settings.PORTONE_STORE_ID,
        channel_key=settings.PORTONE_CHANNEL_KEY,
        order_name=f"하루코토 {'월간' if plan == 'monthly' else '연간'} 프리미엄",
        total_amount=amount,
        currency="KRW",
        customer_id=str(user.id),
    )


@router.post("/activate", status_code=200)
async def activate(
    body: ActivateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, bool | str]:
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

    plan_value = enum_value(payment.plan).lower()
    if plan_value not in ("monthly", "yearly"):
        raise HTTPException(status_code=400, detail="유효하지 않은 플랜입니다")
    plan: PlanSlug = "monthly" if plan_value == "monthly" else "yearly"
    logger.info(
        "Subscription activation started",
        extra={
            "user_id": str(user.id),
            "payment_id": body.payment_id,
            "plan": plan,
            "amount": payment.amount,
        },
    )
    subscription = await activate_subscription(
        db,
        user.id,
        plan,
        body.payment_id,
        payment.amount,
    )
    await db.commit()
    logger.info(
        "Subscription activated",
        extra={
            "user_id": str(user.id),
            "subscription_id": str(subscription.id),
            "period_end": subscription.current_period_end.isoformat(),
        },
    )

    return {
        "ok": True,
        "subscriptionId": str(subscription.id),
        "currentPeriodEnd": subscription.current_period_end.isoformat(),
    }


@router.post("/store/verify", response_model=StoreVerifyResponse, status_code=202)
async def verify_store_purchase(
    body: StoreVerifyRequest,
    user: Annotated[User, Depends(get_current_user)],
) -> StoreVerifyResponse:
    logger.info(
        "Store verification requested",
        extra={
            "user_id": str(user.id),
            "platform": body.platform,
            "plan": body.plan,
            "product_id": body.product_id,
            "transaction_id": body.transaction_id,
            "original_transaction_id": body.original_transaction_id,
            "has_purchase_token": bool(body.purchase_token),
            "has_signed_payload": bool(body.signed_payload),
        },
    )

    # Scaffolding only:
    # - iOS: App Store Server API / signed transaction validation
    # - Android: Google Play Developer API purchase token validation
    return StoreVerifyResponse(
        ok=True,
        status="PENDING",
        grant_state="PENDING_VALIDATION",
        message="Store verification scaffolding is ready. External store validation is not wired yet.",
    )


@router.post("/cancel", status_code=200)
async def cancel(
    body: CancelRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, bool]:
    try:
        await cancel_subscription(db, user.id, body.reason)
        await db.commit()
        logger.info("Subscription cancelled", extra={"user_id": str(user.id), "reason": body.reason})
        return {"ok": True}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@router.post("/resume", status_code=200)
async def resume(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, bool]:
    try:
        await resume_subscription(db, user.id)
        await db.commit()
        logger.info("Subscription resumed", extra={"user_id": str(user.id)})
        return {"ok": True}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
