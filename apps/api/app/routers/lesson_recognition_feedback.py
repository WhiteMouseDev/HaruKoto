"""Private, read-only feedback for one confirmed lesson choice."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.routers.lesson_submissions import PrivateSubmissionRoute, _error_responses
from app.schemas.lesson import LessonRecognitionFeedbackRequest, LessonRecognitionFeedbackResponse, LessonSubmissionErrorResponse
from app.services.lesson_command import LessonServiceError
from app.services.lesson_recognition_feedback import grade_lesson_recognition
from app.services.lesson_submission import NO_STORE_HEADERS

router = APIRouter(route_class=PrivateSubmissionRoute)


@router.post(
    "/{lesson_id}/questions/{question_order}/feedback",
    response_model=LessonRecognitionFeedbackResponse,
    status_code=200,
    responses={
        **_error_responses((401, 403, 422)),
        400: {"model": LessonSubmissionErrorResponse, "description": "이해 체크에서 채점할 수 없는 문항 또는 잘못된 답안"},
        404: {"model": LessonSubmissionErrorResponse, "description": "공개 레슨 또는 문항을 찾을 수 없음"},
        409: {"model": LessonSubmissionErrorResponse, "description": "현재 공개된 레슨과 채점 버전이 다름"},
    },
)
async def get_recognition_feedback(
    lesson_id: UUID,
    question_order: Annotated[int, Path(ge=1)],
    body: LessonRecognitionFeedbackRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LessonRecognitionFeedbackResponse:
    try:
        return await grade_lesson_recognition(db, user, lesson_id=lesson_id, question_order=question_order, request=body)
    except LessonServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=NO_STORE_HEADERS) from exc
