from __future__ import annotations

import contextlib
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import DailyProgress, QuizSession, UserStudyStageProgress, UserVocabProgress
from app.models.user import User
from app.schemas.quiz import QuizCompleteRequest
from app.services.gamification import LevelInfo, calculate_level, check_and_grant_achievements, update_streak
from app.services.quiz_complete_metrics import calculate_accuracy, calculate_daily_progress_increments, calculate_study_minutes
from app.utils.constants import REWARDS
from app.utils.date import get_today_kst


class QuizCompleteServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class QuizCompleteResult:
    session_id: uuid.UUID
    correct_count: int
    total_questions: int
    accuracy: float
    xp_earned: int
    level: int
    current_xp: int
    xp_for_next: int
    events: list[dict[str, Any]]


def _build_complete_result(
    *,
    session: QuizSession,
    accuracy: float,
    xp_earned: int,
    level_info: LevelInfo,
    events: list[dict[str, Any]],
) -> QuizCompleteResult:
    return QuizCompleteResult(
        session_id=session.id,
        correct_count=session.correct_count,
        total_questions=session.total_questions,
        accuracy=accuracy,
        xp_earned=xp_earned,
        level=level_info["level"],
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
        events=events,
    )


def _resolve_stage_id(body: QuizCompleteRequest, session: QuizSession) -> uuid.UUID | None:
    stage_id = body.stage_id
    if stage_id:
        return stage_id

    questions_data = session.questions_data
    if isinstance(questions_data, dict) and "stage_id" in questions_data:
        with contextlib.suppress(ValueError):
            return uuid.UUID(questions_data["stage_id"])
    return None


async def _update_daily_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    today: Any,
    session: QuizSession,
    xp_earned: int,
    study_duration_minutes: int,
) -> None:
    increments = calculate_daily_progress_increments(session)

    stmt = pg_insert(DailyProgress).values(
        user_id=user_id,
        date=today,
        quizzes_completed=1,
        correct_answers=session.correct_count,
        total_answers=session.total_questions,
        xp_earned=xp_earned,
        words_studied=increments.words_studied,
        grammar_studied=increments.grammar_studied,
        sentences_studied=increments.sentences_studied,
        study_minutes=study_duration_minutes,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_={
            "quizzes_completed": DailyProgress.quizzes_completed + 1,
            "correct_answers": DailyProgress.correct_answers + session.correct_count,
            "total_answers": DailyProgress.total_answers + session.total_questions,
            "xp_earned": DailyProgress.xp_earned + xp_earned,
            "words_studied": DailyProgress.words_studied + increments.words_studied,
            "grammar_studied": func.coalesce(DailyProgress.grammar_studied, 0) + increments.grammar_studied,
            "sentences_studied": func.coalesce(DailyProgress.sentences_studied, 0) + increments.sentences_studied,
            "study_minutes": func.coalesce(DailyProgress.study_minutes, 0) + study_duration_minutes,
        },
    )
    await db.execute(stmt)


async def _build_achievement_events(
    db: AsyncSession,
    *,
    user: User,
    old_level: int,
    session: QuizSession,
) -> list[dict[str, Any]]:
    quiz_count_result = await db.execute(
        select(func.count(QuizSession.id)).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.isnot(None),
        )
    )
    quiz_count = quiz_count_result.scalar() or 0

    words_count_result = await db.execute(select(func.count(UserVocabProgress.id)).where(UserVocabProgress.user_id == user.id))
    words_count = words_count_result.scalar() or 0

    is_perfect = session.correct_count == session.total_questions and session.total_questions > 0

    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": user.level,
            "old_level": old_level,
            "streak_count": user.streak_count,
            "quiz_count": quiz_count,
            "is_perfect_quiz": is_perfect,
            "total_words_studied": words_count,
        },
    )
    return [dict(event) for event in events]


async def _update_stage_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    stage_id: uuid.UUID | None,
    accuracy: float,
) -> None:
    if not stage_id:
        return

    now = datetime.now(UTC)
    score_pct = round(accuracy)
    stage_progress_result = await db.execute(
        select(UserStudyStageProgress).where(
            UserStudyStageProgress.user_id == user_id,
            UserStudyStageProgress.stage_id == stage_id,
        )
    )
    stage_progress = stage_progress_result.scalar_one_or_none()

    if stage_progress is None:
        stage_progress = UserStudyStageProgress(
            user_id=user_id,
            stage_id=stage_id,
            best_score=score_pct,
            attempts=1,
            completed=score_pct >= 70,
            completed_at=now if score_pct >= 70 else None,
            last_attempted_at=now,
        )
        db.add(stage_progress)
        return

    stage_progress.attempts = (stage_progress.attempts or 0) + 1
    stage_progress.last_attempted_at = now
    if score_pct > (stage_progress.best_score or 0):
        stage_progress.best_score = score_pct
    if score_pct >= 70 and not stage_progress.completed:
        stage_progress.completed = True
        stage_progress.completed_at = now


async def complete_quiz_session(
    db: AsyncSession,
    user: User,
    body: QuizCompleteRequest,
) -> QuizCompleteResult:
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise QuizCompleteServiceError(status_code=404, detail="세션을 찾을 수 없습니다")

    accuracy = calculate_accuracy(session)

    if session.completed_at:
        level_info = calculate_level(user.experience_points)
        return _build_complete_result(
            session=session,
            accuracy=accuracy,
            xp_earned=0,
            level_info=level_info,
            events=[],
        )

    now = datetime.now(UTC)
    session.completed_at = now
    xp_earned = session.correct_count * REWARDS.QUIZ_XP_PER_CORRECT
    old_level = user.level
    user.experience_points += xp_earned
    level_info = calculate_level(user.experience_points)
    user.level = level_info["level"]

    today = get_today_kst()
    streak_info = update_streak(user.last_study_date, user.streak_count, user.longest_streak, today)
    user.streak_count = streak_info["streak_count"]
    user.longest_streak = streak_info["longest_streak"]
    user.last_study_date = now

    await _update_daily_progress(
        db,
        user_id=user.id,
        today=today,
        session=session,
        xp_earned=xp_earned,
        study_duration_minutes=calculate_study_minutes(session, now),
    )
    events = await _build_achievement_events(
        db,
        user=user,
        old_level=old_level,
        session=session,
    )
    await _update_stage_progress(
        db,
        user_id=user.id,
        stage_id=_resolve_stage_id(body, session),
        accuracy=accuracy,
    )
    await db.commit()

    return _build_complete_result(
        session=session,
        accuracy=accuracy,
        xp_earned=xp_earned,
        level_info=level_info,
        events=events,
    )
