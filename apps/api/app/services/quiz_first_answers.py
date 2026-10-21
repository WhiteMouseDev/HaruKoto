from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizAnswer


async def load_first_quiz_answers(db: AsyncSession, *, session_id: uuid.UUID) -> dict[str, QuizAnswer]:
    """Use the same first-persisted-answer policy as quiz completion."""
    result = await db.execute(select(QuizAnswer).where(QuizAnswer.session_id == session_id).order_by(QuizAnswer.answered_at, QuizAnswer.id))
    first_answers: dict[str, QuizAnswer] = {}
    for answer in result.scalars().all():
        first_answers.setdefault(str(answer.question_id), answer)
    return first_answers


def select_canonical_wrong_answers(
    questions: list[dict[str, Any]], first_answers: dict[str, QuizAnswer]
) -> list[tuple[dict[str, Any], QuizAnswer]]:
    """Keep snapshot order and never include answer rows outside that snapshot.

    Displaying historical results is intentionally tolerant of sparse payloads.
    Starting a new scored review validates the complete snapshot separately.
    """
    selected: list[tuple[dict[str, Any], QuizAnswer]] = []
    seen: set[str] = set()
    for question in questions:
        if not isinstance(question, dict):
            continue
        question_id = question.get("id")
        if not isinstance(question_id, str) or question_id in seen:
            continue
        seen.add(question_id)
        answer = first_answers.get(question_id)
        if answer is not None and not answer.is_correct:
            selected.append((question, answer))
    return selected
