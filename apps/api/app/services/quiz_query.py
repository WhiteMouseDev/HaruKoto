from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizAnswer, QuizSession
from app.models.user import User
from app.schemas.quiz import QuizQuestion, QuizResumeRequest
from app.services.quiz_session import build_response_questions, extract_questions_data
from app.utils.helpers import enum_value


class QuizQueryServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class IncompleteQuizSessionResult:
    id: str
    quiz_type: str
    jlpt_level: str
    total_questions: int
    answered_count: int
    correct_count: int
    started_at: str


@dataclass(slots=True)
class ResumeQuizResult:
    session_id: str
    questions: list[QuizQuestion]
    answered_question_ids: list[str]
    total_questions: int
    correct_count: int
    quiz_type: str


async def get_incomplete_quiz_session(
    db: AsyncSession,
    user: User,
) -> IncompleteQuizSessionResult | None:
    cutoff = datetime.now(UTC) - timedelta(hours=24)
    result = await db.execute(
        select(QuizSession)
        .where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.is_(None),
        )
        .order_by(QuizSession.started_at.desc())
    )
    sessions = result.scalars().all()

    valid_session: tuple[QuizSession, int] | None = None
    for session in sessions:
        answered_result = await db.execute(select(func.count(QuizAnswer.id)).where(QuizAnswer.session_id == session.id))
        answered_count = answered_result.scalar() or 0

        if answered_count == 0 or (session.started_at and session.started_at < cutoff):
            session.completed_at = datetime.now(UTC)
            continue

        if valid_session is None:
            valid_session = (session, answered_count)

    await db.commit()
    if not valid_session:
        return None

    session, answered_count = valid_session
    return IncompleteQuizSessionResult(
        id=str(session.id),
        quiz_type=enum_value(session.quiz_type),
        jlpt_level=enum_value(session.jlpt_level),
        total_questions=session.total_questions,
        answered_count=answered_count,
        correct_count=session.correct_count,
        started_at=session.started_at.isoformat() if session.started_at else "",
    )


async def resume_quiz_session(
    db: AsyncSession,
    user: User,
    body: QuizResumeRequest,
) -> ResumeQuizResult:
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise QuizQueryServiceError(status_code=404, detail="세션을 찾을 수 없습니다")
    if session.completed_at:
        raise QuizQueryServiceError(status_code=400, detail="이미 완료된 세션입니다")

    answered_result = await db.execute(select(QuizAnswer.question_id).where(QuizAnswer.session_id == session.id))
    answered_ids = [str(question_id) for question_id in answered_result.scalars().all()]
    questions = extract_questions_data(session.questions_data)
    response_questions = build_response_questions(questions)

    return ResumeQuizResult(
        session_id=str(session.id),
        questions=response_questions,
        answered_question_ids=answered_ids,
        total_questions=session.total_questions,
        correct_count=session.correct_count,
        quiz_type=enum_value(session.quiz_type),
    )
