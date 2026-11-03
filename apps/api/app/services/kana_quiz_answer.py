from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, cast
from uuid import uuid4

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizSession, UserKanaProgress
from app.models.enums import QuizType
from app.models.study_activity import StudyActivityReceipt
from app.models.user import User
from app.schemas.kana import KanaQuizAnswerRequest, KanaQuizAnswerResponse
from app.services.lesson_study_activity import activity_fingerprint
from app.services.study_day_recording import canonical_study_instant, lock_study_user, record_answered_study_day
from app.utils.date import study_date_kst

KANA_MASTERY_STREAK = 3
QuestionPayload = dict[str, Any]


class KanaQuizAnswerServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class KanaQuizAnswerResult:
    is_correct: bool
    correct_option_id: str


async def _submit_kana_quiz_answer(
    db: AsyncSession,
    user: User,
    body: KanaQuizAnswerRequest,
) -> KanaQuizAnswerResult:
    await lock_study_user(db, user)
    fingerprint = activity_fingerprint({"version": 1, "userId": str(user.id), **body.model_dump(mode="json", by_alias=True)})
    # A committed receipt takes precedence over deleted/edited/legacy-shaped source data.
    prior = await _kana_receipt(db, user.id, body)
    if prior is not None:
        return _read_kana_receipt(prior, fingerprint)
    session = await db.get(QuizSession, body.session_id, with_for_update=True, populate_existing=True)
    if not session or session.user_id != user.id:
        raise KanaQuizAnswerServiceError(status_code=404, detail="세션을 찾을 수 없습니다")

    question_data = find_kana_quiz_question(session.questions_data, body.question_id)
    if not question_data:
        raise KanaQuizAnswerServiceError(status_code=400, detail="질문을 찾을 수 없습니다")

    version = question_data.get("_answerActivityVersion")
    if "_answerActivityVersion" in question_data and (type(version) is not int or version != 1):
        raise KanaQuizAnswerServiceError(status_code=409, detail="가나 퀴즈의 저장 형식을 확인할 수 없습니다")
    tagged = version == 1
    if tagged:
        if session.quiz_type != QuizType.KANA:
            raise KanaQuizAnswerServiceError(status_code=400, detail="가나 퀴즈 세션을 확인해주세요")
        if session.completed_at:
            raise KanaQuizAnswerServiceError(status_code=400, detail="이미 완료된 세션입니다")
        if body.selected_option_id not in _tagged_option_ids(question_data):
            raise KanaQuizAnswerServiceError(status_code=400, detail="문항의 유효한 답안을 선택해주세요")
    correct_option_id = resolve_correct_option_id(question_data)
    is_correct = body.selected_option_id == correct_option_id
    now = canonical_study_instant(datetime.now(UTC))

    await db.execute(
        build_kana_progress_upsert_statement(
            user_id=user.id,
            kana_id=body.question_id,
            is_correct=is_correct,
            now=now,
        )
    )

    if is_correct:
        session.correct_count += 1

    if tagged:
        await record_answered_study_day(db, user, processed_at=now)
        db.add(
            StudyActivityReceipt(
                user_id=user.id,
                activity_id=uuid4(),
                source_kind="KANA_QUIZ_ANSWER",
                source_scope_id=session.id,
                attempt_id=session.id,
                source_item_key=str(body.question_id),
                content_version=activity_fingerprint(question_data),
                request_fingerprint=fingerprint,
                fingerprint_version=1,
                response_schema_version=1,
                response_body={"isCorrect": is_correct, "correctOptionId": correct_option_id},
                processed_at=now,
                study_date=study_date_kst(now),
            )
        )
    await db.commit()
    return KanaQuizAnswerResult(is_correct=is_correct, correct_option_id=correct_option_id)


def _tagged_option_ids(question: QuestionPayload) -> set[str]:
    invalid = KanaQuizAnswerServiceError(status_code=400, detail="가나 퀴즈 문항의 저장 정보를 확인할 수 없습니다")
    options = question.get("options")
    if not isinstance(options, list) or not options:
        raise invalid
    ids: set[str] = set()
    for option in options:
        if not isinstance(option, dict):
            raise invalid
        option_id = option.get("id")
        if not isinstance(option_id, str) or not option_id.strip() or option_id in ids:
            raise invalid
        ids.add(option_id)
    correct = question.get("correctOptionId")
    if not isinstance(correct, str) or correct not in ids:
        raise invalid
    return ids


