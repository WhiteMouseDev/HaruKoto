from __future__ import annotations

import contextlib
import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import (
    DailyProgress,
    Grammar,
    QuizAnswer,
    QuizSession,
    UserGrammarProgress,
    UserStudyStageProgress,
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
from app.services.gamification import (
    calculate_level,
    check_and_grant_achievements,
    update_streak,
)
from app.services.quiz_policy import apply_srs_update
from app.services.quiz_session import (
    build_response_questions,
    extract_questions_data,
)
from app.services.quiz_smart import build_smart_preview_data
from app.services.quiz_start import QuizStartServiceError, start_quiz_session, start_smart_quiz_session
from app.services.srs import log_review_event
from app.utils.constants import REWARDS
from app.utils.date import get_today_kst
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
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")
    if session.completed_at:
        raise HTTPException(status_code=400, detail="이미 완료된 세션입니다")

    # Verify answer from questionsData (handle both list and dict formats)
    questions_data = extract_questions_data(session.questions_data)
    question_data = None
    for q in questions_data:
        if q["id"] == str(body.question_id):
            question_data = q
            break

    if not question_data:
        raise HTTPException(status_code=400, detail="질문을 찾을 수 없습니다")

    correct_option_id = question_data.get("correctOptionId", "")
    is_correct = body.selected_option_id == correct_option_id

    # Create answer record
    answer = QuizAnswer(
        session_id=session.id,
        question_id=body.question_id,
        question_type=body.question_type,
        selected_option_id=body.selected_option_id,
        is_correct=is_correct,
        time_spent_seconds=body.time_spent_seconds,
    )
    db.add(answer)

    if is_correct:
        session.correct_count += 1

    # Update spaced repetition progress
    question_type = body.question_type.value
    now = datetime.now(UTC)

    if question_type in ("VOCABULARY", "KANJI", "LISTENING"):
        progress_result = await db.execute(
            select(UserVocabProgress).where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.vocabulary_id == body.question_id,
            )
        )
        progress = progress_result.scalar_one_or_none()

        if progress is None:
            progress = UserVocabProgress(
                user_id=user.id,
                vocabulary_id=body.question_id,
            )
            db.add(progress)
            await db.flush()

        state_before = getattr(progress, "state", "UNSEEN") or "UNSEEN"
        apply_srs_update(progress, is_correct, body.time_spent_seconds, now)
        with contextlib.suppress(Exception):
            await log_review_event(
                db,
                user.id,
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

    elif question_type == "GRAMMAR":
        progress_result = await db.execute(
            select(UserGrammarProgress).where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.grammar_id == body.question_id,
            )
        )
        progress = progress_result.scalar_one_or_none()

        if progress is None:
            progress = UserGrammarProgress(
                user_id=user.id,
                grammar_id=body.question_id,
            )
            db.add(progress)
            await db.flush()

        state_before_g = getattr(progress, "state", "UNSEEN") or "UNSEEN"
        apply_srs_update(progress, is_correct, body.time_spent_seconds, now)
        with contextlib.suppress(Exception):
            await log_review_event(
                db,
                user.id,
                "GRAMMAR",
                body.question_id,
                session.id,
                None,
                "JP_KR",
                is_correct,
                body.time_spent_seconds * 1000,
                3 if is_correct else 1,
                state_before_g,
                getattr(progress, "state", state_before_g) or state_before_g,
                None,
                getattr(progress, "state", "") == "PROVISIONAL",
                state_before_g == "UNSEEN",
                now.date(),
            )

    await db.commit()
    return QuizAnswerResponse(success=True)


