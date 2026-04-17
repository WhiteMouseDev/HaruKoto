from __future__ import annotations

import math
from dataclasses import dataclass

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import UserVocabProgress, Vocabulary
from app.models.user import User
from app.utils.helpers import enum_value


@dataclass(slots=True)
class LearnedWordEntryData:
    id: str
    vocabulary_id: str
    word: str
    reading: str | None
    meaning_ko: str
    jlpt_level: str
    example_sentence: str | None
    example_translation: str | None
    correct_count: int
    incorrect_count: int
    streak: int
    mastered: bool
    last_reviewed_at: str | None


@dataclass(slots=True)
class LearnedWordsResult:
    entries: list[LearnedWordEntryData]
    total: int
    page: int
    total_pages: int
    total_learned: int
    mastered_count: int


@dataclass(slots=True)
class StudyWrongAnswerEntryData:
    id: str
    vocabulary_id: str
    word: str
    reading: str | None
    meaning_ko: str
    jlpt_level: str
    example_sentence: str | None
    example_translation: str | None
    correct_count: int
    incorrect_count: int
    mastered: bool
    last_reviewed_at: str | None


@dataclass(slots=True)
class StudyWrongAnswersResult:
    entries: list[StudyWrongAnswerEntryData]
    total: int
    page: int
    total_pages: int
    total_wrong: int
    mastered_wrong: int


async def get_learned_words_data(
    db: AsyncSession,
    user: User,
    *,
    page: int,
    limit: int,
    sort: str,
    search: str,
    filter_by: str,
) -> LearnedWordsResult:
    base_query = (
        select(UserVocabProgress, Vocabulary)
        .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(UserVocabProgress.user_id == user.id)
    )

    if filter_by == "MASTERED":
        base_query = base_query.where(UserVocabProgress.mastered.is_(True))
    elif filter_by == "LEARNING":
        base_query = base_query.where(UserVocabProgress.mastered.is_(False))

    if search:
        search_pattern = f"%{search}%"
        base_query = base_query.where(
            or_(
                Vocabulary.word.ilike(search_pattern),
                Vocabulary.meaning_ko.ilike(search_pattern),
            )
        )

    count_query = select(func.count()).select_from(base_query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    if sort == "alphabetical":
        base_query = base_query.order_by(Vocabulary.word.asc())
    elif sort == "most-studied":
        base_query = base_query.order_by(UserVocabProgress.correct_count.desc())
    else:
        base_query = base_query.order_by(UserVocabProgress.last_reviewed_at.desc().nullslast())

    result = await db.execute(base_query.offset((page - 1) * limit).limit(limit))
    rows = result.all()

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

    return LearnedWordsResult(
        entries=[
            LearnedWordEntryData(
                id=str(progress.id),
                vocabulary_id=str(vocab.id),
                word=vocab.word,
                reading=vocab.reading,
                meaning_ko=vocab.meaning_ko,
                jlpt_level=enum_value(vocab.jlpt_level),
                example_sentence=vocab.example_sentence,
                example_translation=vocab.example_translation,
                correct_count=progress.correct_count,
                incorrect_count=progress.incorrect_count,
                streak=progress.streak,
                mastered=progress.mastered,
                last_reviewed_at=progress.last_reviewed_at.isoformat() if progress.last_reviewed_at else None,
            )
            for progress, vocab in rows
        ],
        total=total,
        page=page,
        total_pages=math.ceil(total / limit) if limit > 0 else 0,
        total_learned=total_learned,
        mastered_count=mastered_count,
    )


async def get_study_wrong_answers_data(
    db: AsyncSession,
    user: User,
    *,
    page: int,
    limit: int,
    sort: str,
    level: str | None,
) -> StudyWrongAnswersResult:
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

    count_query = select(func.count()).select_from(base_query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    if sort == "recent":
        base_query = base_query.order_by(UserVocabProgress.last_reviewed_at.desc().nullslast())
    elif sort == "alphabetical":
        base_query = base_query.order_by(Vocabulary.word.asc())
    else:
        base_query = base_query.order_by(UserVocabProgress.incorrect_count.desc())

    result = await db.execute(base_query.offset((page - 1) * limit).limit(limit))
    rows = result.all()

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

    return StudyWrongAnswersResult(
        entries=[
            StudyWrongAnswerEntryData(
                id=str(progress.id),
                vocabulary_id=str(vocab.id),
                word=vocab.word,
                reading=vocab.reading,
                meaning_ko=vocab.meaning_ko,
                jlpt_level=enum_value(vocab.jlpt_level),
                example_sentence=vocab.example_sentence,
                example_translation=vocab.example_translation,
                correct_count=progress.correct_count,
                incorrect_count=progress.incorrect_count,
                mastered=progress.mastered,
                last_reviewed_at=progress.last_reviewed_at.isoformat() if progress.last_reviewed_at else None,
            )
            for progress, vocab in rows
        ],
        total=total,
        page=page,
        total_pages=math.ceil(total / limit) if limit > 0 else 0,
        total_wrong=total_wrong,
        mastered_wrong=mastered_wrong,
    )
