from __future__ import annotations

import math
import uuid
from datetime import UTC, date, datetime
from typing import Literal

from dateutil.relativedelta import relativedelta
from sqlalchemy import func, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import DailyAiUsage, Payment, Subscription, User
from app.models.enums import PaymentStatus, SubscriptionPlan, SubscriptionStatus
from app.utils.constants import AI_LIMITS


def _ensure_aware(dt: datetime) -> datetime:
    """offset-naive datetime을 UTC로 간주하여 aware로 변환."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


# ==========================================
# 구독 기간 계산
# ==========================================


def get_subscription_period_end(
    plan: Literal["monthly", "yearly"],
    from_date: datetime | None = None,
) -> datetime:
    """구독 기간 종료일 계산."""
    base = from_date or datetime.now(tz=UTC)
    if plan == "monthly":
        return base + relativedelta(months=1)
    return base + relativedelta(years=1)


# ==========================================
# 구독 상태 조회
# ==========================================


async def get_subscription_status(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """활성/취소 구독 조회 및 프리미엄 여부 반환."""
    result = await db.execute(
        select(Subscription)
        .where(
            Subscription.user_id == user_id,
            Subscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.CANCELLED]),
        )
        .order_by(Subscription.created_at.desc())
        .limit(1)
    )
    subscription = result.scalar_one_or_none()

    now = datetime.now(tz=UTC)
    is_premium = (
        subscription is not None
        and subscription.plan != SubscriptionPlan.FREE
        and subscription.status in (SubscriptionStatus.ACTIVE, SubscriptionStatus.CANCELLED)
        and _ensure_aware(subscription.current_period_end) > now
    )

    plan = subscription.plan if subscription else SubscriptionPlan.FREE

    return {
        "is_premium": is_premium,
        "plan": plan,
        "expires_at": subscription.current_period_end.isoformat() if subscription and subscription.current_period_end else None,
        "cancelled_at": subscription.cancelled_at.isoformat() if subscription and subscription.cancelled_at else None,
        "subscription": subscription,
    }


# ==========================================
# AI 사용량
# ==========================================


async def get_daily_ai_usage(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """오늘 AI 사용량 조회."""
    today = date.today()

    result = await db.execute(
        select(DailyAiUsage).where(
            DailyAiUsage.user_id == user_id,
            DailyAiUsage.date == today,
        )
    )
    usage = result.scalar_one_or_none()

    return {
        "chat_count": usage.chat_count if usage else 0,
        "chat_seconds": usage.chat_seconds if usage else 0,
        "call_count": usage.call_count if usage else 0,
        "call_seconds": usage.call_seconds if usage else 0,
    }


async def check_ai_limit(
    db: AsyncSession,
    user_id: uuid.UUID,
    usage_type: Literal["chat", "call"],
) -> dict:
    """AI 사용 제한 체크."""
    status = await get_subscription_status(db, user_id)
    limits = AI_LIMITS.PREMIUM if status["is_premium"] else AI_LIMITS.FREE
    usage = await get_daily_ai_usage(db, user_id)

    if usage_type == "chat":
        if usage["chat_count"] >= limits.CHAT_COUNT:
            return {"allowed": False, "reason": "오늘의 AI 채팅 횟수를 초과했습니다."}
        if usage["chat_seconds"] >= limits.CHAT_SECONDS:
            return {"allowed": False, "reason": "오늘의 AI 채팅 시간을 초과했습니다."}
    else:
        if usage["call_count"] >= limits.CALL_COUNT:
            return {"allowed": False, "reason": "오늘의 AI 통화 횟수를 초과했습니다."}
        if usage["call_seconds"] >= limits.CALL_SECONDS:
            return {"allowed": False, "reason": "오늘의 AI 통화 시간을 초과했습니다."}

    return {"allowed": True}


async def track_ai_usage(
    db: AsyncSession,
    user_id: uuid.UUID,
    usage_type: Literal["chat", "call"],
    duration_seconds: int,
) -> None:
    """AI 사용량 기록 (upsert)."""
    today = date.today()
    count_field = "chat_count" if usage_type == "chat" else "call_count"
    seconds_field = "chat_seconds" if usage_type == "chat" else "call_seconds"

    stmt = insert(DailyAiUsage).values(
        user_id=user_id,
        date=today,
        **{count_field: 1, seconds_field: duration_seconds},
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_={
            count_field: getattr(DailyAiUsage, count_field) + 1,
            seconds_field: getattr(DailyAiUsage, seconds_field) + duration_seconds,
        },
    )
    await db.execute(stmt)
    await db.flush()


# ==========================================
# 구독 관리
# ==========================================


async def activate_subscription(
    db: AsyncSession,
    user_id: uuid.UUID,
    plan: Literal["monthly", "yearly"],
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
        result = await db.execute(select(Subscription).where(Subscription.id == existing_payment.subscription_id))
        existing_sub = result.scalar_one_or_none()
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


async def get_payment_history(
    db: AsyncSession,
    user_id: str,
    page: int = 1,
    page_size: int = 10,
) -> dict:
    """결제 내역 조회 (페이지네이션)."""
    offset = (page - 1) * page_size

    result = await db.execute(
        select(Payment).where(Payment.user_id == uuid.UUID(user_id)).order_by(Payment.created_at.desc()).offset(offset).limit(page_size)
    )
    payments = result.scalars().all()

    count_result = await db.execute(select(func.count()).select_from(Payment).where(Payment.user_id == uuid.UUID(user_id)))
    total = count_result.scalar_one()

    return {
        "payments": [
            {
                "id": str(p.id),
                "amount": p.amount,
                "currency": p.currency,
                "status": p.status.value.lower(),
                "plan": p.plan.value.lower(),
                "paidAt": p.paid_at.isoformat() if p.paid_at else None,
                "createdAt": p.created_at.isoformat(),
            }
            for p in payments
        ],
        "total": total,
        "page": page,
        "pageSize": page_size,
        "totalPages": math.ceil(total / page_size) if total > 0 else 0,
    }
