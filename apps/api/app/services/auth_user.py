from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import JlptLevel
from app.models.user import User
from app.schemas.auth import OnboardingRequest
from app.schemas.user import LevelProgressInfo, UserProfile
from app.services.gamification import calculate_level


async def get_or_create_user_profile(
    db: AsyncSession,
    *,
    user_id: UUID,
    email: str,
) -> UserProfile:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(id=user_id, email=email)
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return build_user_profile(user)


async def complete_onboarding_profile(
    db: AsyncSession,
    user: User,
    body: OnboardingRequest,
) -> UserProfile:
    user.nickname = body.nickname
    user.jlpt_level = body.jlpt_level
    user.daily_goal = body.daily_goal
    user.onboarding_completed = True
    if body.goal is not None:
        user.goal = body.goal
    if body.goals is not None:
        user.goals = body.goals[:3]
    if body.show_kana is not None:
        user.show_kana = body.show_kana
    if body.jlpt_level == JlptLevel.ABSOLUTE_ZERO:
        user.show_kana = True

    await db.commit()
    await db.refresh(user)

    return build_user_profile(user)


def build_user_profile(user: User) -> UserProfile:
    level_info = calculate_level(user.experience_points)
    profile = UserProfile.model_validate(user)
    profile.level_progress = LevelProgressInfo(
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
    )
    return profile
