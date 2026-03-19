from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from app.models.enums import PaymentStatus, SubscriptionPlan
from app.schemas.common import CamelModel


class SubscriptionInfo(CamelModel):
    is_premium: bool
    plan: SubscriptionPlan
    expires_at: datetime | None = None
    cancelled_at: datetime | None = None


class AiUsageInfo(CamelModel):
    chat_count: int
    call_count: int
    chat_seconds: int
    call_seconds: int
    chat_limit: int
    call_limit: int
    chat_seconds_limit: int
    call_seconds_limit: int


class SubscriptionStatusResponse(CamelModel):
    subscription: SubscriptionInfo
    ai_usage: AiUsageInfo


class AiUsage(CamelModel):
    chat_count: int
    chat_seconds: int
    call_count: int
    call_seconds: int


class AiLimits(CamelModel):
    chat_count: int
    chat_seconds: int
    call_count: int
    call_seconds: int


class CheckoutRequest(CamelModel):
    plan: str


class CheckoutResponse(CamelModel):
    payment_id: str
    store_id: str
    channel_key: str
    order_name: str
    total_amount: int
    currency: str
    customer_id: str


class ActivateRequest(CamelModel):
    payment_id: str


class CancelRequest(CamelModel):
    reason: str | None = None


class StoreVerifyRequest(CamelModel):
    platform: Literal["ios", "android"]
    plan: Literal["monthly", "yearly"]
    product_id: str
    transaction_id: str | None = None
    original_transaction_id: str | None = None
    purchase_token: str | None = None
    signed_payload: str | None = None


class StoreVerifyResponse(CamelModel):
    ok: bool
    status: str
    grant_state: str
    message: str


class StoreNotificationRequest(CamelModel):
    signed_payload: str


class StoreNotificationAck(CamelModel):
    ok: bool
    accepted: bool
    source: str


class PaymentHistoryItem(CamelModel):
    id: UUID
    amount: int
    currency: str
    status: PaymentStatus
    plan: SubscriptionPlan
    paid_at: datetime | None = None
    created_at: datetime


class PaymentHistoryResponse(CamelModel):
    payments: list[PaymentHistoryItem]
    total: int
    page: int
    page_size: int
    total_pages: int
