from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import UserKanaProgress
from app.models.user import User
from app.schemas.kana import KanaProgressRecord
from app.services.kana_daily_progress import apply_daily_progress_increment
from app.utils.date import get_today_kst


@dataclass(slots=True)
class KanaProgressRecordResult:
    ok: bool


async def record_kana_learning_progress(
    db: AsyncSession,
    user: User,
    body: KanaProgressRecord,
) -> KanaProgressRecordResult:
    await db.execute(
        build_kana_progress_upsert_statement(
            user_id=user.id,
            kana_id=body.kana_id,
            reviewed_at=datetime.now(UTC),
        )
    )
    await apply_daily_progress_increment(
        db,
        user_id=user.id,
        today=get_today_kst(),
        kana_learned=1,
    )
    await db.commit()
    return KanaProgressRecordResult(ok=True)


def build_kana_progress_upsert_statement(
    *,
    user_id: uuid.UUID,
    kana_id: uuid.UUID,
    reviewed_at: datetime,
) -> Any:
    stmt = pg_insert(UserKanaProgress).values(
        user_id=user_id,
        kana_id=kana_id,
        correct_count=1,
        streak=1,
    )
    return stmt.on_conflict_do_update(
        index_elements=["user_id", "kana_id"],
        set_={
            "correct_count": UserKanaProgress.correct_count + 1,
            "streak": UserKanaProgress.streak + 1,
            "last_reviewed_at": reviewed_at,
        },
    )
