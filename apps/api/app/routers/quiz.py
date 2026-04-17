from __future__ import annotations

import contextlib
import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import (
    Grammar,
    QuizAnswer,
    QuizSession,
    UserGrammarProgress,
    UserVocabProgress,
    Vocabulary,
)
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
from app.services.quiz_session import (
    build_response_questions,
    extract_questions_data,
)
from app.services.quiz_smart import build_smart_preview_data
from app.services.quiz_start import QuizStartServiceError, start_quiz_session, start_smart_quiz_session
from app.utils.helpers import enum_value

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

    valid_session = None
    for session in sessions:
        # Count answered questions
        answered_result = await db.execute(select(func.count(QuizAnswer.id)).where(QuizAnswer.session_id == session.id))
        answered_count = answered_result.scalar() or 0

        # Auto-complete zombie sessions (0 answers) or stale sessions (24h+)
        if answered_count == 0 or (session.started_at and session.started_at < cutoff):
            session.completed_at = datetime.now(UTC)
            continue

        if valid_session is None:
            valid_session = (session, answered_count)

    await db.commit()

    if not valid_session:
        return {"session": None}

    session, answered_count = valid_session
    return {
        "session": {
            "id": str(session.id),
            "quizType": enum_value(session.quiz_type),
            "jlptLevel": enum_value(session.jlpt_level),
            "totalQuestions": session.total_questions,
            "answeredCount": answered_count,
            "correctCount": session.correct_count,
            "startedAt": session.started_at.isoformat() if session.started_at else "",
        }
    }


@router.post("/resume", status_code=200)
async def resume_quiz(
    body: QuizResumeRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")
    if session.completed_at:
        raise HTTPException(status_code=400, detail="이미 완료된 세션입니다")

    answered_result = await db.execute(select(QuizAnswer.question_id).where(QuizAnswer.session_id == session.id))
    answered_ids = [str(qid) for qid in answered_result.scalars().all()]

    questions = extract_questions_data(session.questions_data)
    response_questions = build_response_questions(questions)

    quiz_type = enum_value(session.quiz_type)

    return {
        "sessionId": str(session.id),
        "questions": [q.model_dump(by_alias=True) for q in response_questions],
        "answeredQuestionIds": answered_ids,
        "totalQuestions": session.total_questions,
        "correctCount": session.correct_count,
        "quizType": quiz_type,
    }


@router.get("/stats", status_code=200)
async def get_quiz_stats(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    level: str | None = None,
    quiz_type: Annotated[str | None, Query(alias="type")] = None,
):
    # If level and type provided, return content-level stats
    if level and quiz_type:
        if quiz_type in ("VOCABULARY", "KANJI", "LISTENING"):
            total_result = await db.execute(select(func.count(Vocabulary.id)).where(Vocabulary.jlpt_level == level))
            total_count = total_result.scalar() or 0

            studied_result = await db.execute(
                select(func.count(UserVocabProgress.id))
                .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
                .where(
                    UserVocabProgress.user_id == user.id,
                    Vocabulary.jlpt_level == level,
                )
            )
            studied_count = studied_result.scalar() or 0
        else:
            # GRAMMAR
            total_result = await db.execute(select(func.count(Grammar.id)).where(Grammar.jlpt_level == level))
            total_count = total_result.scalar() or 0

            studied_result = await db.execute(
                select(func.count(UserGrammarProgress.id))
                .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
                .where(
                    UserGrammarProgress.user_id == user.id,
                    Grammar.jlpt_level == level,
                )
            )
            studied_count = studied_result.scalar() or 0

        progress = round(studied_count / total_count * 100) if total_count > 0 else 0
        return {
            "totalCount": total_count,
            "studiedCount": studied_count,
            "progress": progress,
        }

    # Default: overall quiz stats
    total_result = await db.execute(
        select(func.count(QuizSession.id)).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.isnot(None),
        )
    )
    total_result2 = await db.execute(
        select(
            func.sum(QuizSession.correct_count),
            func.sum(QuizSession.total_questions),
        ).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.isnot(None),
        )
    )
    row = total_result2.one()
    total_correct = row[0] or 0
    total_questions = row[1] or 0

    return {
        "totalQuizzes": total_result.scalar() or 0,
        "totalCorrect": total_correct,
        "totalQuestions": total_questions,
        "accuracy": (total_correct / total_questions * 100) if total_questions > 0 else 0,
    }


