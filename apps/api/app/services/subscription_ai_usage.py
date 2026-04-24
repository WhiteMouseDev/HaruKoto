from __future__ import annotations

import uuid
from datetime import UTC, date, datetime
from typing import Any, Literal, NotRequired, TypedDict

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import DailyAiUsage
from app.services.subscription import get_subscription_status
from app.utils.constants import AI_LIMITS


class DailyAiUsageResult(TypedDict):
    chat_count: int
    chat_seconds: int
    call_count: int
    call_seconds: int


class AiLimitResult(TypedDict):
    allowed: bool
    reason: NotRequired[str]


async def get_daily_ai_usage(db: AsyncSession, user_id: uuid.UUID) -> DailyAiUsageResult:
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
) -> AiLimitResult:
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
    stmt = build_ai_usage_tracking_statement(
        user_id=user_id,
        today=today,
        usage_type=usage_type,
        duration_seconds=duration_seconds,
    )
    await db.execute(stmt)
    await db.flush()


def build_ai_usage_tracking_statement(
    *,
    user_id: uuid.UUID,
    today: date,
    usage_type: Literal["chat", "call"],
    duration_seconds: int,
) -> Any:
    count_field = "chat_count" if usage_type == "chat" else "call_count"
    seconds_field = "chat_seconds" if usage_type == "chat" else "call_seconds"
    now = datetime.now(tz=UTC)
    insert_values = {
        "id": uuid.uuid4(),
        "user_id": user_id,
        "date": today,
        "chat_count": 0,
        "chat_seconds": 0,
        "call_count": 0,
        "call_seconds": 0,
        "created_at": now,
        "updated_at": now,
    }
    insert_values[count_field] = 1
    insert_values[seconds_field] = duration_seconds

    stmt = insert(DailyAiUsage).values(**insert_values)
    return stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_={
            count_field: getattr(DailyAiUsage, count_field) + 1,
            seconds_field: getattr(DailyAiUsage, seconds_field) + duration_seconds,
            "updated_at": now,
        },
    )
