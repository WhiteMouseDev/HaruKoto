from __future__ import annotations

import calendar
import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import DailyProgress
from app.schemas.stats import DailyProgressItem, HistoryResponse
from app.utils.date import get_today_kst


async def get_history_data(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    year: int | None,
    month: int | None,
) -> HistoryResponse:
    target_year, target_month = _resolve_year_month(year=year, month=month)
    start_date, end_date = _month_range(year=target_year, month=target_month)
    progress_list = await _load_monthly_progress(
        db,
        user_id=user_id,
        start_date=start_date,
        end_date=end_date,
    )

    return HistoryResponse(
        year=target_year,
        month=target_month,
        records=[_build_daily_progress_item(progress) for progress in progress_list],
    )


def _resolve_year_month(
    *,
    year: int | None,
    month: int | None,
) -> tuple[int, int]:
    today = get_today_kst()
    return year if year is not None else today.year, month if month is not None else today.month


def _month_range(*, year: int, month: int) -> tuple[date, date]:
    _, last_day = calendar.monthrange(year, month)
    return date(year, month, 1), date(year, month, last_day)


async def _load_monthly_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    start_date: date,
    end_date: date,
) -> list[DailyProgress]:
    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user_id,
            DailyProgress.date >= start_date,
            DailyProgress.date <= end_date,
        )
        .order_by(DailyProgress.date)
    )
    return list(result.scalars().all())


def _build_daily_progress_item(progress: DailyProgress) -> DailyProgressItem:
    return DailyProgressItem(
        date=str(progress.date),
        words_studied=progress.words_studied,
        quizzes_completed=progress.quizzes_completed,
        correct_answers=progress.correct_answers,
        total_answers=progress.total_answers,
        conversation_count=progress.conversation_count,
        study_time_seconds=progress.study_time_seconds,
        xp_earned=progress.xp_earned,
    )
