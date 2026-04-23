from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User

MIN_DAILY_GOAL = 5
MAX_DAILY_GOAL = 50


class StudyDailyGoalServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class DailyGoalUpdateResult:
    daily_goal: int


async def update_daily_goal_data(
    db: AsyncSession,
    user: User,
    *,
    daily_goal: int,
) -> DailyGoalUpdateResult:
    if daily_goal < MIN_DAILY_GOAL or daily_goal > MAX_DAILY_GOAL:
        raise StudyDailyGoalServiceError(
            status_code=422,
            detail="dailyGoal must be between 5 and 50",
        )

    user.daily_goal = daily_goal
    await db.commit()
    await db.refresh(user)

    return DailyGoalUpdateResult(daily_goal=user.daily_goal)
