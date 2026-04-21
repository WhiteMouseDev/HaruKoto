from __future__ import annotations

import logging
from typing import Literal

from app.schemas.subscription import StoreNotificationAck

type StoreNotificationSource = Literal["apple", "google"]

logger = logging.getLogger(__name__)


def acknowledge_store_notification(source: StoreNotificationSource, signed_payload: str) -> StoreNotificationAck:
    label = "Apple App Store Server" if source == "apple" else "Google Play subscription"
    logger.info(
        "%s notification received",
        label,
        extra={"has_signed_payload": bool(signed_payload), "payload_size": len(signed_payload)},
    )
    return StoreNotificationAck(ok=True, accepted=True, source=source)
