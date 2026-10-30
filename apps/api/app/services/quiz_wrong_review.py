from __future__ import annotations

import uuid
from copy import deepcopy
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, QuizAnswer, QuizSession, Vocabulary
from app.models.user import User
from app.schemas.quiz import QuizWrongReviewRequest
from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_first_answers import load_first_quiz_answers, select_canonical_wrong_answers
from app.services.quiz_session import build_response_questions
from app.services.quiz_session_query import ResumeQuizResult
from app.utils.helpers import enum_value

WRONG_REVIEW_MODE = "wrong_answer_review"
SUPPORTED_TYPES = frozenset({"VOCABULARY", "GRAMMAR", "KANJI", "LISTENING"})
UNSUPPORTED_QUESTION_TYPES = frozenset({"CLOZE", "SENTENCE_ARRANGE", "TYPING", "MATCHING", "KANA"})
SUPPORTED_MODES = frozenset({None, "normal", "smart", WRONG_REVIEW_MODE})
INVALID_RECORD = "기존 퀴즈 기록을 안전하게 복원할 수 없습니다"


def _invalid_record() -> QuizQueryServiceError:
    return QuizQueryServiceError(status_code=409, detail=INVALID_RECORD)


def _validated_questions(session: QuizSession) -> list[dict[str, Any]]:
    raw_data = session.questions_data
    if isinstance(raw_data, dict):
        mode = raw_data.get("mode")
        if not isinstance(mode, str | type(None)) or mode not in SUPPORTED_MODES:
            raise QuizQueryServiceError(status_code=400, detail="이 퀴즈 유형은 이번 오답 복습을 지원하지 않습니다")
        raw_questions = raw_data.get("questions")
    else:
        raw_questions = raw_data
    if not isinstance(raw_questions, list) or not raw_questions or len(raw_questions) != session.total_questions:
        raise _invalid_record()

    questions: list[dict[str, Any]] = []
    seen: set[str] = set()
    for question in raw_questions:
        if not isinstance(question, dict):
            raise _invalid_record()
        question_id = question.get("id")
        try:
            canonical_id = str(uuid.UUID(question_id)) if isinstance(question_id, str) else None
        except ValueError as exc:
            raise _invalid_record() from exc
        if question_id != canonical_id or canonical_id is None or canonical_id in seen:
            raise _invalid_record()
        seen.add(canonical_id)
        question_type = question.get("type")
        if isinstance(question_type, str) and question_type in UNSUPPORTED_QUESTION_TYPES:
            raise QuizQueryServiceError(status_code=400, detail="이 퀴즈 유형은 이번 오답 복습을 지원하지 않습니다")
        if question_type != enum_value(session.quiz_type):
            raise _invalid_record()
        if not isinstance(question.get("question"), str) or not question["question"].strip():
            raise _invalid_record()
        options = question.get("options")
        if not isinstance(options, list) or len(options) < 2:
            raise _invalid_record()
        option_ids: set[str] = set()
        for option in options:
            if not isinstance(option, dict):
                raise _invalid_record()
            option_id, text = option.get("id"), option.get("text")
            if not isinstance(option_id, str) or not option_id or option_id in option_ids or not isinstance(text, str) or not text.strip():
                raise _invalid_record()
            option_ids.add(option_id)
        correct_id = question.get("correctOptionId")
        if not isinstance(correct_id, str) or correct_id not in option_ids:
            raise _invalid_record()
        questions.append(question)
    try:
        # Validate all optional response fields before any new row is written.
        build_response_questions(questions)
    except (KeyError, TypeError, ValueError) as exc:
        raise _invalid_record() from exc
    return questions


def _validate_answers(
    session: QuizSession,
    questions: list[dict[str, Any]],
    first_answers: dict[str, QuizAnswer],
    *,
    require_complete: bool,
) -> None:
    question_map = {question["id"]: question for question in questions}
    if require_complete and not question_map.keys() <= first_answers.keys():
        raise _invalid_record()
    for question_id, answer in first_answers.items():
        question = question_map.get(question_id)
        # Ignore unrelated legacy rows for the source, but never resume a
        # newly created review whose persisted answers leave its own snapshot.
        if question is None:
            if require_complete:
                continue
            raise _invalid_record()
        option_ids = {option["id"] for option in question["options"]}
        if (
            enum_value(answer.question_type) != enum_value(session.quiz_type)
            or answer.selected_option_id not in option_ids
            or answer.is_correct != (answer.selected_option_id == question["correctOptionId"])
        ):
            raise _invalid_record()


