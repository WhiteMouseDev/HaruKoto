from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import QuizType
from app.models.user import User
from app.services.category_goals import award_goal_after_target_change, goal_target, set_goal_target
from app.services.study_day_recording import lock_study_user
from app.utils.constants import MAX_DAILY_GOAL, MIN_DAILY_GOAL
from app.utils.date import get_today_kst


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
    quiz_type: QuizType = QuizType.VOCABULARY,
) -> DailyGoalUpdateResult:
    if daily_goal < MIN_DAILY_GOAL or daily_goal > MAX_DAILY_GOAL:
        raise StudyDailyGoalServiceError(
            status_code=422,
            detail="dailyGoal must be between 5 and 50",
        )

    await lock_study_user(db, user)
    await db.refresh(user, attribute_names=["daily_goal", "app_settings"])
    previous = goal_target(user, quiz_type)
    set_goal_target(user, quiz_type=quiz_type, target=daily_goal)
    if previous != daily_goal:
        await award_goal_after_target_change(db, user, day=get_today_kst(), quiz_type=quiz_type)
    await db.commit()

    return DailyGoalUpdateResult(daily_goal=daily_goal)
