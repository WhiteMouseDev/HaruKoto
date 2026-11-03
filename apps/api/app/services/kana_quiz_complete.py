from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizSession, StudyActivityReceipt
from app.models.enums import QuizType
from app.models.user import User
from app.schemas.kana import KanaQuizCompleteRequest
from app.services.gamification import LevelInfo, calculate_level, check_and_grant_achievements
from app.services.kana_daily_progress import apply_daily_progress_increment
from app.services.lesson_study_activity import activity_fingerprint
from app.services.study_day_recording import apply_study_streak, canonical_study_instant, lock_study_user
from app.utils.constants import KANA_REWARDS


class KanaQuizCompleteServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class KanaQuizCompleteResult:
    accuracy: int
    xp_earned: int
    level: int
    current_xp: int
    xp_for_next: int
    events: list[dict[str, Any]]


async def complete_kana_quiz_session(
    db: AsyncSession,
    user: User,
    body: KanaQuizCompleteRequest,
) -> KanaQuizCompleteResult:
    try:
        return await _complete_kana_quiz_session(db, user, body)
    except Exception:
        await db.rollback()
        raise


async def _complete_kana_quiz_session(
    db: AsyncSession,
    user: User,
    body: KanaQuizCompleteRequest,
) -> KanaQuizCompleteResult:
    await lock_study_user(db, user)
    session = await db.get(QuizSession, body.session_id, with_for_update=True, populate_existing=True)
    if not session or session.user_id != user.id:
        raise KanaQuizCompleteServiceError(status_code=404, detail="세션을 찾을 수 없습니다")
    if session.quiz_type != QuizType.KANA:
        raise KanaQuizCompleteServiceError(status_code=400, detail="가나 퀴즈 세션을 확인해주세요")

    if session.completed_at is not None:
        # Existing completed sessions are authoritative, including legacy ones
        # that predate answer receipts. Never backfill or reward their replay.
        return build_kana_quiz_complete_result(
            accuracy=calculate_kana_quiz_accuracy(correct_count=session.correct_count or 0, total_questions=session.total_questions or 0),
            xp_earned=0,
            level_info=calculate_level(user.experience_points),
            events=[],
        )

    correct_count = await _completed_answer_count(db, user, session)
    session.correct_count = correct_count
    accuracy = calculate_kana_quiz_accuracy(correct_count=correct_count, total_questions=session.total_questions or 0)
    xp_earned = resolve_kana_quiz_xp(accuracy)
    old_level = user.level
    user.experience_points += xp_earned
    level_info = calculate_level(user.experience_points)
    user.level = level_info["level"]

    now = canonical_study_instant(datetime.now(UTC))
    today = apply_study_streak(user, processed_at=now)

    await apply_daily_progress_increment(
        db,
        user_id=user.id,
        today=today,
        xp_earned=xp_earned,
        kana_learned=correct_count,
    )
    events = await grant_kana_quiz_achievements(db, user=user, old_level=old_level)
    session.completed_at = now
    await db.commit()

    return build_kana_quiz_complete_result(
        accuracy=accuracy,
        xp_earned=xp_earned,
        level_info=level_info,
        events=events,
    )


async def _completed_answer_count(db: AsyncSession, user: User, session: QuizSession) -> int:
    """Validate receipt-capable quizzes without rejecting old receipt-less ones.

    Untagged sessions historically persisted only per-character aggregates, not
    session answers. They retain first-completion compatibility, without creating
    answer evidence or retroactive attendance. New tagged snapshots must prove
    every canonical question has a durable answer before any completion effect.
    """
    raw = session.questions_data
    if not isinstance(raw, list) or not any(isinstance(q, dict) and "_answerActivityVersion" in q for q in raw):
        return session.correct_count or 0
    invalid = KanaQuizCompleteServiceError(
        status_code=409, detail="아직 저장되지 않은 가나 답안이 있습니다. 답안 저장 후 다시 시도해주세요"
    )
    if not raw or len(raw) != session.total_questions:
        raise invalid
    expected: dict[str, dict[str, Any]] = {}
    for question in raw:
        if (
            not isinstance(question, dict)
            or type(question.get("_answerActivityVersion")) is not int
            or question["_answerActivityVersion"] != 1
            or not isinstance(question.get("id"), str)
            or question["id"] in expected
        ):
            raise invalid
        expected[question["id"]] = question
    receipts = (
        await db.scalars(
            select(StudyActivityReceipt).where(
                StudyActivityReceipt.user_id == user.id,
                StudyActivityReceipt.source_kind == "KANA_QUIZ_ANSWER",
                StudyActivityReceipt.source_scope_id == session.id,
            )
        )
    ).all()
    if {receipt.source_item_key for receipt in receipts} != set(expected):
        raise invalid
    correct_count = 0
    for receipt in receipts:
        question = expected[receipt.source_item_key]
        if (
            receipt.fingerprint_version != 1
            or receipt.response_schema_version != 1
            or receipt.content_version != activity_fingerprint(question)
            or not isinstance(receipt.response_body, dict)
            or type(receipt.response_body.get("isCorrect")) is not bool
            or not question.get("correctOptionId")
            or receipt.response_body.get("correctOptionId") != question["correctOptionId"]
        ):
            raise KanaQuizCompleteServiceError(
                status_code=503, detail="저장된 가나 답안을 확인할 수 없습니다. 같은 퀴즈로 다시 확인해주세요"
            )
        correct_count += int(receipt.response_body["isCorrect"] is True)
    return correct_count


def calculate_kana_quiz_accuracy(*, correct_count: int, total_questions: int) -> int:
    return round(correct_count / total_questions * 100) if total_questions > 0 else 0


def resolve_kana_quiz_xp(accuracy: int) -> int:
    return KANA_REWARDS.QUIZ_PERFECT_XP if accuracy == 100 else KANA_REWARDS.QUIZ_PASS_XP


async def grant_kana_quiz_achievements(
    db: AsyncSession,
    *,
    user: User,
    old_level: int,
) -> list[dict[str, Any]]:
    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": user.level,
            "old_level": old_level,
            "streak_count": user.streak_count,
        },
    )
    return [dict(event) for event in events]


def build_kana_quiz_complete_result(
    *,
    accuracy: int,
    xp_earned: int,
    level_info: LevelInfo,
    events: list[dict[str, Any]],
) -> KanaQuizCompleteResult:
    return KanaQuizCompleteResult(
        accuracy=accuracy,
        xp_earned=xp_earned,
        level=level_info["level"],
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
        events=events,
    )
