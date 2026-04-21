from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.enums import SubscriptionStatus
from app.models import Subscription, User
from app.services.fsrs_shadow import get_shadow_report

router = APIRouter(prefix="/api/v1/cron", tags=["cron"])


@router.post("/subscription-renewal", status_code=200)
async def subscription_renewal(request: Request, db: AsyncSession = Depends(get_db)) -> dict[str, int]:
    # Verify cron secret
    auth = request.headers.get("authorization", "")
    if settings.CRON_SECRET and auth != f"Bearer {settings.CRON_SECRET}":
        raise HTTPException(status_code=401, detail="Unauthorized")

    now = datetime.now(UTC)
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


@router.post("/ensure-partitions", status_code=200)
async def ensure_review_event_partitions(request: Request, db: AsyncSession = Depends(get_db)) -> dict[str, list[str]]:
    """Ensure review_events partitions exist for the next 3 months."""
    auth = request.headers.get("authorization", "")
    if settings.CRON_SECRET and auth != f"Bearer {settings.CRON_SECRET}":
        raise HTTPException(status_code=401, detail="Unauthorized")

    created: list[str] = []
    now = datetime.now(UTC)
    for offset in range(4):  # current month + next 3
        # Calendar-accurate month arithmetic
        month = now.month + offset
        year = now.year + (month - 1) // 12
        month = (month - 1) % 12 + 1
        next_month = month + 1 if month < 12 else 1
        next_year = year if month < 12 else year + 1
        table_name = f"review_events_{year}_{month:02d}"

        # Check if partition already exists as a child of review_events
        result = await db.execute(
            text(
                "SELECT 1 FROM pg_inherits "
                "JOIN pg_class child ON child.oid = pg_inherits.inhrelid "
                "JOIN pg_class parent ON parent.oid = pg_inherits.inhparent "
                "WHERE parent.relname = 'review_events' AND child.relname = :name"
            ),
            {"name": table_name},
        )
        if result.scalar() is not None:
            continue

        try:
            await db.execute(
                text(f"""
                CREATE TABLE {table_name}
                PARTITION OF review_events
                FOR VALUES FROM ('{year}-{month:02d}-01') TO ('{next_year}-{next_month:02d}-01')
            """)
            )
            created.append(table_name)
        except Exception:
            await db.rollback()
            break

    await db.commit()
    return {"created": created}


@router.post("/fsrs-shadow-report", status_code=200)
async def fsrs_shadow_report(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str | None = None,
) -> dict[str, Any]:
    """Generate FSRS shadow report for a user (admin/cron only)."""
    auth = request.headers.get("authorization", "")
    if settings.CRON_SECRET and auth != f"Bearer {settings.CRON_SECRET}":
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not user_id:
        raise HTTPException(status_code=400, detail="user_id query parameter required")

    from uuid import UUID

    try:
        uid = UUID(user_id)
    except ValueError as err:
        raise HTTPException(status_code=400, detail="Invalid user_id format") from err

    report = await get_shadow_report(db, uid)
    return report
