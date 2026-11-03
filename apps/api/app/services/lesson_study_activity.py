"""Immutable answer-activity receipts, separate from grading and final submissions."""

from __future__ import annotations

import hashlib
import json
import logging
from collections import Counter
from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from pydantic import ValidationError
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.content import Vocabulary
from app.models.lesson import Lesson
from app.models.study_activity import StudyActivityReceipt
from app.models.user import User
from app.schemas.lesson import LessonContent
from app.schemas.study_activity import LessonStudyActivityRequest, LessonStudyActivityResponse
from app.services import study_day_recording
from app.services.lesson_command import LessonServiceError
from app.services.lesson_submission import assert_submission_owner
from app.utils.date import study_date_kst

logger = logging.getLogger(__name__)
RECEIPT_VERSION = 1
UNCONFIRMED = "학습일 저장 결과를 아직 확인할 수 없습니다. 같은 기록으로 다시 확인해주세요"


def activity_fingerprint(payload: dict[str, Any]) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode()).hexdigest()


def lesson_content_version(content: LessonContent, vocabularies: list[dict[str, str]], lesson_id: UUID) -> str:
    # Public assessment identity only: never hash answer keys or volatile audio/progress.
    return activity_fingerprint(
        {
            "version": 1,
            "lessonId": str(lesson_id),
            "questions": [q.model_dump(mode="json", include={"order", "type", "prompt", "options", "tokens"}) for q in content.questions],
            "vocabulary": vocabularies,
        }
    )


async def _activity_source(db: AsyncSession, lesson_id: UUID) -> tuple[LessonContent, list[dict[str, str]], str]:
    lesson = await db.scalar(
        select(Lesson).where(Lesson.id == lesson_id, Lesson.is_published.is_(True)).options(selectinload(Lesson.item_links))
    )
    if lesson is None:
        raise LessonServiceError(status_code=404, detail="레슨을 찾을 수 없습니다")
    content = LessonContent.model_validate(lesson.content_jsonb or {})
    ids = [link.vocabulary_id for link in sorted(lesson.item_links, key=lambda x: x.item_order) if link.item_type == "WORD"]
    found = list((await db.scalars(select(Vocabulary).where(Vocabulary.id.in_([item for item in ids if item])))).all())
    by_id = {v.id: v for v in found}
    ordered = list(dict.fromkeys(item for item in ids if item in by_id))
    words = [
        {"id": str(by_id[item].id), "word": by_id[item].word, "reading": by_id[item].reading, "meaningKo": by_id[item].meaning_ko}
        for item in ordered
    ]
    return content, words, lesson_content_version(content, words, lesson_id)


def validate_lesson_activity(request: LessonStudyActivityRequest, content: LessonContent, words: list[dict[str, str]]) -> str:
    invalid = LessonServiceError(status_code=400, detail="레슨에서 유효한 답안을 확정한 뒤 다시 시도해주세요")
    if request.kind == "MATCHING":
        ids = {item["id"] for item in words}
        if str(request.answer.left_vocabulary_id) not in ids or str(request.answer.right_vocabulary_id) not in ids:
            raise invalid
        return f"match:{request.answer.left_vocabulary_id}"
    question = next((q for q in content.questions if q.order == request.answer.question_order), None)
    if question is None:
        raise invalid
    if request.kind == "RECOGNITION":
        if question.type not in {"VOCAB_MCQ", "CONTEXT_CLOZE"} or request.answer.selected_answer not in {
            o.id for o in question.options or []
        }:
            raise invalid
    else:
        tokens = question.tokens or []
        distractors = {item["word"] for item in words if item["word"].strip() and item["word"] not in tokens}
        submitted = Counter(request.answer.submitted_order)
        allowed = Counter(tokens) + Counter(dict.fromkeys(distractors, 1))
        if (
            question.type != "SENTENCE_REORDER"
            or not tokens
            or len(request.answer.submitted_order) != len(tokens)
            or not submitted <= allowed
            or len(set(submitted) & distractors) > 3
        ):
            raise invalid
    return f"question:{question.order}"


