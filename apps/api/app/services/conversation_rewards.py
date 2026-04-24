from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Literal

from sqlalchemy import func, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Conversation, DailyProgress, Notification, User
from app.services.daily_progress_upsert import build_daily_progress_insert_values
from app.services.gamification import calculate_level, check_and_grant_achievements, update_streak
from app.services.subscription_ai_usage import track_ai_usage
from app.utils.constants import REWARDS
from app.utils.date import get_today_kst

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class ConversationRewardResult:
    xp_earned: int
    events: list[dict[str, Any]]


async def _update_daily_conversation_progress(
    db: AsyncSession,
    *,
    user_id: Any,
    xp: int,
    study_minutes: int,
) -> None:
    await db.execute(
        insert(DailyProgress)
        .values(
            **build_daily_progress_insert_values(
                user_id=user_id,
                today=get_today_kst(),
                xp_earned=xp,
                study_minutes=study_minutes,
                conversation_count=1,
            )
        )
        .on_conflict_do_update(
            index_elements=["user_id", "date"],
            set_={
                "xp_earned": DailyProgress.xp_earned + xp,
                "study_minutes": func.coalesce(DailyProgress.study_minutes, 0) + study_minutes,
                "conversation_count": func.coalesce(DailyProgress.conversation_count, 0) + 1,
            },
        )
    )


async def _count_completed_conversations(db: AsyncSession, *, user_id: Any) -> int:
    result = await db.execute(
        select(func.count()).select_from(Conversation).where(Conversation.user_id == user_id, Conversation.ended_at.isnot(None))
    )
    return result.scalar() or 0


async def grant_conversation_completion_rewards(
    db: AsyncSession,
    user: User,
    *,
    now: datetime,
    duration_seconds: int,
    usage_type: Literal["chat", "call"],
) -> ConversationRewardResult:
    xp = REWARDS.CONVERSATION_COMPLETE_XP
    logger.info("Conversation complete - awarding XP", extra={"user_id": str(user.id), "xp": xp, "usage_type": usage_type})
    old_level = calculate_level(user.experience_points)["level"]

    await db.execute(update(User).where(User.id == user.id).values(experience_points=User.experience_points + xp))
    await db.refresh(user)

    new_level = calculate_level(user.experience_points)["level"]
    if new_level != user.level:
        user.level = new_level

    streak = update_streak(user.last_study_date, user.streak_count, user.longest_streak, now)
    user.streak_count = streak["streak_count"]
    user.longest_streak = streak["longest_streak"]
    user.last_study_date = now

    await _update_daily_conversation_progress(
        db,
        user_id=user.id,
        xp=xp,
        study_minutes=max(0, duration_seconds // 60),
    )

    await track_ai_usage(db, user.id, usage_type, duration_seconds)

    conversation_count = await _count_completed_conversations(db, user_id=user.id)
    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": new_level,
            "old_level": old_level,
            "streak_count": streak["streak_count"],
            "conversation_count": conversation_count,
        },
    )

    for event in events:
        db.add(Notification(user_id=user.id, title=event["title"], body=event["body"], type="achievement"))

    return ConversationRewardResult(xp_earned=xp, events=[dict(event) for event in events])
