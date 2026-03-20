from __future__ import annotations

import math

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import StudyStage, UserStudyStageProgress, UserVocabProgress, Vocabulary
from app.models.user import User
from app.schemas.stats import DailyGoalRequest, DailyGoalResponse
from app.utils.helpers import enum_value

router = APIRouter(prefix="/api/v1/study", tags=["study"])


@router.get("/learned-words", status_code=200)
async def get_learned_words(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, le=50),
    sort: str = Query(default="recent"),
    search: str = Query(default=""),
    filter_by: str = Query(default="ALL", alias="filter"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    base_query = (
        select(UserVocabProgress, Vocabulary)
        .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(UserVocabProgress.user_id == user.id)
    )

    # Filter
    if filter_by == "MASTERED":
        base_query = base_query.where(UserVocabProgress.mastered.is_(True))
    elif filter_by == "LEARNING":
        base_query = base_query.where(UserVocabProgress.mastered.is_(False))

    # Search
    if search:
        search_pattern = f"%{search}%"
        base_query = base_query.where(
            or_(
                Vocabulary.word.ilike(search_pattern),
                Vocabulary.meaning_ko.ilike(search_pattern),
            )
        )

    # Count total
    count_query = select(func.count()).select_from(base_query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    # Sort
    if sort == "alphabetical":
        base_query = base_query.order_by(Vocabulary.word.asc())
    elif sort == "most-studied":
        base_query = base_query.order_by(UserVocabProgress.correct_count.desc())
    else:  # recent
        base_query = base_query.order_by(UserVocabProgress.last_reviewed_at.desc().nullslast())

    # Paginate
    base_query = base_query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(base_query)
    rows = result.all()

    # Summary counts
    summary_base = select(UserVocabProgress).where(UserVocabProgress.user_id == user.id)
    total_learned_result = await db.execute(select(func.count()).select_from(summary_base.subquery()))
    total_learned = total_learned_result.scalar() or 0

    mastered_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.mastered.is_(True),
        )
    )
    mastered_count = mastered_result.scalar() or 0

    total_pages = math.ceil(total / limit) if limit > 0 else 0

    entries = []
    for progress, vocab in rows:
        entries.append(
            {
                "id": str(progress.id),
                "vocabularyId": str(vocab.id),
                "word": vocab.word,
                "reading": vocab.reading,
                "meaningKo": vocab.meaning_ko,
                "jlptLevel": enum_value(vocab.jlpt_level),
                "exampleSentence": vocab.example_sentence,
                "exampleTranslation": vocab.example_translation,
                "correctCount": progress.correct_count,
                "incorrectCount": progress.incorrect_count,
                "streak": progress.streak,
                "mastered": progress.mastered,
                "lastReviewedAt": progress.last_reviewed_at.isoformat() if progress.last_reviewed_at else None,
            }
        )

    return {
        "entries": entries,
        "total": total,
        "page": page,
        "totalPages": total_pages,
        "summary": {
            "totalLearned": total_learned,
            "mastered": mastered_count,
            "learning": total_learned - mastered_count,
        },
    }


