"""Account-scoped idempotent lesson submission API, separate from legacy submit."""

from collections.abc import Callable, Coroutine
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.routing import APIRoute
from pydantic import UUID4
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.db.session import get_db
from app.dependencies import get_current_user
from app.error_handlers import app_exception_handler, unhandled_exception_handler, validation_exception_handler
from app.exceptions import AppError
from app.models.user import User
from app.schemas.lesson import LessonSubmissionErrorResponse, LessonSubmissionRequest, LessonSubmissionResponse
from app.services.lesson_command import LessonServiceError
from app.services.lesson_submission import NO_STORE_HEADERS, get_lesson_submission, submit_lesson_once


class PrivateSubmissionRoute(APIRoute):
    """Never cache personal results, absent receipts or failed auth/validation."""

    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        original = super().get_route_handler()

        async def handler(request: Request) -> Response:
            try:
                response = await original(request)
            except StarletteHTTPException as exc:
                exc.headers = {**(exc.headers or {}), **NO_STORE_HEADERS}
                raise
            except RequestValidationError as exc:
                response = await validation_exception_handler(request, exc)
            except AppError as exc:
                response = await app_exception_handler(request, exc)
            except Exception as exc:
                response = await unhandled_exception_handler(request, exc)
            response.headers.update(NO_STORE_HEADERS)
            return response

        return handler


router = APIRouter(route_class=PrivateSubmissionRoute)

_ERROR_DESCRIPTIONS = {
    400: "답안 검증 실패. 같은 제출의 답안을 자동 변경하지 않음",
    401: "원래 계정 인증 회복 후 같은 제출 ID로 조회/재시도",
    403: "원래 계정과 인증 계정 불일치 또는 접근 불가. 쓰기 없음",
    404: "대상 없음. 진행 중 POST의 미처리를 증명하지 않음",
    409: "같은 제출 ID에 다른 레슨/답안/순서/응답 시간. 쓰기 없음",
    422: "요청 구조 검증 실패",
    500: "기존 SRS 처리 실패. 원자적으로 롤백하고 같은 제출 ID 유지",
    503: "일시 장애 또는 결과 불명. 같은 제출 ID로 재확인",
}


def _error_responses(statuses: tuple[int, ...]) -> dict[int | str, dict[str, Any]]:
    return {
        status: {
            "model": LessonSubmissionErrorResponse,
            "description": _ERROR_DESCRIPTIONS[status],
            "headers": {"Cache-Control": {"schema": {"type": "string"}, "description": "private, no-store"}},
        }
        for status in statuses
    }


@router.post(
    "/{lesson_id}/submissions",
    response_model=LessonSubmissionResponse,
    status_code=200,
    responses=_error_responses((400, 401, 403, 404, 409, 422, 500, 503)),
)
async def create_lesson_submission(
    lesson_id: UUID,
    body: LessonSubmissionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LessonSubmissionResponse:
    try:
        return await submit_lesson_once(db, user, lesson_id=lesson_id, request=body)
    except LessonServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=NO_STORE_HEADERS) from exc


@router.get(
    "/{lesson_id}/submissions/{submission_id}",
    response_model=LessonSubmissionResponse,
    status_code=200,
    responses=_error_responses((401, 403, 404, 422, 500, 503)),
)
async def read_lesson_submission(
    lesson_id: UUID,
    submission_id: UUID4,
    expected_user_id: Annotated[UUID, Query(alias="expectedUserId")],
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LessonSubmissionResponse:
    try:
        return await get_lesson_submission(db, user, lesson_id=lesson_id, submission_id=submission_id, expected_user_id=expected_user_id)
    except LessonServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail, headers=NO_STORE_HEADERS) from exc
