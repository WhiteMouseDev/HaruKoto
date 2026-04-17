from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.enums import effective_jlpt_level
from app.models import StudyStage, UserStudyStageProgress, UserVocabProgress, Vocabulary
from app.models.content import ClozeQuestion, Grammar, SentenceArrangeQuestion
from app.models.lesson import Chapter
from app.models.user import User
from app.schemas.stats import DailyGoalRequest, DailyGoalResponse
from app.schemas.study import (
    LearnedWordEntry,
    LearnedWordsResponse,
    LearnedWordsSummary,
    StudyWrongAnswerEntry,
    StudyWrongAnswersResponse,
    StudyWrongAnswersSummary,
)
from app.services.study_query import (
    get_learned_words_data,
    get_study_wrong_answers_data,
)
from app.utils.helpers import enum_value

router = APIRouter(prefix="/api/v1/study", tags=["study"])


@router.get("/learned-words", response_model=LearnedWordsResponse, status_code=200)
async def get_learned_words(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, le=50),
    sort: str = Query(default="recent"),
    search: str = Query(default=""),
    filter_by: str = Query(default="ALL", alias="filter"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await get_learned_words_data(
        db,
        user,
        page=page,
        limit=limit,
        sort=sort,
        search=search,
        filter_by=filter_by,
    )

    return LearnedWordsResponse(
        entries=[
            LearnedWordEntry(
                id=item.id,
                vocabulary_id=item.vocabulary_id,
                word=item.word,
                reading=item.reading,
                meaning_ko=item.meaning_ko,
                jlpt_level=item.jlpt_level,
                example_sentence=item.example_sentence,
                example_translation=item.example_translation,
                correct_count=item.correct_count,
                incorrect_count=item.incorrect_count,
                streak=item.streak,
                mastered=item.mastered,
                last_reviewed_at=item.last_reviewed_at,
            )
            for item in result.entries
        ],
        total=result.total,
        page=result.page,
        total_pages=result.total_pages,
        summary=LearnedWordsSummary(
            total_learned=result.total_learned,
            mastered=result.mastered_count,
            learning=result.total_learned - result.mastered_count,
        ),
    )


@router.get("/wrong-answers", response_model=StudyWrongAnswersResponse, status_code=200)
async def get_study_wrong_answers(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, le=50),
    sort: str = Query(default="most-wrong"),
    level: str | None = Query(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await get_study_wrong_answers_data(
        db,
        user,
        page=page,
        limit=limit,
        sort=sort,
        level=level,
    )

    return StudyWrongAnswersResponse(
        entries=[
            StudyWrongAnswerEntry(
                id=item.id,
                vocabulary_id=item.vocabulary_id,
                word=item.word,
                reading=item.reading,
                meaning_ko=item.meaning_ko,
                jlpt_level=item.jlpt_level,
                example_sentence=item.example_sentence,
                example_translation=item.example_translation,
                correct_count=item.correct_count,
                incorrect_count=item.incorrect_count,
                mastered=item.mastered,
                last_reviewed_at=item.last_reviewed_at,
            )
            for item in result.entries
        ],
        total=result.total,
        page=result.page,
        total_pages=result.total_pages,
        summary=StudyWrongAnswersSummary(
            total_wrong=result.total_wrong,
            mastered=result.mastered_wrong,
            remaining=result.total_wrong - result.mastered_wrong,
        ),
    )


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


@router.get("/capabilities", status_code=200)
async def get_capabilities(
    jlpt_level: str | None = Query(default=None, alias="jlptLevel"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """레벨별 기능 가용성 매트릭스. 모든 진입/가드 화면의 단일 소스."""
    requested = jlpt_level or enum_value(user.jlpt_level)
    effective = enum_value(effective_jlpt_level(user.jlpt_level)) if not jlpt_level else requested
    if effective == "ABSOLUTE_ZERO":
        effective = "N5"

    # --- Quiz: 카테고리별 콘텐츠 존재 여부 ---
    vocab_count = (await db.execute(select(func.count()).select_from(Vocabulary).where(Vocabulary.jlpt_level == effective))).scalar_one()
    grammar_count = (await db.execute(select(func.count()).select_from(Grammar).where(Grammar.jlpt_level == effective))).scalar_one()
    cloze_count = (
        await db.execute(select(func.count()).select_from(ClozeQuestion).where(ClozeQuestion.jlpt_level == effective))
    ).scalar_one()
    arrange_count = (
        await db.execute(select(func.count()).select_from(SentenceArrangeQuestion).where(SentenceArrangeQuestion.jlpt_level == effective))
    ).scalar_one()

    quiz_caps = {
        "VOCABULARY": vocab_count > 0,
        "GRAMMAR": grammar_count > 0,
        "KANJI": False,
        "LISTENING": False,
        "KANA": True,
        "CLOZE": cloze_count > 0,
        "SENTENCE_ARRANGE": arrange_count > 0,
    }

    # --- Smart: SRS pool 존재 여부 (유저별 + 레벨 필터) ---
    from app.models.progress import UserGrammarProgress

    vocab_pool = (
        await db.execute(
            select(func.count())
            .select_from(UserVocabProgress)
            .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
            .where(UserVocabProgress.user_id == user.id, Vocabulary.jlpt_level == effective)
        )
    ).scalar_one()

    grammar_pool = (
        await db.execute(
            select(func.count())
            .select_from(UserGrammarProgress)
            .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
            .where(UserGrammarProgress.user_id == user.id, Grammar.jlpt_level == effective)
        )
    ).scalar_one()

    smart_caps = {
        "VOCABULARY": {"available": vocab_count > 0, "hasPool": vocab_pool > 0},
        "GRAMMAR": {"available": grammar_count > 0, "hasPool": grammar_pool > 0},
    }

    # --- Lesson: 해당 레벨 published 레슨 존재 여부 ---
    lesson_count = (
        await db.execute(select(func.count()).select_from(Chapter).where(Chapter.jlpt_level == effective, Chapter.is_published.is_(True)))
    ).scalar_one()

    # --- Stage: 카테고리별 스테이지 존재 여부 ---
    stage_result = await db.execute(
        select(StudyStage.category, func.count()).where(StudyStage.jlpt_level == effective).group_by(StudyStage.category)
    )
    stage_map = dict(stage_result.all())

    stage_caps = {
        "VOCABULARY": stage_map.get("VOCABULARY", 0) > 0,
        "GRAMMAR": stage_map.get("GRAMMAR", 0) > 0,
        "SENTENCE": stage_map.get("SENTENCE", 0) > 0,
    }

    return {
        "requestedJlptLevel": requested,
        "effectiveJlptLevel": effective,
        "quiz": quiz_caps,
        "smart": smart_caps,
        "lesson": lesson_count > 0,
        "stage": stage_caps,
    }
