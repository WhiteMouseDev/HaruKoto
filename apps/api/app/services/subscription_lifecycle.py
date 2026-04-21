from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Payment, Subscription, User
from app.models.enums import PaymentStatus, SubscriptionPlan, SubscriptionStatus
from app.services.subscription import PlanSlug, get_subscription_period_end


async def activate_subscription(
    db: AsyncSession,
    user_id: uuid.UUID,
    plan: PlanSlug,
    portone_payment_id: str,
    amount: int,
    billing_key: str | None = None,
) -> Subscription:
    """구독 활성화 (멱등성 보장)."""
    # 멱등성: 이미 이 paymentId로 활성화된 결제가 있으면 기존 구독 반환
    result = await db.execute(
        select(Payment).where(
            Payment.portone_payment_id == portone_payment_id,
            Payment.user_id == user_id,
            Payment.status == PaymentStatus.PAID,
        )
    )
    existing_payment = result.scalar_one_or_none()

    if existing_payment and existing_payment.subscription_id:
        subscription_result = await db.execute(select(Subscription).where(Subscription.id == existing_payment.subscription_id))
        existing_sub = subscription_result.scalar_one_or_none()
        if existing_sub:
            return existing_sub

    now = datetime.now(tz=UTC)
    period_end = get_subscription_period_end(plan, now)

    # 기존 활성 구독 만료 처리
    await db.execute(
        update(Subscription)
        .where(
            Subscription.user_id == user_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
        .values(status=SubscriptionStatus.EXPIRED)
    )

    # 새 구독 생성
    subscription = Subscription(
        user_id=user_id,
        plan=SubscriptionPlan.MONTHLY if plan == "monthly" else SubscriptionPlan.YEARLY,
        status=SubscriptionStatus.ACTIVE,
        billing_key=billing_key,
        current_period_start=now,
        current_period_end=period_end,
    )
    db.add(subscription)
    await db.flush()

    # 결제 기록 업데이트 (checkout에서 PENDING으로 이미 생성됨)
    await db.execute(
        update(Payment)
        .where(
            Payment.portone_payment_id == portone_payment_id,
            Payment.user_id == user_id,
            Payment.status == PaymentStatus.PENDING,
        )
        .values(
            subscription_id=subscription.id,
            status=PaymentStatus.PAID,
            paid_at=now,
        )
    )

    # User isPremium 업데이트
    await db.execute(update(User).where(User.id == user_id).values(is_premium=True, subscription_expires_at=period_end))

    return subscription


async def cancel_subscription(
    db: AsyncSession,
    user_id: uuid.UUID,
    reason: str | None = None,
) -> Subscription:
    """구독 취소 (기간 만료 시 해지)."""
    result = await db.execute(
        select(Subscription)
        .where(
            Subscription.user_id == user_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.plan != SubscriptionPlan.FREE,
        )
        .order_by(Subscription.created_at.desc())
        .limit(1)
    )
    subscription = result.scalar_one_or_none()

    if not subscription:
        raise ValueError("활성 구독이 없습니다.")

    subscription.status = SubscriptionStatus.CANCELLED
    subscription.cancelled_at = datetime.now(tz=UTC)
    subscription.cancel_reason = reason
    await db.flush()

    return subscription


async def resume_subscription(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> Subscription:
    """취소 철회."""
    now = datetime.now(tz=UTC)
    result = await db.execute(
        select(Subscription)
        .where(
            Subscription.user_id == user_id,
            Subscription.status == SubscriptionStatus.CANCELLED,
            Subscription.current_period_end > now,
        )
        .order_by(Subscription.created_at.desc())
        .limit(1)
    )
    subscription = result.scalar_one_or_none()

    if not subscription:
        raise ValueError("취소된 구독이 없거나 이미 만료되었습니다.")

    subscription.status = SubscriptionStatus.ACTIVE
    subscription.cancelled_at = None
    subscription.cancel_reason = None
    await db.flush()

    return subscription