@router.get("/wrong-answers", status_code=200)
async def get_wrong_answers(
    session_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    session = await db.get(QuizSession, uuid.UUID(session_id))
    if not session or session.user_id != user.id:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")

    wrong_result = await db.execute(
        select(QuizAnswer).where(
            QuizAnswer.session_id == session.id,
            QuizAnswer.is_correct.is_(False),
        )
    )
    wrong_answers = wrong_result.scalars().all()

    questions_data = extract_questions_data(session.questions_data)
    q_map = {q["id"]: q for q in questions_data}

    # Collect vocabulary IDs from wrong answers for example sentences
    wrong_vocab_ids = []
    for wa in wrong_answers:
        q = q_map.get(str(wa.question_id))
        if q and q.get("type") in ("VOCABULARY", "KANJI", "LISTENING"):
            with contextlib.suppress(ValueError):
                wrong_vocab_ids.append(uuid.UUID(str(wa.question_id)))

    # Fetch vocabulary details for example sentences
    vocab_map: dict[str, Vocabulary] = {}
    if wrong_vocab_ids:
        vocab_result = await db.execute(select(Vocabulary).where(Vocabulary.id.in_(wrong_vocab_ids)))
        for v in vocab_result.scalars().all():
            vocab_map[str(v.id)] = v

    result_list = []
    for wa in wrong_answers:
        q = q_map.get(str(wa.question_id), {})
        vocab = vocab_map.get(str(wa.question_id))
        result_list.append(
            {
                "questionId": str(wa.question_id),
                "word": q.get("word"),
                "reading": q.get("reading") or (vocab.reading if vocab else None),
                "meaningKo": q.get("meaningKo"),
                "exampleSentence": vocab.example_sentence if vocab else None,
                "exampleTranslation": vocab.example_translation if vocab else None,
            }
        )

    return {"wrongAnswers": result_list}


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
    now = datetime.now(UTC)

    if category == "VOCABULARY":
        # Vocabulary-only recommendations
        due_result = await db.execute(
            select(func.count(UserVocabProgress.id)).where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.next_review_at <= now,
            )
        )
        review_due = due_result.scalar() or 0

        studied_count_result = await db.execute(select(func.count(UserVocabProgress.id)).where(UserVocabProgress.user_id == user.id))
        studied_count = studied_count_result.scalar() or 0
        total_result = await db.execute(select(func.count(Vocabulary.id)))
        total = total_result.scalar() or 0
        new_count = max(0, total - studied_count)

        wrong_result = await db.execute(
            select(func.count(UserVocabProgress.id)).where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.incorrect_count > 0,
            )
        )
        wrong_count = wrong_result.scalar() or 0

        last_reviewed_result = await db.execute(
            select(func.max(UserVocabProgress.last_reviewed_at)).where(UserVocabProgress.user_id == user.id)
        )
        last_reviewed = last_reviewed_result.scalar()

        return {
            "reviewDueCount": review_due,
            "newWordsCount": new_count,
            "wrongCount": wrong_count,
            "lastReviewedAt": last_reviewed.isoformat() if last_reviewed else None,
        }

    elif category == "GRAMMAR":
        # Grammar-only recommendations
        due_result = await db.execute(
            select(func.count(UserGrammarProgress.id)).where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.next_review_at <= now,
            )
        )
        review_due = due_result.scalar() or 0

        studied_count_result = await db.execute(select(func.count(UserGrammarProgress.id)).where(UserGrammarProgress.user_id == user.id))
        studied_count = studied_count_result.scalar() or 0
        total_result = await db.execute(select(func.count(Grammar.id)))
        total = total_result.scalar() or 0
        new_count = max(0, total - studied_count)

        wrong_result = await db.execute(
            select(func.count(UserGrammarProgress.id)).where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.incorrect_count > 0,
            )
        )
        wrong_count = wrong_result.scalar() or 0

        last_reviewed_result = await db.execute(
            select(func.max(UserGrammarProgress.last_reviewed_at)).where(UserGrammarProgress.user_id == user.id)
        )
        last_reviewed = last_reviewed_result.scalar()

        return {
            "reviewDueCount": review_due,
            "newWordsCount": new_count,
            "wrongCount": wrong_count,
            "lastReviewedAt": last_reviewed.isoformat() if last_reviewed else None,
        }

    elif category == "SENTENCE":
        # Sentence-based quizzes (cloze + arrange) — no SRS progress tracking yet
        return {
            "reviewDueCount": 0,
            "newWordsCount": 0,
            "wrongCount": 0,
            "lastReviewedAt": None,
        }

    # Default: overall (backward compatible)
    due_vocab_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.next_review_at <= now,
        )
    )
    due_grammar_result = await db.execute(
        select(func.count(UserGrammarProgress.id)).where(
            UserGrammarProgress.user_id == user.id,
            UserGrammarProgress.next_review_at <= now,
        )
    )
    vocab_due = due_vocab_result.scalar() or 0
    grammar_due = due_grammar_result.scalar() or 0

    # Count new words (vocab not yet studied by user)
    studied_count_result = await db.execute(select(func.count(UserVocabProgress.id)).where(UserVocabProgress.user_id == user.id))
    studied_count = studied_count_result.scalar() or 0
    total_vocab_result = await db.execute(select(func.count(Vocabulary.id)))
    total_vocab = total_vocab_result.scalar() or 0
    new_words_count = max(0, total_vocab - studied_count)

    # Count wrong answers
    wrong_count_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.incorrect_count > 0,
        )
    )
    wrong_count = wrong_count_result.scalar() or 0

    # Last reviewed at
    last_reviewed_result = await db.execute(
        select(func.max(UserVocabProgress.last_reviewed_at)).where(
            UserVocabProgress.user_id == user.id,
        )
    )
    last_reviewed = last_reviewed_result.scalar()

    return {
        "reviewDueCount": vocab_due + grammar_due,
        "newWordsCount": new_words_count,
        "wrongCount": wrong_count,
        "lastReviewedAt": last_reviewed.isoformat() if last_reviewed else None,
    }
