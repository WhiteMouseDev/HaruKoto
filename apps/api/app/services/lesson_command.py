from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.lesson import Lesson, LessonItemLink, UserLessonProgress
from app.models.user import User
from app.schemas.lesson import AnswerSubmission
from app.services.srs import AnswerResult, process_answer, register_items_from_lesson

logger = logging.getLogger(__name__)


class LessonServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class LessonProgressResult:
    status: str
    attempts: int
    score_correct: int
    score_total: int
    started_at: datetime | None
    completed_at: datetime | None
    srs_registered_at: datetime | None


@dataclass(slots=True)
class LessonQuestionResult:
    order: int
    is_correct: bool
    correct_answer: str | None
    correct_order: list[str] | None
    explanation: str | None
    state_before: str | None
    state_after: str | None
    next_review_at: str | None
    is_provisional_phase: bool


@dataclass(slots=True)
class LessonSubmitResult:
    score_correct: int
    score_total: int
    results: list[LessonQuestionResult]
    status: str
    srs_items_registered: int


async def start_lesson_progress(
    db: AsyncSession,
    user: User,
    *,
    lesson_id: UUID,
) -> LessonProgressResult:
    lesson = await db.get(Lesson, lesson_id)
    if lesson is None or not lesson.is_published:
        raise LessonServiceError(status_code=404, detail="레슨을 찾을 수 없습니다")

    result = await db.execute(
        select(UserLessonProgress).where(
            UserLessonProgress.user_id == user.id,
            UserLessonProgress.lesson_id == lesson_id,
        )
    )
    progress = result.scalar_one_or_none()

    now = datetime.now(UTC)
    if progress is None:
        progress = UserLessonProgress(
            user_id=user.id,
            lesson_id=lesson_id,
            status="IN_PROGRESS",
            started_at=now,
        )
        db.add(progress)
    elif progress.status == "NOT_STARTED":
        progress.status = "IN_PROGRESS"
        progress.started_at = now

    await db.commit()
    await db.refresh(progress)

    return LessonProgressResult(
        status=progress.status,
        attempts=progress.attempts,
        score_correct=progress.score_correct,
        score_total=progress.score_total,
        started_at=progress.started_at,
        completed_at=progress.completed_at,
        srs_registered_at=getattr(progress, "srs_registered_at", None),
    )


def _grade_answer(answer: AnswerSubmission, question_data: dict[str, Any]) -> bool:
    question_type = question_data.get("type", "")
    if question_type == "SENTENCE_REORDER":
        return bool(answer.submitted_order == question_data.get("correct_order", []))
    return bool(answer.selected_answer == question_data.get("correct_answer", ""))


def _map_questions_to_links(lesson: Lesson, questions_raw: list[dict[str, Any]]) -> dict[int, LessonItemLink]:
    item_links_by_order = {link.item_order: link for link in lesson.item_links}
    question_to_link: dict[int, LessonItemLink] = {}

    for question in questions_raw:
        order = question["order"]
        vocabulary_id = question.get("vocabulary_id")
        grammar_id = question.get("grammar_id")

        if vocabulary_id:
            for link in lesson.item_links:
                if link.item_type == "WORD" and str(link.vocabulary_id) == str(vocabulary_id):
                    question_to_link[order] = link
                    break
        elif grammar_id:
            for link in lesson.item_links:
                if link.item_type == "GRAMMAR" and str(link.grammar_id) == str(grammar_id):
                    question_to_link[order] = link
                    break
        elif order in item_links_by_order:
            question_to_link[order] = item_links_by_order[order]

    return question_to_link


async def submit_lesson_attempt(
    db: AsyncSession,
    user: User,
    *,
    lesson_id: UUID,
    answers: list[AnswerSubmission],
) -> LessonSubmitResult:
    result = await db.execute(select(Lesson).where(Lesson.id == lesson_id).options(selectinload(Lesson.item_links)))
    lesson = result.scalar_one_or_none()
    if lesson is None:
        raise LessonServiceError(status_code=404, detail="레슨을 찾을 수 없습니다")

    questions_raw = (lesson.content_jsonb or {}).get("questions", [])
    answer_key = {question["order"]: question for question in questions_raw}
    question_to_link = _map_questions_to_links(lesson, questions_raw)

    results: list[LessonQuestionResult] = []
    correct_count = 0

    for answer in answers:
        question_data = answer_key.get(answer.order)
        if question_data is None:
            continue

        is_correct = _grade_answer(answer, question_data)
        if is_correct:
            correct_count += 1

        srs_result: AnswerResult | None = None
        link = question_to_link.get(answer.order)
        if link is not None:
            item_id = link.vocabulary_id if link.item_type == "WORD" else link.grammar_id
            if item_id is not None:
                try:
                    async with db.begin_nested():
                        srs_result = await process_answer(
                            db=db,
                            user_id=user.id,
                            item_type=link.item_type,
                            item_id=item_id,
                            is_correct=is_correct,
                            direction="JP_KR",
                            response_ms=answer.response_ms,
                            session_id=None,
                            lesson_id=lesson_id,
                        )
                except Exception:
                    logger.warning(
                        "SRS process_answer failed for item %s in lesson %s",
                        item_id,
                        lesson_id,
                        exc_info=True,
                    )

        results.append(
            LessonQuestionResult(
                order=answer.order,
                is_correct=is_correct,
                correct_answer=question_data.get("correct_answer"),
                correct_order=question_data.get("correct_order"),
                explanation=question_data.get("explanation"),
                state_before=srs_result["state_before"] if srs_result else None,
                state_after=srs_result["state_after"] if srs_result else None,
                next_review_at=srs_result["next_review_at"] if srs_result else None,
                is_provisional_phase=srs_result["is_provisional_phase"] if srs_result else False,
            )
        )

    srs_items_registered = 0
    try:
        async with db.begin_nested():
            srs_items_registered = await register_items_from_lesson(
                db=db,
                user_id=user.id,
                lesson_id=lesson_id,
                item_links=list(lesson.item_links),
            )
    except Exception:
        logger.warning(
            "SRS register_items_from_lesson failed for lesson %s",
            lesson_id,
            exc_info=True,
        )

    total = len(results)
    progress_result = await db.execute(
        select(UserLessonProgress).where(
            UserLessonProgress.user_id == user.id,
            UserLessonProgress.lesson_id == lesson_id,
        )
    )
    progress = progress_result.scalar_one_or_none()
    now = datetime.now(UTC)

    if progress is None:
        progress = UserLessonProgress(
            user_id=user.id,
            lesson_id=lesson_id,
            status="COMPLETED",
            attempts=1,
            score_correct=correct_count,
            score_total=total,
            started_at=now,
            completed_at=now,
            srs_registered_at=now if srs_items_registered > 0 else None,
        )
        db.add(progress)
    else:
        progress.attempts += 1
        progress.score_correct = correct_count
        progress.score_total = total
        progress.status = "COMPLETED"
        progress.completed_at = now
        if srs_items_registered > 0 and progress.srs_registered_at is None:
            progress.srs_registered_at = now

    await db.commit()

    return LessonSubmitResult(
        score_correct=correct_count,
        score_total=total,
        results=results,
        status=progress.status,
        srs_items_registered=srs_items_registered,
    )
