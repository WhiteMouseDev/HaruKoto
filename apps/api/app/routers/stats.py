from __future__ import annotations

import calendar
from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import (
    DailyProgress,
    Grammar,
    KanaCharacter,
    UserGrammarProgress,
    UserKanaProgress,
    UserVocabProgress,
    Vocabulary,
)
from app.models.enums import JlptLevel, KanaType
from app.models.user import User
from app.schemas.kana import KanaProgressResponse, KanaStat
from app.schemas.stats import (
    ByCategoryResponse,
    CategoryStat,
    DailyProgressItem,
    DashboardResponse,
    HeatmapItem,
    HeatmapResponse,
    HistoryResponse,
    JlptLevelProgress,
    JlptProgressResponse,
    JlptProgressStat,
    LevelProgress,
    ProgressStat,
    StreakInfo,
    TimeChartItem,
    TimeChartResponse,
    TodayStats,
    VolumeChartItem,
    VolumeChartResponse,
    WeeklyStatItem,
)
from app.utils.date import get_today_kst

# ---------------------------------------------------------------------------
# Heatmap level thresholds
# ---------------------------------------------------------------------------
HEATMAP_LEVEL_LOW = 10
HEATMAP_LEVEL_MID = 20

router = APIRouter(prefix="/api/v1/stats", tags=["stats"])


@router.get("/dashboard", response_model=DashboardResponse, status_code=200)
async def get_dashboard(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> DashboardResponse:
    today = get_today_kst()

    # Today's progress
    dp_result = await db.execute(select(DailyProgress).where(DailyProgress.user_id == user.id, DailyProgress.date == today))
    dp = dp_result.scalar_one_or_none()

    goal_progress = 0.0
    if dp and user.daily_goal > 0:
        goal_progress = min(1.0, dp.xp_earned / (user.daily_goal * 10))

    today_stats = TodayStats(
        words_studied=dp.words_studied if dp else 0,
        quizzes_completed=dp.quizzes_completed if dp else 0,
        correct_answers=dp.correct_answers if dp else 0,
        total_answers=dp.total_answers if dp else 0,
        xp_earned=dp.xp_earned if dp else 0,
        goal_progress=goal_progress,
    )

    # Streak as object
    streak = StreakInfo(current=user.streak_count, longest=user.longest_streak)

    # Weekly stats (last 7 days) as array of objects
    week_start = today - timedelta(days=6)
    weekly_result = await db.execute(
        select(DailyProgress).where(DailyProgress.user_id == user.id, DailyProgress.date >= week_start).order_by(DailyProgress.date)
    )
    weekly_data = {str(dp_row.date): dp_row for dp_row in weekly_result.scalars().all()}

    weekly_stats: list[WeeklyStatItem] = []
    for i in range(7):
        d = week_start + timedelta(days=i)
        dp_day = weekly_data.get(str(d))
        weekly_stats.append(
            WeeklyStatItem(
                date=str(d),
                words_studied=dp_day.words_studied if dp_day else 0,
                xp_earned=dp_day.xp_earned if dp_day else 0,
            )
        )

    # Level progress — single aggregate query for vocab
    vocab_total = (await db.execute(select(func.count(Vocabulary.id)).where(Vocabulary.jlpt_level == user.jlpt_level))).scalar() or 0
    vocab_agg_result = await db.execute(
        select(
            UserVocabProgress.mastered,
            func.count(UserVocabProgress.id),
        )
        .join(Vocabulary)
        .where(UserVocabProgress.user_id == user.id, Vocabulary.jlpt_level == user.jlpt_level)
        .group_by(UserVocabProgress.mastered)
    )
    vocab_counts = {row[0]: row[1] for row in vocab_agg_result.all()}
    vocab_mastered = vocab_counts.get(True, 0)
    vocab_in_progress = vocab_counts.get(False, 0)

    # Level progress — single aggregate query for grammar
    grammar_total = (await db.execute(select(func.count(Grammar.id)).where(Grammar.jlpt_level == user.jlpt_level))).scalar() or 0
    grammar_agg_result = await db.execute(
        select(
            UserGrammarProgress.mastered,
            func.count(UserGrammarProgress.id),
        )
        .join(Grammar)
        .where(UserGrammarProgress.user_id == user.id, Grammar.jlpt_level == user.jlpt_level)
        .group_by(UserGrammarProgress.mastered)
    )
    grammar_counts = {row[0]: row[1] for row in grammar_agg_result.all()}
    grammar_mastered = grammar_counts.get(True, 0)
    grammar_in_progress = grammar_counts.get(False, 0)

    # Kana progress — single batch query for totals per kana_type
    kana_total_result = await db.execute(select(KanaCharacter.kana_type, func.count(KanaCharacter.id)).group_by(KanaCharacter.kana_type))
    kana_totals = {row[0]: row[1] for row in kana_total_result.all()}

    # Kana mastered — single query across all types
    kana_mastered_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter)
        .where(UserKanaProgress.user_id == user.id, UserKanaProgress.mastered.is_(True))
        .group_by(KanaCharacter.kana_type)
    )
    kana_mastered_map = {row[0]: row[1] for row in kana_mastered_result.all()}

    # Kana learned — single query across all types
    kana_learned_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter)
        .where(UserKanaProgress.user_id == user.id)
        .group_by(KanaCharacter.kana_type)
    )
    kana_learned_map = {row[0]: row[1] for row in kana_learned_result.all()}

    def _kana_stat(kt: KanaType) -> KanaStat:
        return KanaStat(
            learned=kana_learned_map.get(kt, 0),
            mastered=kana_mastered_map.get(kt, 0),
            total=kana_totals.get(kt, 0),
        )

    return DashboardResponse(
        show_kana=user.show_kana,
        today=today_stats,
        streak=streak,
        weekly_stats=weekly_stats,
        level_progress=LevelProgress(
            vocabulary=ProgressStat(total=vocab_total, mastered=vocab_mastered, in_progress=vocab_in_progress),
            grammar=ProgressStat(total=grammar_total, mastered=grammar_mastered, in_progress=grammar_in_progress),
        ),
        kana_progress=KanaProgressResponse(
            hiragana=_kana_stat(KanaType.HIRAGANA),
            katakana=_kana_stat(KanaType.KATAKANA),
        ),
    )


