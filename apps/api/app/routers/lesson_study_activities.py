"""Private lesson answer-activity receipts; no grading or learning rewards."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import UUID4
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.routers.lesson_submissions import PrivateSubmissionRoute, _error_responses
from app.schemas.study_activity import LessonStudyActivityRequest, LessonStudyActivityResponse
from app.services.lesson_command import LessonServiceError
from app.services.lesson_study_activity import get_lesson_activity, record_lesson_activity
from app.services.lesson_submission import NO_STORE_HEADERS

router = APIRouter(route_class=PrivateSubmissionRoute)


@router.post(
    "/{lesson_id}/study-activities",
    response_model=LessonStudyActivityResponse,
    status_code=200,
    responses=_error_responses((400, 401, 403, 404, 409, 422, 503)),
)
async def create_activity(
    lesson_id: UUID, body: LessonStudyActivityRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> LessonStudyActivityResponse:
    try:
        return await record_lesson_activity(db, user, lesson_id=lesson_id, request=body)
    except LessonServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=NO_STORE_HEADERS) from exc


@router.get(
    "/{lesson_id}/study-activities/{activity_id}",
    response_model=LessonStudyActivityResponse,
    status_code=200,
    responses=_error_responses((401, 403, 404, 422, 503)),
)
async def read_activity(
    lesson_id: UUID,
    activity_id: UUID4,
    expected_user_id: Annotated[UUID, Query(alias="expectedUserId")],
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LessonStudyActivityResponse:
    try:
        return await get_lesson_activity(db, user, lesson_id=lesson_id, activity_id=activity_id, expected_user_id=expected_user_id)
    except LessonServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=NO_STORE_HEADERS) from exc
