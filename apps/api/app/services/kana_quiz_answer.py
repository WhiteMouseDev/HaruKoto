from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, cast

from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizSession, UserKanaProgress
from app.models.user import User
from app.schemas.kana import KanaQuizAnswerRequest

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


async def submit_kana_quiz_answer(
    db: AsyncSession,
    user: User,
    body: KanaQuizAnswerRequest,
) -> KanaQuizAnswerResult:
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise KanaQuizAnswerServiceError(status_code=404, detail="세션을 찾을 수 없습니다")

    question_data = find_kana_quiz_question(session.questions_data, body.question_id)
    if not question_data:
        raise KanaQuizAnswerServiceError(status_code=400, detail="질문을 찾을 수 없습니다")

    correct_option_id = resolve_correct_option_id(question_data)
    is_correct = body.selected_option_id == correct_option_id
    now = datetime.now(UTC)

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

    await db.commit()
    return KanaQuizAnswerResult(is_correct=is_correct, correct_option_id=correct_option_id)


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
    )
    if is_correct:
        return stmt.on_conflict_do_update(
            index_elements=["user_id", "kana_id"],
            set_={
                "correct_count": UserKanaProgress.correct_count + 1,
                "streak": UserKanaProgress.streak + 1,
                "mastered": UserKanaProgress.streak + 1 >= KANA_MASTERY_STREAK,
                "last_reviewed_at": now,
            },
        )

    return stmt.on_conflict_do_update(
        index_elements=["user_id", "kana_id"],
        set_={
            "incorrect_count": UserKanaProgress.incorrect_count + 1,
            "streak": 0,
            "last_reviewed_at": now,
        },
    )
