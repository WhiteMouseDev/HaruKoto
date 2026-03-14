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


# ==========================================
# 3-6: Heatmap
# ==========================================


class HeatmapItem(CamelModel):
    date: str
    words_studied: int
    study_minutes: int
    level: int


class HeatmapResponse(CamelModel):
    data: list[HeatmapItem]


# ==========================================
# 3-7: JLPT Progress
# ==========================================


class JlptProgressStat(CamelModel):
    total: int
    mastered: int
    in_progress: int


class JlptLevelProgress(CamelModel):
    level: str
    vocabulary: JlptProgressStat
    grammar: JlptProgressStat


class JlptProgressResponse(CamelModel):
    levels: list[JlptLevelProgress]


# ==========================================
# 3-8: Time Chart
# ==========================================


class TimeChartItem(CamelModel):
    date: str
    minutes: int


class TimeChartResponse(CamelModel):
    data: list[TimeChartItem]


# ==========================================
# 3-9: Volume Chart
# ==========================================


class VolumeChartItem(CamelModel):
    date: str
    words_studied: int
    grammar_studied: int
    sentences_studied: int


class VolumeChartResponse(CamelModel):
    data: list[VolumeChartItem]


# ==========================================
# 3-10: By Category
# ==========================================


class CategoryStat(CamelModel):
    total: int
    daily: list[int]


class ByCategoryResponse(CamelModel):
    vocabulary: CategoryStat
    grammar: CategoryStat
    sentences: CategoryStat


# ==========================================
# 3-11: Achievements
# ==========================================


class AchievementItem(CamelModel):
    type: str
    title: str
    description: str
    emoji: str
    achieved: bool
    achieved_at: str | None


class AchievementsResponse(CamelModel):
    achievements: list[AchievementItem]


# ==========================================
# 3-12: Daily Goal
# ==========================================


class DailyGoalRequest(CamelModel):
    daily_goal: int


class DailyGoalResponse(CamelModel):
    daily_goal: int