@router.get("/wrong-answers", status_code=200)
async def get_study_wrong_answers(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, le=50),
    sort: str = Query(default="most-wrong"),
    level: str | None = Query(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    base_query = (
        select(UserVocabProgress, Vocabulary)
        .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.incorrect_count > 0,
        )
    )

    if level:
        base_query = base_query.where(Vocabulary.jlpt_level == level)

    # Count total
    count_query = select(func.count()).select_from(base_query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    # Sort
    if sort == "recent":
        base_query = base_query.order_by(UserVocabProgress.last_reviewed_at.desc().nullslast())
    elif sort == "alphabetical":
        base_query = base_query.order_by(Vocabulary.word.asc())
    else:  # most-wrong
        base_query = base_query.order_by(UserVocabProgress.incorrect_count.desc())

    # Paginate
    base_query = base_query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(base_query)
    rows = result.all()

    # Summary
    summary_base = select(UserVocabProgress).where(
        UserVocabProgress.user_id == user.id,
        UserVocabProgress.incorrect_count > 0,
    )
    total_wrong_result = await db.execute(select(func.count()).select_from(summary_base.subquery()))
    total_wrong = total_wrong_result.scalar() or 0

    mastered_wrong_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.incorrect_count > 0,
            UserVocabProgress.mastered.is_(True),
        )
    )
    mastered_wrong = mastered_wrong_result.scalar() or 0

    total_pages = math.ceil(total / limit) if limit > 0 else 0

    entries = []
    for progress, vocab in rows:
        entries.append(
            {
                "id": str(progress.id),
                "vocabularyId": str(vocab.id),
                "word": vocab.word,
                "reading": vocab.reading,
                "meaningKo": vocab.meaning_ko,
                "jlptLevel": enum_value(vocab.jlpt_level),
                "exampleSentence": vocab.example_sentence,
                "exampleTranslation": vocab.example_translation,
                "correctCount": progress.correct_count,
                "incorrectCount": progress.incorrect_count,
                "mastered": progress.mastered,
                "lastReviewedAt": progress.last_reviewed_at.isoformat() if progress.last_reviewed_at else None,
            }
        )

    return {
        "entries": entries,
        "total": total,
        "page": page,
        "totalPages": total_pages,
        "summary": {
            "totalWrong": total_wrong,
            "mastered": mastered_wrong,
            "remaining": total_wrong - mastered_wrong,
        },
    }


@router.get("/stages", status_code=200)
async def get_stages(
    category: str = Query(..., description="VOCABULARY, GRAMMAR, or SENTENCE"),
    jlpt_level: str | None = Query(default=None, alias="jlptLevel"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """카테고리별 스테이지 목록과 유저 진행 상황 조회."""
    from app.enums import effective_jlpt_level

    raw_level = jlpt_level or enum_value(user.jlpt_level)
    level = enum_value(effective_jlpt_level(user.jlpt_level)) if not jlpt_level else raw_level

    # Fetch stages
    stages_result = await db.execute(
        select(StudyStage)
        .where(
            StudyStage.category == category.upper(),
            StudyStage.jlpt_level == level,
        )
        .order_by(StudyStage.order, StudyStage.stage_number)
    )
    stages = stages_result.scalars().all()

    if not stages:
        return []

    # Fetch user progress for all stages in one query
    stage_ids = [s.id for s in stages]
    progress_result = await db.execute(
        select(UserStudyStageProgress).where(
            UserStudyStageProgress.user_id == user.id,
            UserStudyStageProgress.stage_id.in_(stage_ids),
        )
    )
    progress_map = {str(p.stage_id): p for p in progress_result.scalars().all()}

    # Build completed stage IDs set for unlock logic
    completed_stage_ids = {str(p.stage_id) for p in progress_map.values() if p.completed}

    response = []
    for stage in stages:
        progress = progress_map.get(str(stage.id))
        content_ids = stage.content_ids if isinstance(stage.content_ids, list) else []

        # First stage is always unlocked; others require unlock_after completed
        is_locked = False if stage.unlock_after is None else str(stage.unlock_after) not in completed_stage_ids

        response.append(
            {
                "id": str(stage.id),
                "category": stage.category,
                "jlptLevel": enum_value(stage.jlpt_level),
                "stageNumber": stage.stage_number,
                "title": stage.title,
                "description": stage.description,
                "contentCount": len(content_ids),
                "isLocked": is_locked,
                "userProgress": {
                    "bestScore": progress.best_score if progress else 0,
                    "attempts": progress.attempts if progress else 0,
                    "completed": progress.completed if progress else False,
                    "completedAt": progress.completed_at.isoformat() if progress and progress.completed_at else None,
                    "lastAttemptedAt": progress.last_attempted_at.isoformat() if progress and progress.last_attempted_at else None,
                }
                if progress
                else None,
            }
        )

    return response


@router.patch("/daily-goal", response_model=DailyGoalResponse, status_code=200)
async def update_daily_goal(
    body: DailyGoalRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """3-12: Update user's daily goal."""
    if body.daily_goal < 5 or body.daily_goal > 50:
        raise HTTPException(
            status_code=422,
            detail="dailyGoal must be between 5 and 50",
        )

    user.daily_goal = body.daily_goal
    await db.commit()
    await db.refresh(user)

    return DailyGoalResponse(daily_goal=user.daily_goal)
