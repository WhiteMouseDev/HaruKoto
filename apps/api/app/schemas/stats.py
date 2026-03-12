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
    correct_answers: int
    total_answers: int
    xp_earned: int
    goal_progress: float


class StreakInfo(CamelModel):
    current: int
    longest: int


class WeeklyStatItem(CamelModel):
    date: str
    words_studied: int
    xp_earned: int


class DashboardResponse(CamelModel):
    show_kana: bool
    kana_progress: KanaProgressResponse
    today: TodayStats
    streak: StreakInfo
    weekly_stats: list[WeeklyStatItem]
    level_progress: LevelProgress


class DailyProgressItem(CamelModel):
    date: str
    words_studied: int
    quizzes_completed: int
    correct_answers: int
    total_answers: int
    conversation_count: int
    study_time_seconds: int
    xp_earned: int


class HistoryResponse(CamelModel):
    year: int
    month: int
    records: list[DailyProgressItem]