@router.get("/history", response_model=HistoryResponse, status_code=200)
async def get_history(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    year: int | None = Query(default=None),
    month: int | None = Query(default=None),
) -> HistoryResponse:
    today = get_today_kst()

    if year is None:
        year = today.year
    if month is None:
        month = today.month

    start_date = date(year, month, 1)
    _, last_day = calendar.monthrange(year, month)
    end_date = date(year, month, last_day)

    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user.id,
            DailyProgress.date >= start_date,
            DailyProgress.date <= end_date,
        )
        .order_by(DailyProgress.date)
    )
    progress_list = result.scalars().all()

    return HistoryResponse(
        year=year,
        month=month,
        records=[
            DailyProgressItem(
                date=str(dp.date),
                words_studied=dp.words_studied,
                quizzes_completed=dp.quizzes_completed,
                correct_answers=dp.correct_answers,
                total_answers=dp.total_answers,
                conversation_count=dp.conversation_count,
                study_time_seconds=dp.study_time_seconds,
                xp_earned=dp.xp_earned,
            )
            for dp in progress_list
        ],
    )


def _heatmap_level(words_studied: int) -> int:
    """Calculate heatmap level: 0 (none), 1 (1-9), 2 (10-19), 3 (20+)."""
    if words_studied == 0:
        return 0
    if words_studied < HEATMAP_LEVEL_LOW:
        return 1
    if words_studied < HEATMAP_LEVEL_MID:
        return 2
    return 3


@router.get("/heatmap", response_model=HeatmapResponse, status_code=200)
async def get_heatmap(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    year: int = Query(...),
    month: int | None = Query(default=None),
) -> HeatmapResponse:
    """3-6: Daily study data for heatmap visualization."""
    if month is not None:
        start_date = date(year, month, 1)
        _, last_day = calendar.monthrange(year, month)
        end_date = date(year, month, last_day)
    else:
        start_date = date(year, 1, 1)
        end_date = date(year, 12, 31)

    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user.id,
            DailyProgress.date >= start_date,
            DailyProgress.date <= end_date,
        )
        .order_by(DailyProgress.date)
    )
    progress_map = {dp.date: dp for dp in result.scalars().all()}

    data: list[HeatmapItem] = []
    current = start_date
    while current <= end_date:
        dp = progress_map.get(current)
        words = (dp.words_studied or 0) if dp else 0
        minutes = (dp.study_minutes or 0) if dp else 0
        data.append(
            HeatmapItem(
                date=str(current),
                words_studied=words,
                study_minutes=minutes,
                level=_heatmap_level(words),
            )
        )
        current += timedelta(days=1)

    return HeatmapResponse(data=data)


