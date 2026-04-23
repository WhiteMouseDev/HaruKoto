from __future__ import annotations

import calendar
import uuid
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import DailyProgress
from app.schemas.stats import (
    ByCategoryResponse,
    CategoryStat,
    HeatmapItem,
    HeatmapResponse,
    TimeChartItem,
    TimeChartResponse,
    VolumeChartItem,
    VolumeChartResponse,
)
from app.utils.date import get_today_kst

HEATMAP_LEVEL_LOW = 10
HEATMAP_LEVEL_MID = 20
BY_CATEGORY_DAYS = 7


async def get_heatmap_data(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    year: int,
    month: int | None,
) -> HeatmapResponse:
    start_date, end_date = _year_or_month_range(year=year, month=month)
    progress_map = await _load_progress_by_day(
        db,
        user_id=user_id,
        start_date=start_date,
        end_date=end_date,
    )

    return HeatmapResponse(data=[_build_heatmap_item(day, progress_map.get(day)) for day in _date_range(start_date, end_date)])


async def get_time_chart_data(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    days: int,
) -> TimeChartResponse:
    start_date, end_date = _recent_range(days=days)
    progress_map = await _load_progress_by_day(
        db,
        user_id=user_id,
        start_date=start_date,
        end_date=end_date,
    )

    return TimeChartResponse(
        data=[
            TimeChartItem(
                date=str(day),
                minutes=_progress_value(progress_map.get(day), "study_minutes"),
            )
            for day in _date_range(start_date, end_date)
        ]
    )


async def get_volume_chart_data(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    days: int,
) -> VolumeChartResponse:
    start_date, end_date = _recent_range(days=days)
    progress_map = await _load_progress_by_day(
        db,
        user_id=user_id,
        start_date=start_date,
        end_date=end_date,
    )

    return VolumeChartResponse(
        data=[
            VolumeChartItem(
                date=str(day),
                words_studied=_progress_value(progress_map.get(day), "words_studied"),
                grammar_studied=_progress_value(progress_map.get(day), "grammar_studied"),
                sentences_studied=_progress_value(progress_map.get(day), "sentences_studied"),
            )
            for day in _date_range(start_date, end_date)
        ]
    )


async def get_by_category_data(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
) -> ByCategoryResponse:
    start_date, end_date = _recent_range(days=BY_CATEGORY_DAYS)
    progress_map = await _load_progress_by_day(
        db,
        user_id=user_id,
        start_date=start_date,
        end_date=end_date,
    )

    vocab_daily: list[int] = []
    grammar_daily: list[int] = []
    sentences_daily: list[int] = []

    for day in _date_range(start_date, end_date):
        progress = progress_map.get(day)
        vocab_daily.append(_progress_value(progress, "words_studied"))
        grammar_daily.append(_progress_value(progress, "grammar_studied"))
        sentences_daily.append(_progress_value(progress, "sentences_studied"))

    return ByCategoryResponse(
        vocabulary=_category_stat(vocab_daily),
        grammar=_category_stat(grammar_daily),
        sentences=_category_stat(sentences_daily),
    )


def _year_or_month_range(*, year: int, month: int | None) -> tuple[date, date]:
    if month is None:
        return date(year, 1, 1), date(year, 12, 31)

    _, last_day = calendar.monthrange(year, month)
    return date(year, month, 1), date(year, month, last_day)


def _recent_range(*, days: int) -> tuple[date, date]:
    today = get_today_kst()
    return today - timedelta(days=days - 1), today


async def _load_progress_by_day(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    start_date: date,
    end_date: date,
) -> dict[date, DailyProgress]:
    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user_id,
            DailyProgress.date >= start_date,
            DailyProgress.date <= end_date,
        )
        .order_by(DailyProgress.date)
    )
    return {progress.date: progress for progress in result.scalars().all()}


def _date_range(start_date: date, end_date: date) -> list[date]:
    return [start_date + timedelta(days=offset) for offset in range((end_date - start_date).days + 1)]


def _build_heatmap_item(day: date, progress: DailyProgress | None) -> HeatmapItem:
    words = _progress_value(progress, "words_studied")
    return HeatmapItem(
        date=str(day),
        words_studied=words,
        study_minutes=_progress_value(progress, "study_minutes"),
        level=_heatmap_level(words),
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


def _progress_value(
    progress: DailyProgress | None,
    field_name: str,
) -> int:
    if progress is None:
        return 0
    value = getattr(progress, field_name)
    return value or 0


def _category_stat(daily: list[int]) -> CategoryStat:
    return CategoryStat(total=sum(daily), daily=daily)
