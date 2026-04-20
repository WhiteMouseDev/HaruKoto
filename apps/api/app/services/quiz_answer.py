from __future__ import annotations

import contextlib
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizAnswer, QuizSession, UserGrammarProgress, UserVocabProgress
from app.models.user import User
from app.schemas.quiz import QuizAnswerRequest
from app.services.quiz_policy import apply_srs_update
from app.services.quiz_session import extract_questions_data
from app.services.srs import log_review_event


class QuizAnswerServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class QuizAnswerResult:
    success: bool


async def _update_vocab_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    body: QuizAnswerRequest,
    session: QuizSession,
    is_correct: bool,
    now: datetime,
) -> None:
    progress_result = await db.execute(
        select(UserVocabProgress).where(
            UserVocabProgress.user_id == user_id,
            UserVocabProgress.vocabulary_id == body.question_id,
        )
    )
    progress = progress_result.scalar_one_or_none()

    if progress is None:
        progress = UserVocabProgress(
            user_id=user_id,
            vocabulary_id=body.question_id,
        )
        db.add(progress)
        await db.flush()

    state_before = getattr(progress, "state", "UNSEEN") or "UNSEEN"
    apply_srs_update(progress, is_correct, body.time_spent_seconds, now)
    with contextlib.suppress(Exception):
        await log_review_event(
            db,
            user_id,
            "WORD",
            body.question_id,
            session.id,
            None,
            "JP_KR",
            is_correct,
            body.time_spent_seconds * 1000,
            3 if is_correct else 1,
            state_before,
            getattr(progress, "state", state_before) or state_before,
            None,
            getattr(progress, "state", "") == "PROVISIONAL",
            state_before == "UNSEEN",
            now.date(),
        )


async def _update_grammar_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    body: QuizAnswerRequest,
    session: QuizSession,
    is_correct: bool,
    now: datetime,
) -> None:
    progress_result = await db.execute(
        select(UserGrammarProgress).where(
            UserGrammarProgress.user_id == user_id,
            UserGrammarProgress.grammar_id == body.question_id,
        )
    )
    progress = progress_result.scalar_one_or_none()

    if progress is None:
        progress = UserGrammarProgress(
            user_id=user_id,
            grammar_id=body.question_id,
        )
        db.add(progress)
        await db.flush()

    state_before = getattr(progress, "state", "UNSEEN") or "UNSEEN"
    apply_srs_update(progress, is_correct, body.time_spent_seconds, now)
    with contextlib.suppress(Exception):
        await log_review_event(
            db,
            user_id,
            "GRAMMAR",
            body.question_id,
            session.id,
            None,
            "JP_KR",
            is_correct,
            body.time_spent_seconds * 1000,
            3 if is_correct else 1,
            state_before,
            getattr(progress, "state", state_before) or state_before,
            None,
            getattr(progress, "state", "") == "PROVISIONAL",
            state_before == "UNSEEN",
            now.date(),
        )


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
        await _update_vocab_progress(
            db,
            user_id=user.id,
            body=body,
            session=session,
            is_correct=is_correct,
            now=now,
        )
    elif question_type == "GRAMMAR":
        await _update_grammar_progress(
            db,
            user_id=user.id,
            body=body,
            session=session,
            is_correct=is_correct,
            now=now,
        )

    await db.commit()
    return QuizAnswerResult(success=True)