def find_kana_quiz_question(raw_questions_data: Any, question_id: uuid.UUID) -> QuestionPayload | None:
    questions_data = (
        [cast(QuestionPayload, question) for question in raw_questions_data if isinstance(question, dict)]
        if isinstance(raw_questions_data, list)
        else []
    )
    return next((question for question in questions_data if question.get("id") == str(question_id)), None)


def resolve_correct_option_id(question_data: QuestionPayload) -> str:
    correct_option_id = question_data.get("correctOptionId", "")
    return correct_option_id if isinstance(correct_option_id, str) else ""


def build_kana_progress_upsert_statement(
    *,
    user_id: uuid.UUID,
    kana_id: uuid.UUID,
    is_correct: bool,
    now: datetime,
) -> Any:
    stmt = pg_insert(UserKanaProgress).values(
        user_id=user_id,
        kana_id=kana_id,
        correct_count=1 if is_correct else 0,
        incorrect_count=0 if is_correct else 1,
        streak=1 if is_correct else 0,
        mastered=False,
        last_reviewed_at=now,
        updated_at=now,
    )
    if is_correct:
        return stmt.on_conflict_do_update(
            index_elements=["user_id", "kana_id"],
            set_={
                "correct_count": UserKanaProgress.correct_count + 1,
                "streak": UserKanaProgress.streak + 1,
                "mastered": UserKanaProgress.streak + 1 >= KANA_MASTERY_STREAK,
                "last_reviewed_at": now,
                "updated_at": now,
            },
        )

    return stmt.on_conflict_do_update(
        index_elements=["user_id", "kana_id"],
        set_={
            "incorrect_count": UserKanaProgress.incorrect_count + 1,
            "streak": 0,
            "last_reviewed_at": now,
            "updated_at": now,
        },
    )


async def _kana_receipt(db: AsyncSession, user_id: uuid.UUID, body: KanaQuizAnswerRequest) -> StudyActivityReceipt | None:
    receipt: StudyActivityReceipt | None = await db.scalar(
        select(StudyActivityReceipt).where(
            StudyActivityReceipt.user_id == user_id,
            StudyActivityReceipt.source_kind == "KANA_QUIZ_ANSWER",
            StudyActivityReceipt.source_scope_id == body.session_id,
            StudyActivityReceipt.source_item_key == str(body.question_id),
        )
    )

    return receipt


def _read_kana_receipt(receipt: StudyActivityReceipt, fingerprint: str) -> KanaQuizAnswerResult:
    if receipt.request_fingerprint != fingerprint:
        raise KanaQuizAnswerServiceError(status_code=409, detail="이미 제출한 답안은 변경할 수 없습니다")
    try:
        if (
            receipt.fingerprint_version != 1
            or receipt.response_schema_version != 1
            or type(receipt.response_body.get("isCorrect")) is not bool
        ):
            raise ValueError("Invalid kana receipt")
        response = KanaQuizAnswerResponse.model_validate(receipt.response_body)
        if (
            not response.correct_option_id
            or receipt.processed_at.utcoffset() is None
            or study_date_kst(receipt.processed_at) != receipt.study_date
        ):
            raise ValueError("Invalid kana receipt identity")
        return KanaQuizAnswerResult(is_correct=response.is_correct, correct_option_id=response.correct_option_id)
    except (ValueError, TypeError, ValidationError) as exc:
        raise KanaQuizAnswerServiceError(
            status_code=503, detail="저장된 가나 답안을 확인할 수 없습니다. 같은 답안으로 다시 확인해주세요"
        ) from exc


async def submit_kana_quiz_answer(db: AsyncSession, user: User, body: KanaQuizAnswerRequest) -> KanaQuizAnswerResult:
    try:
        return await _submit_kana_quiz_answer(db, user, body)
    except Exception:
        await db.rollback()
        raise
