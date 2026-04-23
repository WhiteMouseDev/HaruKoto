from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.quiz import (
    ContentQuizStatsResponse,
    IncompleteQuizResponse,
    IncompleteQuizSession,
    OverallProgress,
    PoolSize,
    QuizAnswerRequest,
    QuizAnswerResponse,
    QuizCompleteRequest,
    QuizCompleteResponse,
    QuizResumeRequest,
    QuizResumeResponse,
    QuizStartRequest,
    QuizStartResponse,
    QuizStatsResponse,
    RecommendationsResponse,
    SessionDistribution,
    SmartPreviewResponse,
    SmartStartRequest,
    WrongAnswer,
    WrongAnswersResponse,
)
from app.services.quiz_answer import QuizAnswerServiceError, submit_quiz_answer
from app.services.quiz_complete import QuizCompleteServiceError, complete_quiz_session
from app.services.quiz_query import (
    QuizQueryServiceError,
    get_incomplete_quiz_session,
    get_wrong_answers_data,
    resume_quiz_session,
)
from app.services.quiz_recommendations import get_recommendations_data
from app.services.quiz_session import build_response_questions
from app.services.quiz_smart import build_smart_preview_data
from app.services.quiz_start import (
    QuizStartServiceError,
    start_quiz_session,
    start_smart_quiz_session,
)
from app.services.quiz_stats_query import ContentQuizStatsResult, QuizStatsResult, get_quiz_stats_data

router = APIRouter(prefix="/api/v1/quiz", tags=["quiz"])


@router.post("/start", response_model=QuizStartResponse, status_code=200)
async def start_quiz(
    body: QuizStartRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> QuizStartResponse:
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
) -> QuizAnswerResponse:
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
) -> QuizCompleteResponse:
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


@router.get("/incomplete", response_model=IncompleteQuizResponse, status_code=200)
async def get_incomplete_quiz(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> IncompleteQuizResponse:
    """미완료 퀴즈 세션 조회 (배너용).

    - 1문제도 안 푼 세션(좀비)은 자동 완료 처리
    - 24시간 지난 세션은 자동 완료 처리
    """
    session = await get_incomplete_quiz_session(db, user)
    if session is None:
        return IncompleteQuizResponse(session=None)

    return IncompleteQuizResponse(
        session=IncompleteQuizSession(
            id=session.id,
            quiz_type=session.quiz_type,
            jlpt_level=session.jlpt_level,
            total_questions=session.total_questions,
            answered_count=session.answered_count,
            correct_count=session.correct_count,
            started_at=session.started_at,
        )
    )


@router.post("/resume", response_model=QuizResumeResponse, status_code=200)
async def resume_quiz(
    body: QuizResumeRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> QuizResumeResponse:
    try:
        result = await resume_quiz_session(db, user, body)
    except QuizQueryServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return QuizResumeResponse(
        session_id=result.session_id,
        questions=result.questions,
        answered_question_ids=result.answered_question_ids,
        total_questions=result.total_questions,
        correct_count=result.correct_count,
        quiz_type=result.quiz_type,
    )


@router.get("/stats", response_model=QuizStatsResponse | ContentQuizStatsResponse, status_code=200)
async def get_quiz_stats(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    level: str | None = None,
    quiz_type: Annotated[str | None, Query(alias="type")] = None,
) -> QuizStatsResponse | ContentQuizStatsResponse:
    result = await get_quiz_stats_data(
        db,
        user,
        level=level,
        quiz_type=quiz_type,
    )
    if isinstance(result, ContentQuizStatsResult):
        return ContentQuizStatsResponse(
            total_count=result.total_count,
            studied_count=result.studied_count,
            progress=result.progress,
        )

    if not isinstance(result, QuizStatsResult):
        raise HTTPException(status_code=500, detail="퀴즈 통계 응답을 생성할 수 없습니다")

    return QuizStatsResponse(
        total_quizzes=result.total_quizzes,
        total_correct=result.total_correct,
        total_questions=result.total_questions,
        accuracy=result.accuracy,
    )


@router.get("/wrong-answers", response_model=WrongAnswersResponse, status_code=200)
async def get_wrong_answers(
    session_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> WrongAnswersResponse:
    try:
        results = await get_wrong_answers_data(
            db,
            user,
            session_id=session_id,
        )
    except QuizQueryServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return WrongAnswersResponse(
        wrong_answers=[
            WrongAnswer(
                question_id=item.question_id,
                word=item.word,
                reading=item.reading,
                meaning_ko=item.meaning_ko,
                example_sentence=item.example_sentence,
                example_translation=item.example_translation,
            )
            for item in results
        ]
    )


@router.get("/smart-preview", response_model=SmartPreviewResponse, status_code=200)
async def smart_preview(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    category: Annotated[str, Query()] = "VOCABULARY",
    jlpt_level: Annotated[str, Query(alias="jlptLevel")] = "N5",
) -> SmartPreviewResponse:
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
) -> QuizStartResponse:
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


@router.get("/recommendations", response_model=RecommendationsResponse, status_code=200)
async def get_recommendations(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    category: Annotated[str | None, Query()] = None,
) -> RecommendationsResponse:
    result = await get_recommendations_data(
        db,
        user,
        category=category,
    )

    return RecommendationsResponse(
        review_due_count=result.review_due_count,
        new_words_count=result.new_words_count,
        wrong_count=result.wrong_count,
        last_reviewed_at=result.last_reviewed_at,
    )
