from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import PushSubscription
from app.models.user import User
from app.schemas.notification import PushSubscribeRequest

router = APIRouter(prefix="/api/v1/push", tags=["push"])


@router.post("/subscribe", status_code=200)
async def subscribe_push(
    body: PushSubscribeRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = pg_insert(PushSubscription).values(
        user_id=user.id,
        endpoint=body.endpoint,
        p256dh=body.p256dh,
        auth=body.auth,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "endpoint"],
        set_={"p256dh": body.p256dh, "auth": body.auth},
    )
    await db.execute(stmt)
    await db.commit()
    return {"ok": True}
