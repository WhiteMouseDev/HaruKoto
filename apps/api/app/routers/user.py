from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import DailyProgress, QuizSession, UserAchievement, UserVocabProgress
from app.models.user import User
from app.schemas.common import CamelModel
from app.schemas.user import UserProfile, UserProfileUpdate, UserStats
from app.services.gamification import get_achievement

router = APIRouter(prefix="/api/v1/user", tags=["user"])


class UserProfileWithStats(CamelModel):
    profile: UserProfile
    stats: UserStats


class AvatarUpdateRequest(BaseModel):
    avatar_url: str


class AccountUpdateRequest(CamelModel):
    nickname: str | None = None
    email: str | None = None


@router.get("/profile", response_model=UserProfileWithStats)
async def get_profile(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    total_words = (
        await db.execute(select(func.count()).select_from(UserVocabProgress).where(UserVocabProgress.user_id == user.id))
    ).scalar_one()

    total_quizzes = (
        await db.execute(
            select(func.count())
            .select_from(QuizSession)
            .where(
                QuizSession.user_id == user.id,
                QuizSession.completed_at.isnot(None),
            )
        )
    ).scalar_one()

    total_study_days = (
        await db.execute(select(func.count()).select_from(DailyProgress).where(DailyProgress.user_id == user.id))
    ).scalar_one()

    achievement_rows = (await db.execute(select(UserAchievement).where(UserAchievement.user_id == user.id))).scalars().all()

    achievements: list[dict[str, Any]] = []
    for a in achievement_rows:
        definition = get_achievement(a.achievement_type)
        achievements.append(
            {
                "type": a.achievement_type,
                "title": definition["title"] if definition else a.achievement_type,
                "description": definition["description"] if definition else "",
                "emoji": definition.get("emoji", "") if definition else "",
                "achievedAt": a.achieved_at.isoformat() if a.achieved_at else None,
            }
        )

    return UserProfileWithStats(
        profile=UserProfile.model_validate(user),
        stats=UserStats(
            total_words_studied=total_words,
            total_quizzes_completed=total_quizzes,
            total_study_days=total_study_days,
            achievements=achievements,
        ),
    )


@router.patch("/profile", response_model=UserProfile)
async def update_profile(
    body: UserProfileUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    update_data = body.model_dump(exclude_unset=True)

    # Merge call_settings instead of overwriting
    if "call_settings" in update_data and update_data["call_settings"] is not None:
        existing = user.call_settings or {}
        existing.update(update_data["call_settings"])
        update_data["call_settings"] = existing

    for field, value in update_data.items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)
    return UserProfile.model_validate(user)


@router.patch("/avatar", response_model=dict)
async def update_avatar(
    body: AvatarUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    user.avatar_url = body.avatar_url
    await db.commit()
    await db.refresh(user)
    return {"avatarUrl": user.avatar_url}


@router.patch("/account", response_model=dict)
async def update_account(
    body: AccountUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)

    result: dict[str, Any] = {}
    if "nickname" in update_data:
        result["nickname"] = user.nickname
    if "email" in update_data:
        result["email"] = user.email
    return result
