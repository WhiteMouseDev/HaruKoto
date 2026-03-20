from __future__ import annotations

from app.models.enums import JlptLevel, UserGoal
from app.schemas.common import CamelModel
from app.schemas.user import UserProfile


class OnboardingRequest(CamelModel):
    nickname: str
    jlpt_level: JlptLevel
    goal: UserGoal | None = None  # Legacy
    goals: list[str] | None = None  # New (복수 선택)
    daily_goal: int = 10
    show_kana: bool | None = None


class OnboardingResponse(CamelModel):
    profile: UserProfile