def _read_activity(receipt: StudyActivityReceipt) -> LessonStudyActivityResponse:
    try:
        if receipt.fingerprint_version != 1 or receipt.response_schema_version != RECEIPT_VERSION:
            raise ValueError("Unsupported activity receipt")
        result = LessonStudyActivityResponse.model_validate(receipt.response_body)
        if (
            result.activity_id != receipt.activity_id
            or result.processed_at.utcoffset() is None
            or result.processed_at != receipt.processed_at
            or result.study_date != receipt.study_date
            or study_date_kst(result.processed_at) != result.study_date
        ):
            raise ValueError("Activity receipt identity mismatch")
        return result
    except (ValueError, ValidationError, TypeError) as exc:
        raise LessonServiceError(status_code=503, detail=UNCONFIRMED) from exc


async def get_lesson_activity(
    db: AsyncSession, user: User, *, lesson_id: UUID, activity_id: UUID, expected_user_id: UUID
) -> LessonStudyActivityResponse:
    assert_submission_owner(user, expected_user_id)
    receipt = await db.get(StudyActivityReceipt, (user.id, activity_id))
    if receipt is None or receipt.source_scope_id != lesson_id or receipt.source_kind != "LESSON_ANSWER":
        raise LessonServiceError(status_code=404, detail="아직 확인할 수 있는 학습일 기록이 없습니다")
    return _read_activity(receipt)


def _replay(receipt: StudyActivityReceipt, lesson_id: UUID, fingerprint: str) -> LessonStudyActivityResponse:
    if receipt.source_kind != "LESSON_ANSWER" or receipt.source_scope_id != lesson_id or receipt.request_fingerprint != fingerprint:
        raise LessonServiceError(status_code=409, detail="같은 학습일 기록의 내용이 달라졌습니다. 원래 기록을 확인해주세요")
    return _read_activity(receipt)


async def record_lesson_activity(
    db: AsyncSession, user: User, *, lesson_id: UUID, request: LessonStudyActivityRequest
) -> LessonStudyActivityResponse:
    assert_submission_owner(user, request.expected_user_id)
    fingerprint = activity_fingerprint({"version": 1, "lessonId": str(lesson_id), **request.model_dump(mode="json", by_alias=True)})
    try:
        receipt = await db.get(StudyActivityReceipt, (user.id, request.activity_id))
        if receipt is not None:
            return _replay(receipt, lesson_id, fingerprint)
        if not study_day_recording.ANSWERED_STUDY_DAY_RECOGNITION_ENABLED:
            raise LessonServiceError(status_code=503, detail="학습일 저장을 준비하고 있어요. 잠시 후 같은 기록으로 다시 확인해주세요")
        await db.execute(text("SET LOCAL lock_timeout = '2s'"))
        await db.execute(text("SET LOCAL statement_timeout = '15s'"))
        await study_day_recording.lock_study_user(db, user)
        receipt = await db.get(StudyActivityReceipt, (user.id, request.activity_id))
        if receipt is not None:
            return _replay(receipt, lesson_id, fingerprint)
        content, words, version = await _activity_source(db, lesson_id)
        if request.content_version != version:
            raise LessonServiceError(status_code=409, detail="레슨 내용이 변경되어 이 답변의 학습일을 확인할 수 없습니다")
        item_key = validate_lesson_activity(request, content, words)
        now = study_day_recording.canonical_study_instant(datetime.now(UTC))
        result = LessonStudyActivityResponse(activity_id=request.activity_id, processed_at=now, study_date=study_date_kst(now))
        await study_day_recording.record_answered_study_day(db, user, processed_at=now)
        db.add(
            StudyActivityReceipt(
                user_id=user.id,
                activity_id=request.activity_id,
                source_kind="LESSON_ANSWER",
                source_scope_id=lesson_id,
                attempt_id=request.attempt_id,
                source_item_key=item_key,
                content_version=version,
                request_fingerprint=fingerprint,
                fingerprint_version=1,
                response_schema_version=1,
                response_body=result.model_dump(mode="json", by_alias=True),
                processed_at=now,
                study_date=result.study_date,
            )
        )
        await db.commit()
        return result
    except LessonServiceError:
        await db.rollback()
        raise
    except Exception as exc:
        await db.rollback()
        logger.warning("Activity transaction failed; retain activity ID", exc_info=True)
        raise LessonServiceError(status_code=503, detail=UNCONFIRMED) from exc
