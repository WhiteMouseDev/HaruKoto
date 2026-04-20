"""표준 에러 응답 체계.

성공 응답: Bare 유지 (기존 그대로)
에러 응답: {"error": {"code": "...", "message": "...", "details": ...}}
"""

from __future__ import annotations

from enum import StrEnum
from typing import Any

type ErrorDetails = dict[str, Any] | list[Any]


class ErrorCode(StrEnum):
    """API 에러 코드. UPPER_SNAKE_CASE, {DOMAIN}_{REASON} 형식."""

    # Auth
    AUTH_UNAUTHORIZED = "AUTH_UNAUTHORIZED"
    AUTH_TOKEN_EXPIRED = "AUTH_TOKEN_EXPIRED"
    AUTH_FORBIDDEN = "AUTH_FORBIDDEN"

    # Quiz
    QUIZ_SESSION_NOT_FOUND = "QUIZ_SESSION_NOT_FOUND"
    QUIZ_ALREADY_COMPLETED = "QUIZ_ALREADY_COMPLETED"
    QUIZ_QUESTION_NOT_FOUND = "QUIZ_QUESTION_NOT_FOUND"
    QUIZ_NO_CONTENT = "QUIZ_NO_CONTENT"
    QUIZ_SESSION_CREATE_FAILED = "QUIZ_SESSION_CREATE_FAILED"

    # Lesson
    LESSON_NOT_FOUND = "LESSON_NOT_FOUND"
    STAGE_NOT_FOUND = "STAGE_NOT_FOUND"
    STAGE_NO_CONTENT = "STAGE_NO_CONTENT"

    # Chat
    CHAT_NOT_FOUND = "CHAT_NOT_FOUND"
    CHAT_ALREADY_ENDED = "CHAT_ALREADY_ENDED"
    CHAT_UNSUPPORTED_FORMAT = "CHAT_UNSUPPORTED_FORMAT"
    CHAT_FILE_TOO_LARGE = "CHAT_FILE_TOO_LARGE"

    # Content
    SCENARIO_NOT_FOUND = "SCENARIO_NOT_FOUND"
    CHARACTER_NOT_FOUND = "CHARACTER_NOT_FOUND"
    VOCAB_NOT_FOUND = "VOCAB_NOT_FOUND"
    KANA_NOT_FOUND = "KANA_NOT_FOUND"

    # Wordbook
    WORDBOOK_ENTRY_NOT_FOUND = "WORDBOOK_ENTRY_NOT_FOUND"

    # Mission
    MISSION_NOT_FOUND = "MISSION_NOT_FOUND"
    MISSION_NOT_COMPLETED = "MISSION_NOT_COMPLETED"
    MISSION_ALREADY_CLAIMED = "MISSION_ALREADY_CLAIMED"

    # Payment
    PAYMENT_NOT_FOUND = "PAYMENT_NOT_FOUND"
    PAYMENT_INVALID_PLAN = "PAYMENT_INVALID_PLAN"

    # Upload
    UPLOAD_FAILED = "UPLOAD_FAILED"
    UPLOAD_FILE_TOO_LARGE = "UPLOAD_FILE_TOO_LARGE"
    UPLOAD_UNSUPPORTED_FORMAT = "UPLOAD_UNSUPPORTED_FORMAT"

    # TTS
    TTS_GENERATION_FAILED = "TTS_GENERATION_FAILED"
    TTS_IN_PROGRESS = "TTS_IN_PROGRESS"

    # System
    RATE_LIMITED = "RATE_LIMITED"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    SYSTEM_ERROR = "SYSTEM_ERROR"
    RESOURCE_NOT_FOUND = "RESOURCE_NOT_FOUND"


class AppError(Exception):
    """앱 표준 예외. 전역 핸들러가 표준 에러 응답으로 변환."""

    def __init__(
        self,
        code: ErrorCode,
        message: str,
        status_code: int = 400,
        details: ErrorDetails | None = None,
    ) -> None:
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details
        super().__init__(message)
