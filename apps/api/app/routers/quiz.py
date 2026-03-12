from __future__ import annotations

import contextlib
import random
import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import (
    ClozeQuestion,
    DailyProgress,
    Grammar,
    QuizAnswer,
    QuizSession,
    SentenceArrangeQuestion,
    UserGrammarProgress,
    UserVocabProgress,
    Vocabulary,
)
from app.models.user import User
from app.schemas.quiz import (
    QuizAnswerRequest,
    QuizAnswerResponse,
    QuizCompleteRequest,
    QuizCompleteResponse,
    QuizOption,
    QuizQuestion,
    QuizResumeRequest,
    QuizStartRequest,
    QuizStartResponse,
)
from app.services.gamification import (
    calculate_level,
    check_and_grant_achievements,
    update_streak,
)
from app.utils.constants import QUIZ_CONFIG, REWARDS, SRS_CONFIG
from app.utils.date import get_today_kst

router = APIRouter(prefix="/api/v1/quiz", tags=["quiz"])


def _shuffle(items: list) -> list:
    result = items.copy()
    random.shuffle(result)
    return result


async def _auto_complete_sessions(db: AsyncSession, user: User) -> int:
    """Auto-complete incomplete sessions and return aggregated XP."""
    result = await db.execute(
        select(QuizSession).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.is_(None),
        )
    )
    incomplete = result.scalars().all()
    total_xp = 0

    for session in incomplete:
        session.completed_at = datetime.now(UTC)
        xp = session.correct_count * REWARDS.QUIZ_XP_PER_CORRECT
        total_xp += xp

    if total_xp > 0:
        user.experience_points += total_xp
        level_info = calculate_level(user.experience_points)
        user.level = level_info["level"]

    await db.flush()
    return total_xp


async def _generate_normal_questions(db: AsyncSession, user: User, quiz_type: str, jlpt_level: str, count: int) -> list[dict[str, Any]]:
    """Generate mixed new + review questions for normal mode."""
    questions: list[dict[str, Any]] = []
    review_count = max(1, int(count * 0.2))
    new_count = count - review_count

    if quiz_type in ("VOCABULARY", "KANJI", "LISTENING"):
        # Fetch review items first
        review_result = await db.execute(
            select(Vocabulary)
            .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
            .where(
                UserVocabProgress.user_id == user.id,
                Vocabulary.jlpt_level == jlpt_level,
                UserVocabProgress.next_review_at <= datetime.now(UTC),
            )
            .order_by(UserVocabProgress.next_review_at)
            .limit(review_count)
        )
        review_items = review_result.scalars().all()

        # Fetch new items (exclude already studied)
        studied_ids_result = await db.execute(select(UserVocabProgress.vocabulary_id).where(UserVocabProgress.user_id == user.id))
        studied_ids = set(studied_ids_result.scalars().all())

        new_result = await db.execute(
            select(Vocabulary)
            .where(
                Vocabulary.jlpt_level == jlpt_level,
                Vocabulary.id.notin_(studied_ids) if studied_ids else True,
            )
            .order_by(func.random())
            .limit(new_count)
        )
        new_items = new_result.scalars().all()

        # Combine and deduplicate by meaning_ko
        all_items = list(review_items) + list(new_items)
        seen_meanings: set[str] = set()
        unique_items = []
        for item in all_items:
            if item.meaning_ko not in seen_meanings:
                seen_meanings.add(item.meaning_ko)
                unique_items.append(item)

        # Get wrong options pool
        pool_result = await db.execute(
            select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
        )
        all_meanings = [r for r in pool_result.scalars().all()]

        for vocab in unique_items[:count]:
            wrong_options = [m for m in all_meanings if m != vocab.meaning_ko]
            random.shuffle(wrong_options)
            wrong_options = wrong_options[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT]

            correct_id = str(uuid.uuid4())
            options = [QuizOption(id=correct_id, text=vocab.meaning_ko).model_dump()]
            for wo in wrong_options:
                options.append(QuizOption(id=str(uuid.uuid4()), text=wo).model_dump())
            random.shuffle(options)

            questions.append(
                {
                    "id": str(vocab.id),
                    "type": quiz_type,
                    "question": vocab.word,
                    "reading": vocab.reading,
                    "options": options,
                    "correctOptionId": correct_id,
                    "word": vocab.word,
                    "meaningKo": vocab.meaning_ko,
                }
            )
    else:
        # Grammar
        result = await db.execute(select(Grammar).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(count))
        items = result.scalars().all()

        pool_result = await db.execute(select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50))
        all_meanings = list(pool_result.scalars().all())

        for grammar in items:
            wrong_options = [m for m in all_meanings if m != grammar.meaning_ko]
            random.shuffle(wrong_options)
            wrong_options = wrong_options[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT]

            correct_id = str(uuid.uuid4())
            options = [QuizOption(id=correct_id, text=grammar.meaning_ko).model_dump()]
            for wo in wrong_options:
                options.append(QuizOption(id=str(uuid.uuid4()), text=wo).model_dump())
            random.shuffle(options)

            questions.append(
                {
                    "id": str(grammar.id),
                    "type": quiz_type,
                    "question": grammar.pattern,
                    "options": options,
                    "correctOptionId": correct_id,
                    "pattern": grammar.pattern,
                    "meaningKo": grammar.meaning_ko,
                }
            )

    return questions


