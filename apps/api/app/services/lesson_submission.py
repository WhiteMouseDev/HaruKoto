"""Immutable, account-scoped lesson receipts and atomic submission retries."""

from __future__ import annotations

import hashlib
import json
import logging
from datetime import UTC, datetime
from uuid import UUID

from pydantic import ValidationError
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import LessonSubmission
from app.models.user import User
from app.schemas.lesson import LessonSubmissionRequest, LessonSubmissionResponse, LessonSubmitResponse
from app.services.lesson_command import LessonServiceError, apply_lesson_attempt
from app.services.study_day_recording import canonical_study_instant, lock_study_user, record_lesson_study_day

logger = logging.getLogger(__name__)

FINGERPRINT_VERSION = 1
RESPONSE_SCHEMA_VERSION = 1
# Source-controlled activation follows the compatibility deployment and writer drain.
# This is deliberately not an environment or runtime configuration contract.
LESSON_STUDY_DAY_RECOGNITION_ENABLED = False
NO_STORE_HEADERS = {"Cache-Control": "private, no-store"}
UNCONFIRMED_DETAIL = "제출 결과를 아직 확인할 수 없습니다. 같은 제출로 다시 확인해주세요"


def assert_submission_owner(user: User, expected_user_id: UUID) -> None:
    if user.id != expected_user_id:
        raise LessonServiceError(status_code=403, detail="제출한 계정으로 로그인한 뒤 다시 확인해주세요")


def submission_fingerprint(lesson_id: UUID, request: LessonSubmissionRequest) -> str:
    # Object keys/defaults are canonical; answer/token arrays and response times
    # are deliberately NOT sorted, deduplicated, trimmed or recomputed.
    canonical = {
        "version": FINGERPRINT_VERSION,
        "userId": str(request.expected_user_id),
        "lessonId": str(lesson_id),
        "answers": [answer.model_dump(mode="json", by_alias=True) for answer in request.answers],
    }
    payload = json.dumps(canonical, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _read_receipt(receipt: LessonSubmission) -> LessonSubmissionResponse:
    if receipt.fingerprint_version != FINGERPRINT_VERSION or receipt.response_schema_version != RESPONSE_SCHEMA_VERSION:
        raise LessonServiceError(status_code=503, detail=UNCONFIRMED_DETAIL)
    try:
        result = LessonSubmissionResponse.model_validate(receipt.response_body)
        if (
            result.submission_id != receipt.submission_id
            or result.processed_at.utcoffset() is None
            or receipt.processed_at.utcoffset() is None
            or result.processed_at != receipt.processed_at
        ):
            raise ValueError("Receipt identity or timestamp mismatch")
    except (ValidationError, ValueError, TypeError) as exc:
        # Never attempt regrading or repairing a corrupt/unknown stored result.
        logger.error("Invalid lesson submission receipt", exc_info=True)
        raise LessonServiceError(status_code=503, detail=UNCONFIRMED_DETAIL) from exc
    return result


async def get_lesson_submission(
    db: AsyncSession,
    user: User,
    *,
    lesson_id: UUID,
    submission_id: UUID,
    expected_user_id: UUID,
) -> LessonSubmissionResponse:
    assert_submission_owner(user, expected_user_id)
    receipt = await db.get(LessonSubmission, (user.id, submission_id))
    if receipt is None or receipt.lesson_id != lesson_id:
        # Absence is not proof that an in-flight POST will not commit later.
        raise LessonServiceError(status_code=404, detail="아직 확인할 수 있는 제출 결과가 없습니다")
    return _read_receipt(receipt)


def _replay(receipt: LessonSubmission, lesson_id: UUID, fingerprint: str) -> LessonSubmissionResponse:
    result = _read_receipt(receipt)
    if receipt.lesson_id != lesson_id or receipt.request_fingerprint != fingerprint:
        raise LessonServiceError(status_code=409, detail="같은 제출의 답안이 달라졌습니다. 저장된 제출 결과를 확인해주세요")
    return result


async def submit_lesson_once(
    db: AsyncSession,
    user: User,
    *,
    lesson_id: UUID,
    request: LessonSubmissionRequest,
) -> LessonSubmissionResponse:
    assert_submission_owner(user, request.expected_user_id)
    fingerprint = submission_fingerprint(lesson_id, request)
    try:
        receipt = await db.get(LessonSubmission, (user.id, request.submission_id))
        if receipt is not None:
            return _replay(receipt, lesson_id, fingerprint)

        # Auth may already have started a transaction. Do not nest db.begin().
        # Bound only this new protocol's transaction, never global DB settings.
        await db.execute(text("SET LOCAL lock_timeout = '2s'"))
        await db.execute(text("SET LOCAL statement_timeout = '15s'"))
        await lock_study_user(db, user)
        receipt = await db.get(LessonSubmission, (user.id, request.submission_id))
        if receipt is not None:
            return _replay(receipt, lesson_id, fingerprint)

        # Query current lesson only after historical receipt recovery. A deleted
        # or unpublished source does not remove an already committed result.
        applied = await apply_lesson_attempt(db, user, lesson_id=lesson_id, answers=list(request.answers))
        processed_at = canonical_study_instant(datetime.now(UTC))
        if LESSON_STUDY_DAY_RECOGNITION_ENABLED and applied.status == "COMPLETED":
            await record_lesson_study_day(db, user, processed_at=processed_at)
        result = LessonSubmissionResponse(
            submission_id=request.submission_id,
            processed_at=processed_at,
            result=LessonSubmitResponse.model_validate(applied),
        )
        db.add(
            LessonSubmission(
                user_id=user.id,
                submission_id=request.submission_id,
                lesson_id=lesson_id,
                request_fingerprint=fingerprint,
                fingerprint_version=FINGERPRINT_VERSION,
                response_schema_version=RESPONSE_SCHEMA_VERSION,
                response_body=result.model_dump(mode="json", by_alias=True),
                processed_at=result.processed_at,
            )
        )
        await db.commit()
        return result
    except LessonServiceError:
        await db.rollback()
        raise
    except Exception as exc:
        # Includes a failed/unknown COMMIT: never emit a new ID or reapply an
        # unkeyed attempt. A later GET/POST resolves the same completed receipt.
        await db.rollback()
        logger.warning("Lesson submission transaction failed; retry same submission", exc_info=True)
        raise LessonServiceError(status_code=503, detail=UNCONFIRMED_DETAIL) from exc
