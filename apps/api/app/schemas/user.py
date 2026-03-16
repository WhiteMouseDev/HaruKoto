from __future__ import annotations

from datetime import date, datetime
from typing import Any
from uuid import UUID

from app.models.enums import JlptLevel, UserGoal
from app.schemas.common import CamelModel


class LevelProgressInfo(CamelModel):
    current_xp: int
    xp_for_next: int


class UserProfile(CamelModel):
    id: UUID
    email: str
    nickname: str | None = "학습자"
    avatar_url: str | None = None
    jlpt_level: JlptLevel
    goal: UserGoal | None = None
    daily_goal: int
    experience_points: int
    level: int
    streak_count: int
    longest_streak: int
    last_study_date: date | None = None
    is_premium: bool
    show_kana: bool
    onboarding_completed: bool
    call_settings: dict[str, Any] | None = None
    app_settings: dict[str, Any] | None = None
    created_at: datetime
    level_progress: LevelProgressInfo | None = None


class UserProfileUpdate(CamelModel):
    nickname: str | None = None
    jlpt_level: JlptLevel | None = None
    daily_goal: int | None = None
    goal: UserGoal | None = None
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
