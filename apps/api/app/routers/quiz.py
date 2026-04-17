from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.quiz import (
    OverallProgress,
    PoolSize,
    QuizAnswerRequest,
    QuizAnswerResponse,
    QuizCompleteRequest,
    QuizCompleteResponse,
    QuizResumeRequest,
    QuizStartRequest,
    QuizStartResponse,
    SessionDistribution,
    SmartPreviewResponse,
    SmartStartRequest,
)
from app.services.quiz_answer import QuizAnswerServiceError, submit_quiz_answer
from app.services.quiz_complete import QuizCompleteServiceError, complete_quiz_session
from app.services.quiz_query import (
    QuizQueryServiceError,
    get_incomplete_quiz_session,
    get_quiz_stats_data,
    get_recommendations_data,
    get_wrong_answers_data,
    resume_quiz_session,
)
from app.services.quiz_session import build_response_questions
from app.services.quiz_smart import build_smart_preview_data
from app.services.quiz_start import QuizStartServiceError, start_quiz_session, start_smart_quiz_session

router = APIRouter(prefix="/api/v1/quiz", tags=["quiz"])


@router.post("/start", response_model=QuizStartResponse, status_code=200)
async def start_quiz(
    body: QuizStartRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        result = await start_quiz_session(db, user, body)
    except QuizStartServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    response_questions = build_response_questions(result.questions)

    return QuizStartResponse(
        session_id=result.session.id,
        questions=response_questions,
        total_questions=len(result.questions),
        matching_pairs=result.matching_pairs,
    )


@router.post("/answer", response_model=QuizAnswerResponse, status_code=200)
async def answer_quiz(
    body: QuizAnswerRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        result = await submit_quiz_answer(db, user, body)
    except QuizAnswerServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return QuizAnswerResponse(success=result.success)


@router.post("/complete", response_model=QuizCompleteResponse, status_code=200)
async def complete_quiz(
    body: QuizCompleteRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        result = await complete_quiz_session(db, user, body)
    except QuizCompleteServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return QuizCompleteResponse(
        session_id=result.session_id,
        correct_count=result.correct_count,
        total_questions=result.total_questions,
        accuracy=result.accuracy,
        xp_earned=result.xp_earned,
        level=result.level,
        current_xp=result.current_xp,
        xp_for_next=result.xp_for_next,
        events=result.events,
    )


@router.get("/incomplete", status_code=200)
async def get_incomplete_quiz(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """미완료 퀴즈 세션 조회 (배너용).

    - 1문제도 안 푼 세션(좀비)은 자동 완료 처리
    - 24시간 지난 세션은 자동 완료 처리
    """
    session = await get_incomplete_quiz_session(db, user)
    if session is None:
        return {"session": None}

    return {
        "session": {
            "id": session.id,
            "quizType": session.quiz_type,
            "jlptLevel": session.jlpt_level,
            "totalQuestions": session.total_questions,
            "answeredCount": session.answered_count,
            "correctCount": session.correct_count,
            "startedAt": session.started_at,
        }
    }


@router.post("/resume", status_code=200)
async def resume_quiz(
    body: QuizResumeRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        result = await resume_quiz_session(db, user, body)
    except QuizQueryServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return {
        "sessionId": result.session_id,
        "questions": [question.model_dump(by_alias=True) for question in result.questions],
        "answeredQuestionIds": result.answered_question_ids,
        "totalQuestions": result.total_questions,
        "correctCount": result.correct_count,
        "quizType": result.quiz_type,
    }


@router.get("/stats", status_code=200)
async def get_quiz_stats(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    level: str | None = None,
    quiz_type: Annotated[str | None, Query(alias="type")] = None,
):
    result = await get_quiz_stats_data(
        db,
        user,
        level=level,
        quiz_type=quiz_type,
    )
    if level and quiz_type:
        return {
            "totalCount": result.total_count,
            "studiedCount": result.studied_count,
            "progress": result.progress,
        }

    return {
        "totalQuizzes": result.total_quizzes,
        "totalCorrect": result.total_correct,
        "totalQuestions": result.total_questions,
        "accuracy": result.accuracy,
    }


@router.get("/wrong-answers", status_code=200)
async def get_wrong_answers(
    session_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        results = await get_wrong_answers_data(
            db,
            user,
            session_id=session_id,
        )
    except QuizQueryServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return {
        "wrongAnswers": [
            {
                "questionId": item.question_id,
                "word": item.word,
                "reading": item.reading,
                "meaningKo": item.meaning_ko,
                "exampleSentence": item.example_sentence,
                "exampleTranslation": item.example_translation,
            }
            for item in results
        ]
    }


@router.get("/smart-preview", response_model=SmartPreviewResponse, status_code=200)
async def smart_preview(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    category: Annotated[str, Query()] = "VOCABULARY",
    jlpt_level: Annotated[str, Query(alias="jlptLevel")] = "N5",
):
    preview = await build_smart_preview_data(
        db,
        user,
        category=category,
        jlpt_level=jlpt_level,
    )

    return SmartPreviewResponse(
        pool_size=PoolSize(
            new_ready=preview.pool_stats.new_ready,
            review_due=preview.pool_stats.review_due,
            retry_due=preview.pool_stats.retry_due,
        ),
        session_distribution=SessionDistribution(
            new=preview.distribution["new"],
            review=preview.distribution["review"],
            retry=preview.distribution["retry"],
            total=preview.distribution["new"] + preview.distribution["review"] + preview.distribution["retry"],
        ),
        daily_goal=preview.daily_goal,
        today_completed=preview.today_completed,
        overall_progress=OverallProgress(
            total=preview.pool_stats.total,
            studied=preview.pool_stats.studied,
            mastered=preview.pool_stats.mastered,
            percentage=round(preview.pool_stats.studied / preview.pool_stats.total * 100) if preview.pool_stats.total > 0 else 0,
        ),
    )


@router.post("/smart-start", response_model=QuizStartResponse, status_code=200)
async def smart_start(
    body: SmartStartRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    try:
        result = await start_smart_quiz_session(db, user, body)
    except QuizStartServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    response_questions = build_response_questions(result.questions)

    return QuizStartResponse(
        session_id=result.session.id,
        questions=response_questions,
        total_questions=len(result.questions),
        matching_pairs=None,
    )


@router.get("/recommendations", status_code=200)
async def get_recommendations(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    category: Annotated[str | None, Query()] = None,
):
    result = await get_recommendations_data(
        db,
        user,
        category=category,
    )

    return {
        "reviewDueCount": result.review_due_count,
        "newWordsCount": result.new_words_count,
        "wrongCount": result.wrong_count,
        "lastReviewedAt": result.last_reviewed_at,
    }
