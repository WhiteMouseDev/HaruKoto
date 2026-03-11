from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import QuizAnswer, UserVocabProgress, Vocabulary
from app.models.user import User

router = APIRouter(prefix="/api/v1/study", tags=["study"])


@router.get("/learned-words")
async def get_learned_words(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, le=50),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Vocabulary)
        .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(UserVocabProgress.user_id == user.id)
        .order_by(UserVocabProgress.last_reviewed_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
    )
    result = await db.execute(query)
    words = result.scalars().all()

    count_result = await db.execute(select(func.count(UserVocabProgress.id)).where(UserVocabProgress.user_id == user.id))
    total = count_result.scalar() or 0

    return {
        "words": [
            {
                "id": str(v.id),
                "word": v.word,
                "reading": v.reading,
                "meaningKo": v.meaning_ko,
                "jlptLevel": v.jlpt_level.value,
                "partOfSpeech": v.part_of_speech.value,
            }
            for v in words
        ],
        "total": total,
        "page": page,
        "pageSize": limit,
    }


@router.get("/wrong-answers")
async def get_study_wrong_answers(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, le=50),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.models import QuizSession

    result = await db.execute(
        select(QuizAnswer)
        .join(QuizSession, QuizSession.id == QuizAnswer.session_id)
        .where(QuizSession.user_id == user.id, QuizAnswer.is_correct.is_(False))
        .order_by(QuizAnswer.answered_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
    )
    wrong = result.scalars().all()

    return {
        "wrongAnswers": [
            {
                "questionId": str(a.question_id),
                "questionType": a.question_type.value,
                "selectedOptionId": a.selected_option_id,
                "answeredAt": a.answered_at.isoformat(),
            }
            for a in wrong
        ]
    }
