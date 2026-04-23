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
    UserGrammarProgress,
    UserVocabProgress,
    Vocabulary,
)
from app.models.enums import JlptLevel
from app.models.user import User
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
    TimeChartItem,
    TimeChartResponse,
    VolumeChartItem,
    VolumeChartResponse,
)
from app.services.stats_dashboard import get_dashboard_data
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
    return await get_dashboard_data(db, user)


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
