from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import field_validator

from app.models.enums import JlptLevel, UserGoal
from app.schemas.common import CamelModel
from app.utils.constants import DAILY_CATEGORY_GOALS_KEY


class LevelProgressInfo(CamelModel):
    current_xp: int
    xp_for_next: int


class UserProfile(CamelModel):
    id: UUID
    email: str | None = None
    nickname: str | None = "학습자"
    avatar_url: str | None = None
    jlpt_level: JlptLevel
    goal: UserGoal | None = None
    goals: list[str] | None = None
    daily_goal: int
    experience_points: int
    level: int
    streak_count: int
    longest_streak: int
    last_study_date: datetime | None = None
    is_premium: bool
    show_kana: bool
    onboarding_completed: bool
    call_settings: dict[str, Any] | None = None
    app_settings: dict[str, Any] | None = None
    created_at: datetime
    level_progress: LevelProgressInfo | None = None

    @field_validator("app_settings")
    @classmethod
    def hide_server_settings(cls, value: dict[str, Any] | None) -> dict[str, Any] | None:
        if value is not None and DAILY_CATEGORY_GOALS_KEY in value:
            return {key: item for key, item in value.items() if key != DAILY_CATEGORY_GOALS_KEY} or None
        return value


class UserProfileUpdate(CamelModel):
    nickname: str | None = None
    jlpt_level: JlptLevel | None = None
    daily_goal: int | None = None
    goal: UserGoal | None = None  # Legacy
    goals: list[str] | None = None  # New (복수 선택)
    show_kana: bool | None = None
    call_settings: dict[str, Any] | None = None
    app_settings: dict[str, Any] | None = None


class UserSummary(CamelModel):
    total_words_studied: int
    total_quizzes_completed: int
    total_study_days: int
    total_xp_earned: int


class AchievementItem(CamelModel):
    achievement_type: str
    achieved_at: datetime | None = None


class UserStats(CamelModel):
    total_words_studied: int
    total_quizzes_completed: int
    total_study_days: int
    achievements: list[dict[str, Any]]
