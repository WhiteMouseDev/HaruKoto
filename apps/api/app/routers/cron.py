from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.enums import SubscriptionStatus
from app.models import Subscription, User

router = APIRouter(prefix="/api/v1/cron", tags=["cron"])


@router.post("/subscription-renewal")
async def subscription_renewal(request: Request, db: AsyncSession = Depends(get_db)):
    # Verify cron secret
    auth = request.headers.get("authorization", "")
    if settings.CRON_SECRET and auth != f"Bearer {settings.CRON_SECRET}":
        raise HTTPException(status_code=401, detail="Unauthorized")

    now = datetime.utcnow()
    # Expire subscriptions past their period end
    result = await db.execute(
        select(Subscription).where(
            Subscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.CANCELLED]),
            Subscription.current_period_end <= now,
        )
    )
    expired = result.scalars().all()

    for sub in expired:
        sub.status = SubscriptionStatus.EXPIRED
        await db.execute(
            update(User)
            .where(User.id == sub.user_id)
            .values(
                is_premium=False,
                subscription_expires_at=None,
            )
        )

    await db.commit()
    return {"processed": len(expired)}