@router.get("/jlpt-progress", response_model=JlptProgressResponse, status_code=200)
async def get_jlpt_progress(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> JlptProgressResponse:
    """3-7: JLPT level progress across all levels the user has studied."""

    # Batch: total vocab/grammar counts per JLPT level (2 queries instead of N*6)
    vocab_total_result = await db.execute(select(Vocabulary.jlpt_level, func.count(Vocabulary.id)).group_by(Vocabulary.jlpt_level))
    vocab_totals = {row[0]: row[1] for row in vocab_total_result.all()}

    grammar_total_result = await db.execute(select(Grammar.jlpt_level, func.count(Grammar.id)).group_by(Grammar.jlpt_level))
    grammar_totals = {row[0]: row[1] for row in grammar_total_result.all()}

    # Batch: user vocab progress per (jlpt_level, mastered) — single query
    vocab_progress_result = await db.execute(
        select(Vocabulary.jlpt_level, UserVocabProgress.mastered, func.count(UserVocabProgress.id))
        .join(Vocabulary)
        .where(UserVocabProgress.user_id == user.id)
        .group_by(Vocabulary.jlpt_level, UserVocabProgress.mastered)
    )
    vocab_progress: dict[tuple[JlptLevel, bool], int] = {}
    for row in vocab_progress_result.all():
        vocab_progress[(row[0], row[1])] = row[2]

    # Batch: user grammar progress per (jlpt_level, mastered) — single query
    grammar_progress_result = await db.execute(
        select(Grammar.jlpt_level, UserGrammarProgress.mastered, func.count(UserGrammarProgress.id))
        .join(Grammar)
        .where(UserGrammarProgress.user_id == user.id)
        .group_by(Grammar.jlpt_level, UserGrammarProgress.mastered)
    )
    grammar_progress: dict[tuple[JlptLevel, bool], int] = {}
    for row in grammar_progress_result.all():
        grammar_progress[(row[0], row[1])] = row[2]

    levels: list[JlptLevelProgress] = []
    for jlpt in JlptLevel:
        v_total = vocab_totals.get(jlpt, 0)
        g_total = grammar_totals.get(jlpt, 0)

        if v_total == 0 and g_total == 0:
            continue

        v_mastered = vocab_progress.get((jlpt, True), 0)
        v_in_progress = vocab_progress.get((jlpt, False), 0)
        g_mastered = grammar_progress.get((jlpt, True), 0)
        g_in_progress = grammar_progress.get((jlpt, False), 0)

        if v_mastered + v_in_progress + g_mastered + g_in_progress > 0 or jlpt == user.jlpt_level:
            levels.append(
                JlptLevelProgress(
                    level=jlpt.value,
                    vocabulary=JlptProgressStat(total=v_total, mastered=v_mastered, in_progress=v_in_progress),
                    grammar=JlptProgressStat(total=g_total, mastered=g_mastered, in_progress=g_in_progress),
                )
            )

    return JlptProgressResponse(levels=levels)


@router.get("/time-chart", response_model=TimeChartResponse, status_code=200)
async def get_time_chart(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(default=7, ge=1, le=90),
) -> TimeChartResponse:
    """3-8: Daily study time for chart."""
    today = get_today_kst()
    start_date = today - timedelta(days=days - 1)

    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user.id,
            DailyProgress.date >= start_date,
            DailyProgress.date <= today,
        )
        .order_by(DailyProgress.date)
    )
    progress_map = {dp.date: dp for dp in result.scalars().all()}

    data: list[TimeChartItem] = []
    current = start_date
    while current <= today:
        dp = progress_map.get(current)
        data.append(
            TimeChartItem(
                date=str(current),
                minutes=(dp.study_minutes or 0) if dp else 0,
            )
        )
        current += timedelta(days=1)

    return TimeChartResponse(data=data)


@router.get("/volume-chart", response_model=VolumeChartResponse, status_code=200)
async def get_volume_chart(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(default=7, ge=1, le=90),
) -> VolumeChartResponse:
    """3-9: Daily study volume (items studied)."""
    today = get_today_kst()
    start_date = today - timedelta(days=days - 1)

    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user.id,
            DailyProgress.date >= start_date,
            DailyProgress.date <= today,
        )
        .order_by(DailyProgress.date)
    )
    progress_map = {dp.date: dp for dp in result.scalars().all()}

    data: list[VolumeChartItem] = []
    current = start_date
    while current <= today:
        dp = progress_map.get(current)
        data.append(
            VolumeChartItem(
                date=str(current),
                words_studied=(dp.words_studied or 0) if dp else 0,
                grammar_studied=(dp.grammar_studied or 0) if dp else 0,
                sentences_studied=(dp.sentences_studied or 0) if dp else 0,
            )
        )
        current += timedelta(days=1)

    return VolumeChartResponse(data=data)


@router.get("/by-category", response_model=ByCategoryResponse, status_code=200)
async def get_by_category(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ByCategoryResponse:
    """3-10: 7-day breakdown per category."""
    today = get_today_kst()
    start_date = today - timedelta(days=6)

    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user.id,
            DailyProgress.date >= start_date,
            DailyProgress.date <= today,
        )
        .order_by(DailyProgress.date)
    )
    progress_map = {dp.date: dp for dp in result.scalars().all()}

    vocab_daily: list[int] = []
    grammar_daily: list[int] = []
    sentences_daily: list[int] = []

    for i in range(7):
        d = start_date + timedelta(days=i)
        dp = progress_map.get(d)
        vocab_daily.append((dp.words_studied or 0) if dp else 0)
        grammar_daily.append((dp.grammar_studied or 0) if dp else 0)
        sentences_daily.append((dp.sentences_studied or 0) if dp else 0)

    return ByCategoryResponse(
        vocabulary=CategoryStat(total=sum(vocab_daily), daily=vocab_daily),
        grammar=CategoryStat(total=sum(grammar_daily), daily=grammar_daily),
        sentences=CategoryStat(total=sum(sentences_daily), daily=sentences_daily),
    )
