from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizAnswer, QuizSession
from app.models.user import User
from app.schemas.quiz import QuizAnswerRequest
from app.services.quiz_answer_progress import update_grammar_answer_progress, update_vocab_answer_progress
from app.services.quiz_session import extract_questions_data


class QuizAnswerServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class QuizAnswerResult:
    success: bool


async def submit_quiz_answer(
    db: AsyncSession,
    user: User,
    body: QuizAnswerRequest,
) -> QuizAnswerResult:
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise QuizAnswerServiceError(status_code=404, detail="세션을 찾을 수 없습니다")
    if session.completed_at:
        raise QuizAnswerServiceError(status_code=400, detail="이미 완료된 세션입니다")

    questions_data = extract_questions_data(session.questions_data)
    question_data = next((question for question in questions_data if question["id"] == str(body.question_id)), None)
    if not question_data:
        raise QuizAnswerServiceError(status_code=400, detail="질문을 찾을 수 없습니다")

    is_correct = body.selected_option_id == question_data.get("correctOptionId", "")
    db.add(
        QuizAnswer(
            session_id=session.id,
            question_id=body.question_id,
            question_type=body.question_type,
            selected_option_id=body.selected_option_id,
            is_correct=is_correct,
            time_spent_seconds=body.time_spent_seconds,
        )
    )

    if is_correct:
        session.correct_count += 1

    question_type = body.question_type.value
    now = datetime.now(UTC)
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

    await db.commit()
    return QuizAnswerResult(success=True)
