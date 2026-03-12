from __future__ import annotations

import math

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import UserVocabProgress, Vocabulary
from app.models.user import User

router = APIRouter(prefix="/api/v1/study", tags=["study"])


@router.get("/learned-words")
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
                "jlptLevel": vocab.jlpt_level.value if hasattr(vocab.jlpt_level, "value") else vocab.jlpt_level,
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


@router.get("/wrong-answers")
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
                "jlptLevel": vocab.jlpt_level.value if hasattr(vocab.jlpt_level, "value") else vocab.jlpt_level,
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