@router.post("/complete", response_model=QuizCompleteResponse, status_code=200)
async def complete_quiz(
    body: QuizCompleteRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")

    # Idempotency
    if session.completed_at:
        level_info = calculate_level(user.experience_points)
        accuracy = (session.correct_count / session.total_questions * 100) if session.total_questions > 0 else 0
        return QuizCompleteResponse(
            session_id=session.id,
            correct_count=session.correct_count,
            total_questions=session.total_questions,
            accuracy=accuracy,
            xp_earned=0,
            level=level_info["level"],
            current_xp=level_info["current_xp"],
            xp_for_next=level_info["xp_for_next"],
            events=[],
        )

    session.completed_at = datetime.now(UTC)
    xp_earned = session.correct_count * REWARDS.QUIZ_XP_PER_CORRECT
    old_level = user.level
    user.experience_points += xp_earned
    level_info = calculate_level(user.experience_points)
    user.level = level_info["level"]

    # Update streak
    today = get_today_kst()
    streak_info = update_streak(user.last_study_date, user.streak_count, user.longest_streak, today)
    user.streak_count = streak_info["streak_count"]
    user.longest_streak = streak_info["longest_streak"]
    user.last_study_date = datetime.now(UTC)

    # Calculate study duration in minutes from session start
    study_duration_minutes = 0
    if session.started_at:
        started = session.started_at.replace(tzinfo=UTC) if session.started_at.tzinfo is None else session.started_at
        delta = datetime.now(UTC) - started
        study_duration_minutes = max(0, int(delta.total_seconds() / 60))

    # Determine per-category counters based on quiz_type
    quiz_type_val = enum_value(session.quiz_type)
    words_increment = session.correct_count if quiz_type_val in ("VOCABULARY", "KANJI", "LISTENING") else 0
    grammar_increment = session.correct_count if quiz_type_val == "GRAMMAR" else 0
    sentences_increment = session.total_questions if quiz_type_val in ("CLOZE", "SENTENCE_ARRANGE") else 0

    # Update daily progress
    stmt = pg_insert(DailyProgress).values(
        user_id=user.id,
        date=today,
        quizzes_completed=1,
        correct_answers=session.correct_count,
        total_answers=session.total_questions,
        xp_earned=xp_earned,
        words_studied=words_increment,
        grammar_studied=grammar_increment,
        sentences_studied=sentences_increment,
        study_minutes=study_duration_minutes,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_={
            "quizzes_completed": DailyProgress.quizzes_completed + 1,
            "correct_answers": DailyProgress.correct_answers + session.correct_count,
            "total_answers": DailyProgress.total_answers + session.total_questions,
            "xp_earned": DailyProgress.xp_earned + xp_earned,
            "words_studied": DailyProgress.words_studied + words_increment,
            "grammar_studied": func.coalesce(DailyProgress.grammar_studied, 0) + grammar_increment,
            "sentences_studied": func.coalesce(DailyProgress.sentences_studied, 0) + sentences_increment,
            "study_minutes": func.coalesce(DailyProgress.study_minutes, 0) + study_duration_minutes,
        },
    )
    await db.execute(stmt)

    # Count total quizzes for achievements
    quiz_count_result = await db.execute(
        select(func.count(QuizSession.id)).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.isnot(None),
        )
    )
    quiz_count = quiz_count_result.scalar() or 0

    words_count_result = await db.execute(select(func.count(UserVocabProgress.id)).where(UserVocabProgress.user_id == user.id))
    words_count = words_count_result.scalar() or 0

    accuracy = (session.correct_count / session.total_questions * 100) if session.total_questions > 0 else 0
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

    # Update stage progress if stage_id is provided
    stage_id = body.stage_id
    # Also check if stage_id was stored in session metadata
    if not stage_id:
        qdata = session.questions_data
        if isinstance(qdata, dict) and "stage_id" in qdata:
            with contextlib.suppress(ValueError):
                stage_id = uuid.UUID(qdata["stage_id"])

    if stage_id:
        now = datetime.now(UTC)
        score_pct = round(accuracy)

        stage_progress_result = await db.execute(
            select(UserStudyStageProgress).where(
                UserStudyStageProgress.user_id == user.id,
                UserStudyStageProgress.stage_id == stage_id,
            )
        )
        stage_progress = stage_progress_result.scalar_one_or_none()

        if stage_progress is None:
            stage_progress = UserStudyStageProgress(
                user_id=user.id,
                stage_id=stage_id,
                best_score=score_pct,
                attempts=1,
                completed=score_pct >= 70,
                completed_at=now if score_pct >= 70 else None,
                last_attempted_at=now,
            )
            db.add(stage_progress)
        else:
            stage_progress.attempts = (stage_progress.attempts or 0) + 1
            stage_progress.last_attempted_at = now
            if score_pct > (stage_progress.best_score or 0):
                stage_progress.best_score = score_pct
            if score_pct >= 70 and not stage_progress.completed:
                stage_progress.completed = True
                stage_progress.completed_at = now

    await db.commit()

    return QuizCompleteResponse(
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
