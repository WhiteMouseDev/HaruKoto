from __future__ import annotations

from app.schemas.common import CamelModel
from app.schemas.kana import KanaProgressResponse


class ProgressStat(CamelModel):
    total: int
    mastered: int
    in_progress: int


class LevelProgress(CamelModel):
    vocabulary: ProgressStat
    grammar: ProgressStat


class TodayStats(CamelModel):
    words_studied: int
    quizzes_completed: int
    xp_earned: int
    goal_progress: float


class WeeklyStats(CamelModel):
    dates: list[str]
    words_studied: list[int]
    xp_earned: list[int]


class DashboardResponse(CamelModel):
    today: TodayStats
    streak: int
    weekly: WeeklyStats
    level_progress: LevelProgress
    kana_progress: KanaProgressResponse


class DailyProgressItem(CamelModel):
    date: str
    words_studied: int
    quizzes_completed: int
    xp_earned: int


class HistoryResponse(CamelModel):
    days: list[DailyProgressItem]