@router.post("/start", response_model=QuizStartResponse)
async def start_quiz(
    body: QuizStartRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    # Auto-complete incomplete sessions
    await _auto_complete_sessions(db, user)

    mode = body.mode
    quiz_type = body.quiz_type.value
    jlpt_level = body.jlpt_level.value
    count = body.count

    questions: list[dict[str, Any]] = []

    if mode == "cloze":
        result = await db.execute(select(ClozeQuestion).where(ClozeQuestion.jlpt_level == jlpt_level).order_by(func.random()).limit(count))
        items = result.scalars().all()
        for item in items:
            correct_id = str(uuid.uuid4())
            opts = []
            for opt_text in item.options if isinstance(item.options, list) else []:
                oid = correct_id if opt_text == item.correct_answer else str(uuid.uuid4())
                opts.append({"id": oid, "text": opt_text})
            questions.append(
                {
                    "id": str(item.id),
                    "type": "CLOZE",
                    "question": item.sentence,
                    "translation": item.translation,
                    "options": opts,
                    "correctOptionId": correct_id,
                    "explanation": item.explanation,
                }
            )

    elif mode == "arrange":
        result = await db.execute(
            select(SentenceArrangeQuestion).where(SentenceArrangeQuestion.jlpt_level == jlpt_level).order_by(func.random()).limit(count)
        )
        items = result.scalars().all()
        for item in items:
            questions.append(
                {
                    "id": str(item.id),
                    "type": "SENTENCE_ARRANGE",
                    "question": item.korean_sentence,
                    "japaneseSentence": item.japanese_sentence,
                    "tokens": item.tokens,
                    "explanation": item.explanation,
                    "correctOptionId": "",
                    "options": [],
                }
            )

    elif mode == "review":
        if quiz_type in ("VOCABULARY", "KANJI", "LISTENING"):
            result = await db.execute(
                select(Vocabulary)
                .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
                .where(
                    UserVocabProgress.user_id == user.id,
                    Vocabulary.jlpt_level == jlpt_level,
                    UserVocabProgress.next_review_at <= datetime.now(UTC),
                )
                .order_by(UserVocabProgress.next_review_at)
                .limit(count)
            )
            review_items = result.scalars().all()
            pool_result = await db.execute(
                select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
            )
            all_meanings = list(pool_result.scalars().all())

            for vocab in review_items:
                wrong = [m for m in all_meanings if m != vocab.meaning_ko][:3]
                correct_id = str(uuid.uuid4())
                options = [{"id": correct_id, "text": vocab.meaning_ko}]
                for w in wrong:
                    options.append({"id": str(uuid.uuid4()), "text": w})
                random.shuffle(options)
                questions.append(
                    {
                        "id": str(vocab.id),
                        "type": quiz_type,
                        "question": vocab.word,
                        "options": options,
                        "correctOptionId": correct_id,
                        "word": vocab.word,
                        "meaningKo": vocab.meaning_ko,
                    }
                )
        else:
            result = await db.execute(
                select(Grammar)
                .join(UserGrammarProgress, UserGrammarProgress.grammar_id == Grammar.id)
                .where(
                    UserGrammarProgress.user_id == user.id,
                    Grammar.jlpt_level == jlpt_level,
                    UserGrammarProgress.next_review_at <= datetime.now(UTC),
                )
                .limit(count)
            )
            items = result.scalars().all()
            pool_result = await db.execute(
                select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
            )
            all_meanings = list(pool_result.scalars().all())
            for g in items:
                wrong = [m for m in all_meanings if m != g.meaning_ko][:3]
                correct_id = str(uuid.uuid4())
                options = [{"id": correct_id, "text": g.meaning_ko}]
                for w in wrong:
                    options.append({"id": str(uuid.uuid4()), "text": w})
                random.shuffle(options)
                questions.append(
                    {
                        "id": str(g.id),
                        "type": quiz_type,
                        "question": g.pattern,
                        "options": options,
                        "correctOptionId": correct_id,
                        "pattern": g.pattern,
                        "meaningKo": g.meaning_ko,
                    }
                )
    else:
        # normal mode
        questions = await _generate_normal_questions(db, user, quiz_type, jlpt_level, count)

    # Create session
    session = QuizSession(
        user_id=user.id,
        quiz_type=body.quiz_type,
        jlpt_level=body.jlpt_level,
        total_questions=len(questions),
        questions_data=questions,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)

    # Include correctOptionId for mobile client-side validation
    response_questions = []
    for q in questions:
        response_questions.append(
            QuizQuestion(
                question_id=q["id"],
                question_text=q["question"],
                question_sub_text=q.get("questionSubText"),
                hint=q.get("hint"),
                options=[QuizOption(**o) for o in q["options"]],
                correct_option_id=q.get("correctOptionId"),
            )
        )

    return QuizStartResponse(
        session_id=session.id,
        questions=response_questions,
        total_questions=len(questions),
    )


@router.post("/answer", response_model=QuizAnswerResponse)
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

    # Verify answer from questionsData
    questions_data = session.questions_data or []
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

        if is_correct:
            progress.correct_count += 1
            progress.streak += 1
            if progress.streak <= 1:
                progress.interval = SRS_CONFIG.INITIAL_INTERVALS[0]
            elif progress.streak == 2:
                progress.interval = SRS_CONFIG.INITIAL_INTERVALS[1]
            else:
                progress.interval = round(progress.interval * progress.ease_factor)
            progress.ease_factor = max(
                SRS_CONFIG.MIN_EASE_FACTOR,
                progress.ease_factor + 0.1,
            )
        else:
            progress.incorrect_count += 1
            progress.streak = 0
            progress.interval = 0
            progress.ease_factor = max(
                SRS_CONFIG.MIN_EASE_FACTOR,
                progress.ease_factor - SRS_CONFIG.INCORRECT_PENALTY,
            )

        progress.next_review_at = (
            now + timedelta(days=progress.interval) if progress.interval > 0 else now + timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES)
        )
        progress.last_reviewed_at = now
        progress.mastered = progress.interval >= SRS_CONFIG.MASTERY_INTERVAL

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

        if is_correct:
            progress.correct_count += 1
            progress.streak += 1
            if progress.streak <= 1:
                progress.interval = SRS_CONFIG.INITIAL_INTERVALS[0]
            elif progress.streak == 2:
                progress.interval = SRS_CONFIG.INITIAL_INTERVALS[1]
            else:
                progress.interval = round(progress.interval * progress.ease_factor)
            progress.ease_factor = max(SRS_CONFIG.MIN_EASE_FACTOR, progress.ease_factor + 0.1)
        else:
            progress.incorrect_count += 1
            progress.streak = 0
            progress.interval = 0
            progress.ease_factor = max(SRS_CONFIG.MIN_EASE_FACTOR, progress.ease_factor - SRS_CONFIG.INCORRECT_PENALTY)

        progress.next_review_at = (
            now + timedelta(days=progress.interval) if progress.interval > 0 else now + timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES)
        )
        progress.last_reviewed_at = now
        progress.mastered = progress.interval >= SRS_CONFIG.MASTERY_INTERVAL

    await db.commit()
    return QuizAnswerResponse(success=True)