async def _validate_catalog(db: AsyncSession, *, quiz_type: str, questions: list[dict[str, Any]]) -> None:
    content_ids = {uuid.UUID(question["id"]) for question in questions}
    model = Grammar if quiz_type == "GRAMMAR" else Vocabulary
    result = await db.execute(select(model.id).where(model.id.in_(content_ids)))
    if set(result.scalars().all()) != content_ids:
        raise QuizQueryServiceError(status_code=409, detail="복습할 학습 항목을 찾을 수 없습니다")


async def start_wrong_answer_review(db: AsyncSession, user: User, body: QuizWrongReviewRequest) -> ResumeQuizResult:
    # This lock serializes all starts for the same source, without closing any
    # other unfinished session or awarding its pending XP.
    source = await db.get(QuizSession, body.source_session_id, with_for_update=True, populate_existing=True)
    if source is None or source.user_id != user.id:
        raise QuizQueryServiceError(status_code=404, detail="세션을 찾을 수 없습니다")
    quiz_type = enum_value(source.quiz_type)
    if quiz_type not in SUPPORTED_TYPES:
        raise QuizQueryServiceError(status_code=400, detail="이 퀴즈 유형은 이번 오답 복습을 지원하지 않습니다")
    if source.completed_at is None:
        raise QuizQueryServiceError(status_code=409, detail="완료한 퀴즈에서만 오답 복습을 시작할 수 있습니다")

    questions = _validated_questions(source)
    first_answers = await load_first_quiz_answers(db, session_id=source.id)
    _validate_answers(source, questions, first_answers, require_complete=True)
    wrong_questions = [question for question, _ in select_canonical_wrong_answers(questions, first_answers)]
    if not wrong_questions:
        raise QuizQueryServiceError(status_code=409, detail="이번 퀴즈에서 복습할 오답이 없습니다")
    await _validate_catalog(db, quiz_type=quiz_type, questions=questions)

    active_result = await db.execute(
        select(QuizSession)
        .where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.is_(None),
            QuizSession.questions_data["mode"].as_string() == WRONG_REVIEW_MODE,
            QuizSession.questions_data["source_session_id"].as_string() == str(source.id),
        )
        .order_by(QuizSession.started_at, QuizSession.id)
        .limit(2)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    active_sessions = list(active_result.scalars().all())
    if len(active_sessions) > 1:
        raise _invalid_record()
    if active_sessions:
        review = active_sessions[0]
        if (
            review.quiz_type != source.quiz_type
            or review.jlpt_level != source.jlpt_level
            or review.total_questions != len(wrong_questions)
            or not isinstance(review.questions_data, dict)
            or "stage_id" in review.questions_data
            or _validated_questions(review) != wrong_questions
        ):
            raise _invalid_record()
        review_answers = await load_first_quiz_answers(db, session_id=review.id)
        _validate_answers(review, wrong_questions, review_answers, require_complete=False)
        correct_count = sum(answer.is_correct for answer in review_answers.values())
        if review.correct_count != correct_count:
            raise _invalid_record()
        result = ResumeQuizResult(
            session_id=str(review.id),
            questions=build_response_questions(wrong_questions),
            answered_question_ids=[question["id"] for question in wrong_questions if question["id"] in review_answers],
            total_questions=review.total_questions,
            correct_count=correct_count,
            quiz_type=quiz_type,
            mode=WRONG_REVIEW_MODE,
        )
        await db.commit()
        return result

    # Only this new session receives metadata; the source snapshot and stage
    # completion metadata are not edited or copied into the derived session.
    review = QuizSession(
        user_id=user.id,
        quiz_type=source.quiz_type,
        jlpt_level=source.jlpt_level,
        total_questions=len(wrong_questions),
        correct_count=0,
        questions_data={
            "mode": WRONG_REVIEW_MODE,
            "source_session_id": str(source.id),
            "questions": deepcopy(wrong_questions),
        },
    )
    db.add(review)
    await db.flush()
    result = ResumeQuizResult(
        session_id=str(review.id),
        questions=build_response_questions(wrong_questions),
        answered_question_ids=[],
        total_questions=review.total_questions,
        correct_count=0,
        quiz_type=quiz_type,
        mode=WRONG_REVIEW_MODE,
    )
    await db.commit()
    return result
