from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.schemas.subscription import StoreNotificationAck, StoreNotificationRequest
from app.services.portone_webhook import (
    PortoneWebhookError,
    extract_portone_payment_id,
    handle_portone_payment_event,
    verify_portone_signature,
)
from app.services.store_notifications import acknowledge_store_notification

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/webhook", tags=["webhook"])


@router.post("/portone", status_code=200)
async def portone_webhook(request: Request, db: AsyncSession = Depends(get_db)) -> dict[str, bool]:
    body = await request.body()
    signature = request.headers.get("x-portone-signature", "")
    timestamp = request.headers.get("x-portone-timestamp", "")

    try:
        verify_portone_signature(
            body=body,
            signature=signature,
            timestamp=timestamp,
            secret=settings.PORTONE_WEBHOOK_SECRET,
        )
    except PortoneWebhookError as err:
        raise HTTPException(status_code=err.status_code, detail=err.detail) from err

    payment_id = extract_portone_payment_id(await request.json())
    if payment_id is None:
        logger.info("Webhook received without paymentId, skipping")
        return {"ok": True}

    logger.info("Webhook received", extra={"payment_id": payment_id})

    try:
        await handle_portone_payment_event(db, payment_id)
    except PortoneWebhookError as err:
        raise HTTPException(status_code=err.status_code, detail=err.detail) from err

    return {"ok": True}


@router.post("/apple/app-store-server", response_model=StoreNotificationAck, status_code=202)
async def apple_app_store_server_notification(body: StoreNotificationRequest) -> StoreNotificationAck:
    return acknowledge_store_notification("apple", body.signed_payload)


@router.post("/google/play", response_model=StoreNotificationAck, status_code=202)
async def google_play_notification(body: StoreNotificationRequest) -> StoreNotificationAck:
    return acknowledge_store_notification("google", body.signed_payload)
