"""전역 에러 핸들러. 모든 에러를 표준 형식으로 변환."""

from __future__ import annotations

import uuid

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.exceptions import AppError, ErrorCode


def _error_response(
    status_code: int,
    code: str,
    message: str,
    details: dict | list | None = None,
    request_id: str | None = None,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "error": {
                "code": code,
                "message": message,
                "details": details,
            },
        },
        headers={"X-Request-Id": request_id or str(uuid.uuid4())},
    )


def _get_request_id(request: Request) -> str:
    return request.headers.get("X-Request-Id") or str(uuid.uuid4())


async def app_exception_handler(request: Request, exc: AppError) -> JSONResponse:
    """AppError → 표준 에러 응답."""
    return _error_response(
        status_code=exc.status_code,
        code=exc.code.value,
        message=exc.message,
        details=exc.details,
        request_id=_get_request_id(request),
    )


# HTTPException detail → 에러 코드 매핑 (레거시 호환)
_STATUS_TO_CODE: dict[int, str] = {
    400: ErrorCode.VALIDATION_ERROR,
    401: ErrorCode.AUTH_UNAUTHORIZED,
    403: ErrorCode.AUTH_FORBIDDEN,
    404: ErrorCode.RESOURCE_NOT_FOUND,
    409: ErrorCode.SYSTEM_ERROR,
    429: ErrorCode.RATE_LIMITED,
    500: ErrorCode.SYSTEM_ERROR,
    502: ErrorCode.SYSTEM_ERROR,
}


async def http_exception_handler(
    request: Request,
    exc: StarletteHTTPException,
) -> JSONResponse:
    """기존 HTTPException → 표준 에러 응답으로 래핑."""
    code = _STATUS_TO_CODE.get(exc.status_code, ErrorCode.SYSTEM_ERROR)
    message = exc.detail if isinstance(exc.detail, str) else str(exc.detail)

    headers = {"X-Request-Id": _get_request_id(request)}
    if hasattr(exc, "headers") and exc.headers:
        headers.update(exc.headers)

    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": code,
                "message": message,
                "details": None,
            },
        },
        headers=headers,
    )


async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    """Pydantic 422 → 표준 에러 응답."""
    return _error_response(
        status_code=422,
        code=ErrorCode.VALIDATION_ERROR,
        message="요청 검증에 실패했습니다",
        details=exc.errors(),
        request_id=_get_request_id(request),
    )


async def unhandled_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    """미처리 예외 → SYSTEM_ERROR."""
    import logging

    logging.exception("Unhandled exception: %s", exc)
    return _error_response(
        status_code=500,
        code=ErrorCode.SYSTEM_ERROR,
        message="서버 내부 오류가 발생했습니다",
        request_id=_get_request_id(request),
    )


def register_error_handlers(app: FastAPI) -> None:
    """앱에 전역 에러 핸들러 등록."""
    app.add_exception_handler(AppError, app_exception_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
