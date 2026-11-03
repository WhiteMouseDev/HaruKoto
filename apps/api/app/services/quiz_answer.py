from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, QuizAnswer, QuizSession, Vocabulary
from app.models.user import User
from app.schemas.quiz import QuizAnswerRequest
from app.services.quiz_answer_progress import update_grammar_answer_progress, update_vocab_answer_progress
from app.services.quiz_resume_snapshot import INVALID_SNAPSHOT
from app.services.quiz_saved_sessions import CONTENT_UNAVAILABLE
from app.services.quiz_session import extract_questions_data
from app.services.study_day_recording import canonical_study_instant, lock_study_user, record_answered_study_day


class QuizAnswerServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class QuizAnswerResult:
    success: bool


async def _submit_quiz_answer(
    db: AsyncSession,
    user: User,
    body: QuizAnswerRequest,
) -> QuizAnswerResult:
    await lock_study_user(db, user)
    # All activity writers acquire user before session, including completion.
    session = await db.get(QuizSession, body.session_id, with_for_update=True, populate_existing=True)
    if not session or session.user_id != user.id:
        raise QuizAnswerServiceError(status_code=404, detail="세션을 찾을 수 없습니다")
    previous_answer = (
        await db.execute(
            select(QuizAnswer)
            .where(QuizAnswer.session_id == session.id, QuizAnswer.question_id == body.question_id)
            .order_by(QuizAnswer.answered_at, QuizAnswer.id)
            .limit(1)
        )
    ).scalar_one_or_none()
    if previous_answer is not None:
        if previous_answer.selected_option_id != body.selected_option_id:
            raise QuizAnswerServiceError(status_code=409, detail="이미 제출한 답안은 변경할 수 없습니다")
        return QuizAnswerResult(success=True)
    if session.completed_at:
        raise QuizAnswerServiceError(status_code=400, detail="이미 완료된 세션입니다")

    questions_data = extract_questions_data(session.questions_data)
    if len(questions_data) != session.total_questions or not questions_data:
        raise QuizAnswerServiceError(status_code=409, detail=INVALID_SNAPSHOT)
    question_data = next((question for question in questions_data if question["id"] == str(body.question_id)), None)
    if question_data is None:
        raise QuizAnswerServiceError(status_code=400, detail="질문을 찾을 수 없습니다")
    if not isinstance(question_data.get("correctOptionId"), str):
        raise QuizAnswerServiceError(status_code=409, detail=INVALID_SNAPSHOT)

    # Hold a catalogue key-share lock until the answer/SRS transaction commits.
    # This closes the resume-read -> catalogue-delete race without mutating content.
    catalog = Vocabulary if body.question_type.value in {"VOCABULARY", "KANJI", "LISTENING"} else Grammar
    if body.question_type.value in {"VOCABULARY", "KANJI", "LISTENING", "GRAMMAR"}:
        content = await db.execute(select(catalog.id).where(catalog.id == body.question_id).with_for_update(read=True, key_share=True))
        if content.scalar_one_or_none() is None:
            raise QuizAnswerServiceError(status_code=409, detail=CONTENT_UNAVAILABLE)

    now = canonical_study_instant(datetime.now(UTC))
    is_correct = body.selected_option_id == question_data.get("correctOptionId", "")
    db.add(
        QuizAnswer(
            session_id=session.id,
            question_id=body.question_id,
            question_type=body.question_type,
            selected_option_id=body.selected_option_id,
            is_correct=is_correct,
            time_spent_seconds=body.time_spent_seconds,
            answered_at=now,
        )
    )

    if is_correct:
        session.correct_count += 1

    question_type = body.question_type.value
    if question_type in ("VOCABULARY", "KANJI", "LISTENING"):
        await update_vocab_answer_progress(
            db,
            user_id=user.id,
            question_id=body.question_id,
            session_id=session.id,
            is_correct=is_correct,
            time_spent_seconds=body.time_spent_seconds,
            now=now,
        )
    elif question_type == "GRAMMAR":
        await update_grammar_answer_progress(
            db,
            user_id=user.id,
            question_id=body.question_id,
            session_id=session.id,
            is_correct=is_correct,
            time_spent_seconds=body.time_spent_seconds,
            now=now,
        )

    await record_answered_study_day(db, user, processed_at=now)
    await db.commit()
    return QuizAnswerResult(success=True)


async def submit_quiz_answer(db: AsyncSession, user: User, body: QuizAnswerRequest) -> QuizAnswerResult:
    try:
        return await _submit_quiz_answer(db, user, body)
    except Exception:
        await db.rollback()
        raise
