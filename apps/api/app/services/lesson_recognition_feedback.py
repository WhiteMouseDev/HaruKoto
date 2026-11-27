"""Grade a confirmed recognition choice without writing learning progress."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Lesson
from app.models.user import User
from app.schemas.lesson import LessonContent, LessonRecognitionFeedbackRequest, LessonRecognitionFeedbackResponse
from app.services.lesson_command import LessonServiceError
from app.services.lesson_submission import assert_submission_owner


def recognition_feedback_version(updated_at: datetime | None) -> str | None:
    if updated_at is None:
        return None
    if updated_at.tzinfo is None:
        updated_at = updated_at.replace(tzinfo=UTC)
    return updated_at.astimezone(UTC).isoformat()


async def grade_lesson_recognition(
    db: AsyncSession,
    user: User,
    *,
    lesson_id: UUID,
    question_order: int,
    request: LessonRecognitionFeedbackRequest,
) -> LessonRecognitionFeedbackResponse:
    assert_submission_owner(user, request.expected_user_id)
    lesson = await db.scalar(select(Lesson).where(Lesson.id == lesson_id, Lesson.is_published.is_(True)))
    if lesson is None:
        raise LessonServiceError(status_code=404, detail="레슨을 찾을 수 없습니다")

    version = recognition_feedback_version(lesson.updated_at)
    if version is None or version != request.feedback_version:
        raise LessonServiceError(status_code=409, detail="레슨 내용이 변경됐어요. 최신 레슨에서 다시 확인해 주세요.")

    content = LessonContent.model_validate(lesson.content_jsonb or {})
    question = next((item for item in content.questions if item.order == question_order), None)
    if question is None:
        raise LessonServiceError(status_code=404, detail="레슨 문항을 찾을 수 없습니다")

    option_ids = {option.id for option in question.options or []}
    correct = question.correct_answer
    if question.type not in {"VOCAB_MCQ", "CONTEXT_CLOZE"} or not correct or correct not in option_ids:
        raise LessonServiceError(status_code=400, detail="이 문항은 이해 체크에서 채점할 수 없습니다")
    if request.selected_answer not in option_ids:
        raise LessonServiceError(status_code=400, detail="이 문항에 있는 답안을 선택해 주세요")

    return LessonRecognitionFeedbackResponse(
        feedback_version=version,
        question_order=question_order,
        selected_answer=request.selected_answer,
        correct_answer=correct,
        is_correct=request.selected_answer == correct,
        explanation=question.explanation,
    )
