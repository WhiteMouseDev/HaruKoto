"""Transaction-local user serialization shared by all activity writers.

Order is user NO KEY UPDATE -> domain/session -> daily row. Authentication may
have loaded an older User, so only reward/activity fields are refreshed under
that lock before writers perform calculations; credentials/preferences stay out.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.gamification import DailyProgress
from app.models.user import User
from app.services.daily_progress_upsert import build_daily_progress_insert_values
from app.services.gamification import update_streak
from app.utils.date import study_date_kst

ACTIVITY_FIELDS = ["experience_points", "level", "last_study_date", "streak_count", "longest_streak"]


async def lock_study_user(db: AsyncSession, user: User) -> None:
    """Reload the locked activity snapshot before any domain or reward writes.

    no_autoflush prevents a pending domain mutation from reversing lock order.
    Callers must invoke this before calculating/changing User reward fields.
    NO KEY UPDATE remains compatible with child-row FK KEY SHARE locks.
    """
    with db.no_autoflush:
        await db.refresh(user, attribute_names=ACTIVITY_FIELDS, with_for_update={"key_share": True})


def canonical_study_instant(processed_at: datetime) -> datetime:
    """Match the existing UTC-naive User TIMESTAMP(3) without rounding days.

    Flooring, rather than PostgreSQL's millisecond rounding, prevents an instant
    just before KST midnight from becoming the next day in last_study_date.
    Receipts retain this exact same canonical aware UTC processing instant.
    """
    if processed_at.utcoffset() is None:
        raise ValueError("Study-day processing timestamp must be timezone-aware")
    utc = processed_at.astimezone(UTC)
    return utc.replace(microsecond=(utc.microsecond // 1000) * 1000)


def apply_study_streak(user: User, *, processed_at: datetime) -> date:
    """Apply one aware server timestamp without moving a newer study day back."""
    processed_at = canonical_study_instant(processed_at)
    day = study_date_kst(processed_at)
    streak = update_streak(user.last_study_date, user.streak_count, user.longest_streak, day)
    user.streak_count = streak["streak_count"]
    user.longest_streak = streak["longest_streak"]
    previous = user.last_study_date
    previous_aware = previous.replace(tzinfo=UTC) if previous is not None and previous.utcoffset() is None else previous
    if previous_aware is None or processed_at >= previous_aware:
        user.last_study_date = processed_at
    return day


async def record_lesson_study_day(db: AsyncSession, user: User, *, processed_at: datetime) -> None:
    """Called only by the first successful keyed lesson receipt transaction."""
    day = apply_study_streak(user, processed_at=processed_at)
    statement = insert(DailyProgress).values(**build_daily_progress_insert_values(user_id=user.id, today=day, lesson_completed=True))
    await db.execute(statement.on_conflict_do_update(index_elements=["user_id", "date"], set_={"lesson_completed": True}))
