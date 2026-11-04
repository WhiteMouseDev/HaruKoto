"""Exactly-once card progress effects, without changing legacy progress policy."""

from __future__ import annotations

import logging
import re
from datetime import UTC, datetime

from pydantic import ValidationError
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import KanaCharacter, StudyActivityReceipt
from app.models.user import User
from app.schemas.kana import KanaProgressActivityRequest, KanaProgressActivityResponse
from app.services.kana_daily_progress import apply_daily_progress_increment
from app.services.kana_progress import build_kana_progress_upsert_statement
from app.services.lesson_study_activity import activity_fingerprint
from app.services.study_day_recording import canonical_study_instant, lock_study_user
from app.utils.date import study_date_kst

logger = logging.getLogger(__name__)
SOURCE_KIND = "KANA_CARD_PROGRESS"
UNCONFIRMED = "문자 학습 저장 여부를 확인하지 못했어요. 같은 기록으로 다시 확인해주세요."


class KanaProgressActivityError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


def _content_version(request: KanaProgressActivityRequest) -> str:
    # Card acknowledgement does not grade content or depend on audio/typography.
    return activity_fingerprint({"version": 1, "sourceKind": SOURCE_KIND, "kanaId": str(request.kana_id)})


def _read_receipt(
    receipt: StudyActivityReceipt,
    request: KanaProgressActivityRequest,
    fingerprint: str,
) -> KanaProgressActivityResponse:
    if receipt.source_kind != SOURCE_KIND or receipt.source_scope_id != request.kana_id:
        raise KanaProgressActivityError(409, "같은 문자 학습 기록의 내용이 달라졌어요. 원래 기록으로 확인해주세요.")
    if not isinstance(receipt.request_fingerprint, str) or re.fullmatch(r"[0-9a-f]{64}", receipt.request_fingerprint) is None:
        raise KanaProgressActivityError(503, UNCONFIRMED)
    if receipt.request_fingerprint != fingerprint:
        # The request consists only of owner/activity/kana IDs. After the
        # owner + receipt PK + scope checks these cannot legitimately differ;
        # a different hash is damaged evidence, not a changed user selection.
        raise KanaProgressActivityError(503, UNCONFIRMED)
    try:
        if (
            receipt.fingerprint_version != 1
            or receipt.response_schema_version != 1
            or receipt.user_id != request.expected_user_id
            or receipt.activity_id != request.activity_id
            or receipt.attempt_id != request.activity_id
            or receipt.source_item_key != str(request.kana_id)
            or receipt.content_version != _content_version(request)
            or not isinstance(receipt.response_body, dict)
            or receipt.response_body.get("ok") is not True
        ):
            raise ValueError("Invalid card progress receipt")
        result = KanaProgressActivityResponse.model_validate(receipt.response_body)
        if (
            result.activity_id != request.activity_id
            or result.processed_at.utcoffset() is None
            or receipt.processed_at.utcoffset() is None
            or result.processed_at != receipt.processed_at
            or study_date_kst(receipt.processed_at) != receipt.study_date
        ):
            raise ValueError("Card progress receipt identity mismatch")
        return result
    except (ValueError, TypeError, ValidationError) as exc:
        raise KanaProgressActivityError(503, UNCONFIRMED) from exc


async def record_kana_progress_activity(db: AsyncSession, user: User, request: KanaProgressActivityRequest) -> KanaProgressActivityResponse:
    if request.expected_user_id != user.id:
        raise KanaProgressActivityError(403, "학습한 계정으로 로그인한 뒤 다시 확인해주세요.")
    fingerprint = activity_fingerprint({"version": 1, "sourceKind": SOURCE_KIND, **request.model_dump(mode="json", by_alias=True)})
    try:
        await db.execute(text("SET LOCAL lock_timeout = '2s'"))
        await db.execute(text("SET LOCAL statement_timeout = '15s'"))
        await lock_study_user(db, user)
        receipt = await db.get(StudyActivityReceipt, (user.id, request.activity_id))
        if receipt is not None:
            # Accepted evidence survives subsequent deletion/editing of a source.
            return _read_receipt(receipt, request, fingerprint)
        if await db.get(KanaCharacter, request.kana_id) is None:
            raise KanaProgressActivityError(404, "학습할 문자를 찾을 수 없습니다.")
        now = canonical_study_instant(datetime.now(UTC))
        result = KanaProgressActivityResponse(ok=True, activity_id=request.activity_id, processed_at=now)
        await db.execute(build_kana_progress_upsert_statement(user_id=user.id, kana_id=request.kana_id, reviewed_at=now))
        # Preserve /progress effects exactly once. This deliberately does not
        # award XP, mark a quiz answer, or update the user's streak/SRS/goal.
        await apply_daily_progress_increment(db, user_id=user.id, today=study_date_kst(now), kana_learned=1)
        db.add(
            StudyActivityReceipt(
                user_id=user.id,
                activity_id=request.activity_id,
                source_kind=SOURCE_KIND,
                source_scope_id=request.kana_id,
                attempt_id=request.activity_id,
                source_item_key=str(request.kana_id),
                content_version=_content_version(request),
                request_fingerprint=fingerprint,
                fingerprint_version=1,
                response_schema_version=1,
                response_body=result.model_dump(mode="json", by_alias=True),
                processed_at=now,
                study_date=study_date_kst(now),
            )
        )
        await db.commit()
        return result
    except KanaProgressActivityError:
        await db.rollback()
        raise
    except Exception as exc:
        await db.rollback()
        # Do not log request bodies, tokens, or database parameter values.
        logger.warning("Card progress transaction unconfirmed; retain activity ID (%s)", type(exc).__name__)
        raise KanaProgressActivityError(503, UNCONFIRMED) from exc
