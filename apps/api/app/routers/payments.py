from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.services.subscription_payments import PaymentHistoryResult, get_payment_history

router = APIRouter(prefix="/api/v1/payments", tags=["payments"])


@router.get("", status_code=200)
async def list_payments(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, le=50),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaymentHistoryResult:
    return await get_payment_history(db, str(user.id), page, page_size)
