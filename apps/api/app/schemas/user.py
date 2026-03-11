from __future__ import annotations

from datetime import date, datetime
from typing import Any
from uuid import UUID

from app.models.enums import JlptLevel, UserGoal
from app.schemas.common import CamelModel


class UserProfile(CamelModel):
    id: UUID
    email: str
    nickname: str
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
    created_at: datetime


class UserProfileUpdate(CamelModel):
    nickname: str | None = None
    jlpt_level: JlptLevel | None = None
    daily_goal: int | None = None
    goal: UserGoal | None = None
    show_kana: bool | None = None
    call_settings: dict[str, Any] | None = None


class UserStats(CamelModel):
    total_words_studied: int
    total_quizzes_completed: int
    total_study_days: int
    achievements: list[dict[str, Any]]
