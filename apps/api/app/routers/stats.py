from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.stats import (
    ByCategoryResponse,
    DashboardResponse,
    HeatmapResponse,
    HistoryResponse,
    JlptProgressResponse,
    TimeChartResponse,
    VolumeChartResponse,
)
from app.services.stats_dashboard import get_dashboard_data
from app.services.stats_history import get_history_data
from app.services.stats_jlpt_progress import get_jlpt_progress_data
from app.services.stats_time_series import (
    get_by_category_data,
    get_heatmap_data,
    get_time_chart_data,
    get_volume_chart_data,
)

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
    return await get_history_data(db, user_id=user.id, year=year, month=month)


@router.get("/heatmap", response_model=HeatmapResponse, status_code=200)
async def get_heatmap(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    year: int = Query(...),
    month: int | None = Query(default=None),
) -> HeatmapResponse:
    """3-6: Daily study data for heatmap visualization."""
    return await get_heatmap_data(db, user_id=user.id, year=year, month=month)


@router.get("/jlpt-progress", response_model=JlptProgressResponse, status_code=200)
async def get_jlpt_progress(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> JlptProgressResponse:
    """3-7: JLPT level progress across all levels the user has studied."""
    return await get_jlpt_progress_data(
        db,
        user_id=user.id,
        current_jlpt_level=user.jlpt_level,
    )


@router.get("/time-chart", response_model=TimeChartResponse, status_code=200)
async def get_time_chart(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(default=7, ge=1, le=90),
) -> TimeChartResponse:
    """3-8: Daily study time for chart."""
    return await get_time_chart_data(db, user_id=user.id, days=days)


@router.get("/volume-chart", response_model=VolumeChartResponse, status_code=200)
async def get_volume_chart(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(default=7, ge=1, le=90),
) -> VolumeChartResponse:
    """3-9: Daily study volume (items studied)."""
    return await get_volume_chart_data(db, user_id=user.id, days=days)


@router.get("/by-category", response_model=ByCategoryResponse, status_code=200)
async def get_by_category(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ByCategoryResponse:
    """3-10: 7-day breakdown per category."""
    return await get_by_category_data(db, user_id=user.id)
