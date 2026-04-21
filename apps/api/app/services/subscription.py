from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Literal, TypedDict, cast

from dateutil.relativedelta import relativedelta  # type: ignore[import-untyped]
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Subscription
from app.models.enums import SubscriptionPlan, SubscriptionStatus

type PlanSlug = Literal["monthly", "yearly"]


class SubscriptionStatusResult(TypedDict):
    is_premium: bool
    plan: SubscriptionPlan
    expires_at: str | None
    cancelled_at: str | None
    subscription: Subscription | None


def _ensure_aware(dt: datetime) -> datetime:
    """offset-naive datetime을 UTC로 간주하여 aware로 변환."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


# ==========================================
# 구독 기간 계산
# ==========================================


def get_subscription_period_end(
    plan: PlanSlug,
    from_date: datetime | None = None,
) -> datetime:
    """구독 기간 종료일 계산."""
    base = from_date or datetime.now(tz=UTC)
    if plan == "monthly":
        return cast(datetime, base + relativedelta(months=1))
    return cast(datetime, base + relativedelta(years=1))


# ==========================================
# 구독 상태 조회
# ==========================================


async def get_subscription_status(db: AsyncSession, user_id: uuid.UUID) -> SubscriptionStatusResult:
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
