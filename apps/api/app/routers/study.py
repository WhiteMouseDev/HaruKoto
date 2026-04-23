from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.stats import DailyGoalRequest, DailyGoalResponse
from app.schemas.study import (
    LearnedWordsResponse,
    StudyCapabilitiesResponse,
    StudyStageResponse,
    StudyWrongAnswersResponse,
)
from app.services.study_capabilities import get_study_capabilities_data
from app.services.study_daily_goal import StudyDailyGoalServiceError, update_daily_goal_data
from app.services.study_responses import (
    to_learned_words_response,
    to_study_capabilities_response,
    to_study_stage_responses,
    to_study_wrong_answers_response,
)
from app.services.study_stage_query import get_stages_data
from app.services.study_word_progress import get_learned_words_data, get_study_wrong_answers_data

router = APIRouter(prefix="/api/v1/study", tags=["study"])


@router.get("/learned-words", response_model=LearnedWordsResponse, status_code=200)
async def get_learned_words(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, le=50),
    sort: str = Query(default="recent"),
    search: str = Query(default=""),
    filter_by: str = Query(default="ALL", alias="filter"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LearnedWordsResponse:
    result = await get_learned_words_data(
        db,
        user,
        page=page,
        limit=limit,
        sort=sort,
        search=search,
        filter_by=filter_by,
    )

    return to_learned_words_response(result)


@router.get("/wrong-answers", response_model=StudyWrongAnswersResponse, status_code=200)
async def get_study_wrong_answers(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, le=50),
    sort: str = Query(default="most-wrong"),
    level: str | None = Query(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StudyWrongAnswersResponse:
    result = await get_study_wrong_answers_data(
        db,
        user,
        page=page,
        limit=limit,
        sort=sort,
        level=level,
    )

    return to_study_wrong_answers_response(result)


@router.get("/stages", response_model=list[StudyStageResponse], status_code=200)
async def get_stages(
    category: str = Query(..., description="VOCABULARY, GRAMMAR, or SENTENCE"),
    jlpt_level: str | None = Query(default=None, alias="jlptLevel"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[StudyStageResponse]:
    """카테고리별 스테이지 목록과 유저 진행 상황 조회."""
    stages = await get_stages_data(
        db,
        user,
        category=category,
        jlpt_level=jlpt_level,
    )

    return to_study_stage_responses(stages)


@router.patch("/daily-goal", response_model=DailyGoalResponse, status_code=200)
async def update_daily_goal(
    body: DailyGoalRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DailyGoalResponse:
    """3-12: Update user's daily goal."""
    try:
        result = await update_daily_goal_data(db, user, daily_goal=body.daily_goal)
    except StudyDailyGoalServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return DailyGoalResponse(daily_goal=result.daily_goal)


@router.get("/capabilities", response_model=StudyCapabilitiesResponse, status_code=200)
async def get_capabilities(
    jlpt_level: str | None = Query(default=None, alias="jlptLevel"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StudyCapabilitiesResponse:
    """레벨별 기능 가용성 매트릭스. 모든 진입/가드 화면의 단일 소스."""
    capabilities = await get_study_capabilities_data(
        db,
        user,
        jlpt_level=jlpt_level,
    )

    return to_study_capabilities_response(capabilities)
