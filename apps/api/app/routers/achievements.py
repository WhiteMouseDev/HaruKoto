from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import UserAchievement
from app.models.user import User
from app.schemas.stats import AchievementItem, AchievementsResponse
from app.services.gamification import ACHIEVEMENTS

router = APIRouter(prefix="/api/v1/achievements", tags=["achievements"])


@router.get("", response_model=AchievementsResponse, status_code=200)
async def get_achievements(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """3-11: All achievement definitions with user's unlocked status."""
    result = await db.execute(
        select(UserAchievement).where(UserAchievement.user_id == user.id)
    )
    user_achievements = {ua.achievement_type: ua for ua in result.scalars().all()}

    items: list[AchievementItem] = []
    for defn in ACHIEVEMENTS:
        a_type = defn.get("type", "")
        ua = user_achievements.get(a_type)
        items.append(
            AchievementItem(
                type=a_type,
                title=defn.get("title", ""),
                description=defn.get("description", ""),
                emoji=defn.get("emoji", ""),
                achieved=ua is not None,
                achieved_at=ua.achieved_at.isoformat() if ua else None,
            )
        )

    return AchievementsResponse(achievements=items)
