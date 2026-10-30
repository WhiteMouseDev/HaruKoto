from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizAnswer, QuizSession
from app.models.user import User
from app.schemas.quiz import MatchingPair, QuizQuestion, QuizResumeRequest
from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_resume_snapshot import QuizResumeSnapshot, ResumeStatus, decode_quiz_resume_snapshot, snapshot_error_message
from app.services.quiz_session import build_response_questions
from app.utils.helpers import enum_value


@dataclass(slots=True)
class IncompleteQuizSessionResult:
    id: str
    quiz_type: str
    jlpt_level: str
    total_questions: int
    answered_count: int
    correct_count: int
    started_at: str
    mode: str | None = None
    resume_status: ResumeStatus | None = None


@dataclass(slots=True)
class ResumeQuizResult:
    session_id: str
    questions: list[QuizQuestion]
    answered_question_ids: list[str]
    total_questions: int
    correct_count: int
    quiz_type: str
    mode: str | None = None
    matching_pairs: list[MatchingPair] | None = None


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
        answered_count = await _count_session_answers(db, session=session)

        started_at = session.started_at
        # Legacy TIMESTAMP columns return naive values stored in UTC.
        if started_at is not None and started_at.tzinfo is None:
            started_at = started_at.replace(tzinfo=UTC)
        if started_at and started_at < cutoff:
            session.completed_at = datetime.now(UTC)
            continue
        # A delayed home-screen request can arrive just after /quiz/start. Hide
        # an unanswered session from the banner without closing the active quiz.
        if answered_count == 0:
            continue

        if valid_session is None:
            valid_session = (session, answered_count)

    await db.commit()
    if not valid_session:
        return None

    session, answered_count = valid_session
    snapshot = decode_quiz_resume_snapshot(
        getattr(session, "questions_data", None), total_questions=session.total_questions, quiz_type=enum_value(session.quiz_type)
    )
    status = snapshot.status
    correct_count = session.correct_count
    if status == "available" and snapshot.mode in {"matching", "arrange"}:
        try:
            answered_ids, correct_count = await _load_special_answer_ids(db, session=session, snapshot=snapshot)
            answered_count = len(answered_ids)
        except QuizQueryServiceError:
            status = "invalid_snapshot"
    return IncompleteQuizSessionResult(
        id=str(session.id),
        quiz_type=enum_value(session.quiz_type),
        jlpt_level=enum_value(session.jlpt_level),
        total_questions=session.total_questions,
        answered_count=answered_count,
        correct_count=correct_count,
        started_at=session.started_at.isoformat() if session.started_at else "",
        mode=snapshot.mode,
        resume_status=status,
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

    snapshot = decode_quiz_resume_snapshot(
        session.questions_data, total_questions=session.total_questions, quiz_type=enum_value(session.quiz_type)
    )
    if snapshot.status != "available":
        raise QuizQueryServiceError(status_code=409, detail=snapshot_error_message(snapshot.status))
    correct_count = session.correct_count
    if snapshot.mode in {"matching", "arrange"}:
        answered_ids, correct_count = await _load_special_answer_ids(db, session=session, snapshot=snapshot)
    else:
        saved_ids = set(await _load_answered_question_ids(db, session=session))
        question_ids = {question["id"] for question in snapshot.questions}
        if not saved_ids <= question_ids:
            raise QuizQueryServiceError(status_code=409, detail=snapshot_error_message("invalid_snapshot"))
        answered_ids = [question["id"] for question in snapshot.questions if question["id"] in saved_ids]
    response_questions = build_response_questions(snapshot.questions)

    return ResumeQuizResult(
        session_id=str(session.id),
        questions=response_questions,
        answered_question_ids=answered_ids,
        total_questions=session.total_questions,
        correct_count=correct_count,
        quiz_type=enum_value(session.quiz_type),
        mode=snapshot.mode,
        matching_pairs=snapshot.matching_pairs,
    )


async def _count_session_answers(
    db: AsyncSession,
    *,
    session: QuizSession,
) -> int:
    answered_result = await db.execute(select(func.count(func.distinct(QuizAnswer.question_id))).where(QuizAnswer.session_id == session.id))
    return answered_result.scalar() or 0


async def _load_answered_question_ids(
    db: AsyncSession,
    *,
    session: QuizSession,
) -> list[str]:
    answered_result = await db.execute(select(QuizAnswer.question_id).where(QuizAnswer.session_id == session.id))
    return [str(question_id) for question_id in answered_result.scalars().all()]


async def _load_special_answer_ids(db: AsyncSession, *, session: QuizSession, snapshot: QuizResumeSnapshot) -> tuple[list[str], int]:
    """Validate saved references while retaining the first-answer grading policy."""
    result = await db.execute(select(QuizAnswer).where(QuizAnswer.session_id == session.id).order_by(QuizAnswer.answered_at, QuizAnswer.id))
    questions = {question["id"]: question for question in snapshot.questions}
    first_answers: dict[str, QuizAnswer] = {}
    pair_ids = {pair.id for pair in snapshot.matching_pairs or []}
    for answer in result.scalars().all():
        question_id = str(answer.question_id)
        if question_id not in questions:
            raise QuizQueryServiceError(status_code=409, detail=snapshot_error_message("invalid_snapshot"))
        # Later legacy duplicates remain untouched and do not re-grade the first.
        if question_id in first_answers:
            continue
        question = questions[question_id]
        if (
            enum_value(answer.question_type) != enum_value(session.quiz_type)
            or not isinstance(answer.selected_option_id, str)
            or not isinstance(answer.is_correct, bool)
            or answer.is_correct != (answer.selected_option_id == question["correctOptionId"])
            or snapshot.mode == "matching"
            and answer.selected_option_id not in pair_ids | {"wrong"}
        ):
            raise QuizQueryServiceError(status_code=409, detail=snapshot_error_message("invalid_snapshot"))
        first_answers[question_id] = answer
    return (
        [question["id"] for question in snapshot.questions if question["id"] in first_answers],
        sum(answer.is_correct for answer in first_answers.values()),
    )
