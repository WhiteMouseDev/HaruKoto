from __future__ import annotations

import random
import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import (
    DailyProgress,
    KanaCharacter,
    KanaLearningStage,
    QuizSession,
    UserKanaProgress,
    UserKanaStage,
)
from app.models.enums import KanaType, QuizType
from app.models.user import User
from app.schemas.kana import (
    KanaProgressRecord,
    KanaProgressResponse,
    KanaQuizAnswerRequest,
    KanaQuizAnswerResponse,
    KanaQuizStartRequest,
    KanaQuizStartResponse,
    KanaStageCompleteRequest,
    KanaStageCompleteResponse,
    KanaStat,
)
from app.services.gamification import calculate_level, check_and_grant_achievements, update_streak
from app.utils.constants import KANA_REWARDS
from app.utils.date import get_today_kst

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
FIRST_STAGE_NUMBER = 1
KANA_MASTERY_STREAK = 3

router = APIRouter(prefix="/api/v1/kana", tags=["kana"])


@router.get("/characters", status_code=200)
async def get_characters(
    kana_type: KanaType | None = None,
    db: AsyncSession = Depends(get_db),
):
    query = select(KanaCharacter).order_by(KanaCharacter.order)
    if kana_type:
        query = query.where(KanaCharacter.kana_type == kana_type)
    result = await db.execute(query)
    characters = result.scalars().all()

    return [
        {
            "id": str(c.id),
            "kanaType": c.kana_type.value,
            "character": c.character,
            "romaji": c.romaji,
            "pronunciation": c.pronunciation,
            "row": c.row,
            "column": c.column,
            "strokeCount": c.stroke_count,
            "strokeOrder": c.stroke_order,
            "audioUrl": c.audio_url,
            "exampleWord": c.example_word,
            "exampleReading": c.example_reading,
            "exampleMeaning": c.example_meaning,
            "category": c.category,
            "order": c.order,
        }
        for c in characters
    ]


@router.get("/stages", status_code=200)
async def get_stages(
    kana_type: KanaType | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(KanaLearningStage).order_by(KanaLearningStage.order)
    if kana_type:
        query = query.where(KanaLearningStage.kana_type == kana_type)
    result = await db.execute(query)
    stages = result.scalars().all()

    # Get user stage progress
    stage_progress_result = await db.execute(select(UserKanaStage).where(UserKanaStage.user_id == user.id))
    user_stages = {str(us.stage_id): us for us in stage_progress_result.scalars().all()}

    response = []
    for stage in stages:
        us = user_stages.get(str(stage.id))
        response.append(
            {
                "id": str(stage.id),
                "kanaType": stage.kana_type.value,
                "stageNumber": stage.stage_number,
                "title": stage.title,
                "description": stage.description,
                "characters": stage.characters,
                "isUnlocked": us.is_unlocked if us else (stage.stage_number == FIRST_STAGE_NUMBER),
                "isCompleted": us.is_completed if us else False,
                "quizScore": us.quiz_score if us else None,
            }
        )

    return response


@router.get("/progress", response_model=KanaProgressResponse, status_code=200)
async def get_progress(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Batch: totals per kana_type (1 query instead of 2)
    total_result = await db.execute(select(KanaCharacter.kana_type, func.count(KanaCharacter.id)).group_by(KanaCharacter.kana_type))
    totals = {row[0]: row[1] for row in total_result.all()}

    # Batch: learned per kana_type (1 query instead of 2)
    learned_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter, KanaCharacter.id == UserKanaProgress.kana_id)
        .where(UserKanaProgress.user_id == user.id)
        .group_by(KanaCharacter.kana_type)
    )
    learned_map = {row[0]: row[1] for row in learned_result.all()}

    # Batch: mastered per kana_type (1 query instead of 2)
    mastered_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter, KanaCharacter.id == UserKanaProgress.kana_id)
        .where(UserKanaProgress.user_id == user.id, UserKanaProgress.mastered.is_(True))
        .group_by(KanaCharacter.kana_type)
    )
    mastered_map = {row[0]: row[1] for row in mastered_result.all()}

    def _stat(kt: KanaType) -> KanaStat:
        return KanaStat(
            learned=learned_map.get(kt, 0),
            mastered=mastered_map.get(kt, 0),
            total=totals.get(kt, 0),
        )

    return KanaProgressResponse(
        hiragana=_stat(KanaType.HIRAGANA),
        katakana=_stat(KanaType.KATAKANA),
    )


