from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import DailyProgress
from app.services.daily_progress_upsert import build_daily_progress_insert_values


async def apply_daily_progress_increment(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    today: date,
    xp_earned: int = 0,
    kana_learned: int = 0,
) -> None:
    await db.execute(
        build_daily_progress_increment_statement(
            user_id=user_id,
            today=today,
            xp_earned=xp_earned,
            kana_learned=kana_learned,
        )
    )


def build_daily_progress_increment_statement(
    *,
    user_id: uuid.UUID,
    today: date,
    xp_earned: int = 0,
    kana_learned: int = 0,
) -> Any:
    values = build_daily_progress_insert_values(user_id=user_id, today=today)
    updates: dict[str, Any] = {}

    if xp_earned:
        values["xp_earned"] = xp_earned
        updates["xp_earned"] = DailyProgress.xp_earned + xp_earned
    if kana_learned:
        values["kana_learned"] = kana_learned
        updates["kana_learned"] = DailyProgress.kana_learned + kana_learned
    if not updates:
        raise ValueError("At least one daily progress increment is required")

    stmt = pg_insert(DailyProgress).values(**values)
    return stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_=updates,
    )
