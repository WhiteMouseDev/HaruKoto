from __future__ import annotations

import math
import uuid
from typing import TypedDict

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Payment


class PaymentHistoryItem(TypedDict):
    id: str
    amount: int
    currency: str
    status: str
    plan: str
    paidAt: str | None
    createdAt: str


class PaymentHistoryResult(TypedDict):
    payments: list[PaymentHistoryItem]
    total: int
    page: int
    pageSize: int
    totalPages: int


async def get_payment_history(
    db: AsyncSession,
    user_id: str,
    page: int = 1,
    page_size: int = 10,
) -> PaymentHistoryResult:
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