@router.post("/progress", status_code=200)
async def record_kana_learning(
    body: KanaProgressRecord,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = pg_insert(UserKanaProgress).values(
        user_id=user.id,
        kana_id=body.kana_id,
        correct_count=1,
        streak=1,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "kana_id"],
        set_={
            "correct_count": UserKanaProgress.correct_count + 1,
            "streak": UserKanaProgress.streak + 1,
            "last_reviewed_at": datetime.now(UTC),
        },
    )
    await db.execute(stmt)

    today = get_today_kst()
    dp_stmt = pg_insert(DailyProgress).values(
        user_id=user.id,
        date=today,
        kana_learned=1,
    )
    dp_stmt = dp_stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_={"kana_learned": DailyProgress.kana_learned + 1},
    )
    await db.execute(dp_stmt)
    await db.commit()

    return {"ok": True}


@router.post("/quiz/start", response_model=KanaQuizStartResponse, status_code=200)
async def start_kana_quiz(
    body: KanaQuizStartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Get characters from current stage + previous 2 stages
    stage_numbers = [body.stage_number - 2, body.stage_number - 1, body.stage_number]
    stage_numbers = [s for s in stage_numbers if s >= 1]

    stages_result = await db.execute(
        select(KanaLearningStage).where(
            KanaLearningStage.kana_type == body.kana_type,
            KanaLearningStage.stage_number.in_(stage_numbers),
        )
    )
    stages = stages_result.scalars().all()
    all_chars_list: list[str] = []
    for s in stages:
        all_chars_list.extend(s.characters)

    chars_result = await db.execute(
        select(KanaCharacter).where(
            KanaCharacter.kana_type == body.kana_type,
            KanaCharacter.character.in_(all_chars_list),
        )
    )
    characters = chars_result.scalars().all()

    if not characters:
        raise HTTPException(status_code=400, detail="가나 문자를 찾을 수 없습니다")

    # Generate questions
    questions: list[dict[str, Any]] = []
    quiz_chars = characters.copy()
    random.shuffle(quiz_chars)
    quiz_chars = quiz_chars[: body.count]

    for char in quiz_chars:
        wrong_pool = [c for c in characters if c.id != char.id]
        random.shuffle(wrong_pool)
        wrong_pool = wrong_pool[:3]

        correct_id = str(uuid.uuid4())

        if body.quiz_mode == "recognition":
            # Show kana -> pick romaji
            question_text = char.character
            options = [{"id": correct_id, "text": char.romaji}]
            for w in wrong_pool:
                options.append({"id": str(uuid.uuid4()), "text": w.romaji})
        elif body.quiz_mode == "sound_matching":
            # Show romaji -> pick kana
            question_text = char.romaji
            options = [{"id": correct_id, "text": char.character}]
            for w in wrong_pool:
                options.append({"id": str(uuid.uuid4()), "text": w.character})
        else:
            # kana_matching - default to recognition
            question_text = char.character
            options = [{"id": correct_id, "text": char.romaji}]
            for w in wrong_pool:
                options.append({"id": str(uuid.uuid4()), "text": w.romaji})

        random.shuffle(options)
        questions.append(
            {
                "id": str(char.id),
                "question": question_text,
                "options": options,
                "correctOptionId": correct_id,
            }
        )

    # Create quiz session
    session = QuizSession(
        user_id=user.id,
        quiz_type=QuizType.KANA,
        jlpt_level=user.jlpt_level,
        total_questions=len(questions),
        questions_data=questions,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)

    # Strip correctOptionId from response
    resp_questions = []
    for q in questions:
        resp_questions.append(
            {
                "id": q["id"],
                "question": q["question"],
                "options": q["options"],
            }
        )

    return KanaQuizStartResponse(
        session_id=session.id,
        questions=resp_questions,
        total_questions=len(questions),
    )


@router.post("/quiz/answer", response_model=KanaQuizAnswerResponse, status_code=200)
async def answer_kana_quiz(
    body: KanaQuizAnswerRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")

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

    # Update kana progress
    now = datetime.now(UTC)
    stmt = pg_insert(UserKanaProgress).values(
        user_id=user.id,
        kana_id=body.question_id,
        correct_count=1 if is_correct else 0,
        incorrect_count=0 if is_correct else 1,
        streak=1 if is_correct else 0,
        mastered=False,
        last_reviewed_at=now,
    )
    if is_correct:
        stmt = stmt.on_conflict_do_update(
            index_elements=["user_id", "kana_id"],
            set_={
                "correct_count": UserKanaProgress.correct_count + 1,
                "streak": UserKanaProgress.streak + 1,
                "mastered": UserKanaProgress.streak + 1 >= KANA_MASTERY_STREAK,
                "last_reviewed_at": now,
            },
        )
    else:
        stmt = stmt.on_conflict_do_update(
            index_elements=["user_id", "kana_id"],
            set_={
                "incorrect_count": UserKanaProgress.incorrect_count + 1,
                "streak": 0,
                "last_reviewed_at": now,
            },
        )
    await db.execute(stmt)

    if is_correct:
        session.correct_count += 1

    await db.commit()

    return KanaQuizAnswerResponse(is_correct=is_correct, correct_option_id=correct_option_id)


@router.post("/stage-complete", response_model=KanaStageCompleteResponse, status_code=200)
async def complete_stage(
    body: KanaStageCompleteRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Find stage
    stage_result = await db.execute(
        select(KanaLearningStage).where(
            KanaLearningStage.kana_type == body.kana_type,
            KanaLearningStage.stage_number == body.stage_number,
        )
    )
    stage = stage_result.scalar_one_or_none()
    if not stage:
        raise HTTPException(status_code=404, detail="스테이지를 찾을 수 없습니다")

    # Mark stage complete
    now = datetime.now(UTC)
    stmt = pg_insert(UserKanaStage).values(
        user_id=user.id,
        stage_id=stage.id,
        is_unlocked=True,
        is_completed=True,
        quiz_score=body.score,
        completed_at=now,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "stage_id"],
        set_={"is_completed": True, "quiz_score": body.score, "completed_at": now},
    )
    await db.execute(stmt)

    # Unlock next stage
    next_stage_result = await db.execute(
        select(KanaLearningStage).where(
            KanaLearningStage.kana_type == body.kana_type,
            KanaLearningStage.stage_number == body.stage_number + 1,
        )
    )
    next_stage = next_stage_result.scalar_one_or_none()
    next_stage_unlocked = False

    if next_stage:
        unlock_stmt = pg_insert(UserKanaStage).values(
            user_id=user.id,
            stage_id=next_stage.id,
            is_unlocked=True,
        )
        unlock_stmt = unlock_stmt.on_conflict_do_update(
            index_elements=["user_id", "stage_id"],
            set_={"is_unlocked": True},
        )
        await db.execute(unlock_stmt)
        next_stage_unlocked = True

    # Award XP
    xp_earned = KANA_REWARDS.STAGE_COMPLETE_XP
    old_level = user.level
    user.experience_points += xp_earned
    level_info = calculate_level(user.experience_points)
    user.level = level_info["level"]

    today = get_today_kst()
    streak_info = update_streak(user.last_study_date, user.streak_count, user.longest_streak, today)
    user.streak_count = streak_info["streak_count"]
    user.longest_streak = streak_info["longest_streak"]
    user.last_study_date = now

    # Update daily progress
    dp_stmt = pg_insert(DailyProgress).values(
        user_id=user.id,
        date=today,
        xp_earned=xp_earned,
    )
    dp_stmt = dp_stmt.on_conflict_do_update(
        index_elements=["user_id", "date"],
        set_={"xp_earned": DailyProgress.xp_earned + xp_earned},
    )
    await db.execute(dp_stmt)

    # Check kana achievements — batch queries
    kana_total_result = await db.execute(select(KanaCharacter.kana_type, func.count(KanaCharacter.id)).group_by(KanaCharacter.kana_type))
    kana_totals = {row[0]: row[1] for row in kana_total_result.all()}
    hiragana_total = kana_totals.get(KanaType.HIRAGANA, 0)
    katakana_total = kana_totals.get(KanaType.KATAKANA, 0)

    kana_mastered_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter, KanaCharacter.id == UserKanaProgress.kana_id)
        .where(UserKanaProgress.user_id == user.id, UserKanaProgress.mastered.is_(True))
        .group_by(KanaCharacter.kana_type)
    )
    kana_mastered_counts = {row[0]: row[1] for row in kana_mastered_result.all()}
    hiragana_mastered = kana_mastered_counts.get(KanaType.HIRAGANA, 0)
    katakana_mastered = kana_mastered_counts.get(KanaType.KATAKANA, 0)

    events = await check_and_grant_achievements(
        db,
        user.id,
        {
            "total_xp": user.experience_points,
            "new_level": user.level,
            "old_level": old_level,
            "streak_count": user.streak_count,
            "kana_first_char": True,
            "kana_hiragana_complete": hiragana_mastered >= hiragana_total and hiragana_total > 0,
            "kana_katakana_complete": katakana_mastered >= katakana_total and katakana_total > 0,
        },
    )

    # Auto-disable showKana when both complete
    if hiragana_mastered >= hiragana_total and katakana_mastered >= katakana_total and hiragana_total > 0 and katakana_total > 0:
        user.show_kana = False

    await db.commit()

    return KanaStageCompleteResponse(
        success=True,
        xp_earned=xp_earned,
        level=level_info["level"],
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
        events=events,
        next_stage_unlocked=next_stage_unlocked,
    )