@router.post("/complete", response_model=QuizCompleteResponse)
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

    # Update daily progress
    stmt = pg_insert(DailyProgress).values(
        user_id=user.id,
        date=today,
        quizzes_completed=1,
        correct_answers=session.correct_count,
        total_answers=session.total_questions,
        xp_earned=xp_earned,
        words_studied=session.correct_count,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_={
            "quizzes_completed": DailyProgress.quizzes_completed + 1,
            "correct_answers": DailyProgress.correct_answers + session.correct_count,
            "total_answers": DailyProgress.total_answers + session.total_questions,
            "xp_earned": DailyProgress.xp_earned + xp_earned,
            "words_studied": DailyProgress.words_studied + session.correct_count,
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


@router.get("/incomplete")
async def get_incomplete_quiz(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """미완료 퀴즈 세션 조회 (배너용)."""
    result = await db.execute(
        select(QuizSession)
        .where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.is_(None),
        )
        .order_by(QuizSession.started_at.desc())
        .limit(1)
    )
    session = result.scalar_one_or_none()
    if not session:
        return {"session": None}

    # Count answered questions
    answered_result = await db.execute(select(func.count(QuizAnswer.id)).where(QuizAnswer.session_id == session.id))
    answered_count = answered_result.scalar() or 0

    return {
        "session": {
            "id": str(session.id),
            "quizType": session.quiz_type.value if hasattr(session.quiz_type, "value") else session.quiz_type,
            "jlptLevel": session.jlpt_level.value if hasattr(session.jlpt_level, "value") else session.jlpt_level,
            "totalQuestions": session.total_questions,
            "answeredCount": answered_count,
            "correctCount": session.correct_count,
            "startedAt": session.started_at.isoformat() if session.started_at else "",
        }
    }


@router.post("/resume")
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

    questions = session.questions_data or []
    response_questions = []
    for q in questions:
        response_questions.append(
            QuizQuestion(
                question_id=q["id"],
                question_text=q["question"],
                question_sub_text=q.get("questionSubText"),
                hint=q.get("hint"),
                options=[QuizOption(**o) for o in q["options"]],
                correct_option_id=q.get("correctOptionId"),
            )
        )

    quiz_type = session.quiz_type.value if hasattr(session.quiz_type, "value") else session.quiz_type

    return {
        "sessionId": str(session.id),
        "questions": [q.model_dump(by_alias=True) for q in response_questions],
        "answeredQuestionIds": answered_ids,
        "totalQuestions": session.total_questions,
        "correctCount": session.correct_count,
        "quizType": quiz_type,
    }


@router.get("/stats")
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


@router.get("/wrong-answers")
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

    questions_data = session.questions_data or []
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


@router.get("/recommendations")
async def get_recommendations(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    now = datetime.now(UTC)

    # Count due review items (vocab + grammar)
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
