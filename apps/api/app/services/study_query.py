from __future__ import annotations

import math
from dataclasses import dataclass

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import effective_jlpt_level
from app.models import StudyStage, UserStudyStageProgress, UserVocabProgress, Vocabulary
from app.models.content import ClozeQuestion, Grammar, SentenceArrangeQuestion
from app.models.lesson import Chapter
from app.models.progress import UserGrammarProgress
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


@dataclass(slots=True)
class StudyStageProgressData:
    best_score: int
    attempts: int
    completed: bool
    completed_at: str | None
    last_attempted_at: str | None


@dataclass(slots=True)
class StudyStageEntryData:
    id: str
    category: str
    jlpt_level: str
    stage_number: int
    title: str
    description: str | None
    content_count: int
    is_locked: bool
    user_progress: StudyStageProgressData | None


@dataclass(slots=True)
class QuizCapabilitiesData:
    vocabulary: bool
    grammar: bool
    kanji: bool
    listening: bool
    kana: bool
    cloze: bool
    sentence_arrange: bool


@dataclass(slots=True)
class SmartCategoryCapabilityData:
    available: bool
    has_pool: bool


@dataclass(slots=True)
class SmartCapabilitiesData:
    vocabulary: SmartCategoryCapabilityData
    grammar: SmartCategoryCapabilityData


@dataclass(slots=True)
class StageCapabilitiesData:
    vocabulary: bool
    grammar: bool
    sentence: bool


@dataclass(slots=True)
class StudyCapabilitiesResult:
    requested_jlpt_level: str
    effective_jlpt_level: str
    quiz: QuizCapabilitiesData
    smart: SmartCapabilitiesData
    lesson: bool
    stage: StageCapabilitiesData


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


async def get_stages_data(
    db: AsyncSession,
    user: User,
    *,
    category: str,
    jlpt_level: str | None,
) -> list[StudyStageEntryData]:
    raw_level = jlpt_level or enum_value(user.jlpt_level)
    level = enum_value(effective_jlpt_level(user.jlpt_level)) if not jlpt_level else raw_level

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

    stage_ids = [stage.id for stage in stages]
    progress_result = await db.execute(
        select(UserStudyStageProgress).where(
            UserStudyStageProgress.user_id == user.id,
            UserStudyStageProgress.stage_id.in_(stage_ids),
        )
    )
    progress_rows = progress_result.scalars().all()
    progress_map = {str(progress.stage_id): progress for progress in progress_rows}
    completed_stage_ids = {str(progress.stage_id) for progress in progress_rows if progress.completed}

    return [
        StudyStageEntryData(
            id=str(stage.id),
            category=stage.category,
            jlpt_level=enum_value(stage.jlpt_level),
            stage_number=stage.stage_number,
            title=stage.title,
            description=stage.description,
            content_count=len(stage.content_ids) if isinstance(stage.content_ids, list) else 0,
            is_locked=False if stage.unlock_after is None else str(stage.unlock_after) not in completed_stage_ids,
            user_progress=(
                StudyStageProgressData(
                    best_score=progress.best_score or 0,
                    attempts=progress.attempts or 0,
                    completed=bool(progress.completed),
                    completed_at=progress.completed_at.isoformat() if progress.completed_at else None,
                    last_attempted_at=progress.last_attempted_at.isoformat() if progress.last_attempted_at else None,
                )
                if (progress := progress_map.get(str(stage.id)))
                else None
            ),
        )
        for stage in stages
    ]


async def get_study_capabilities_data(
    db: AsyncSession,
    user: User,
    *,
    jlpt_level: str | None,
) -> StudyCapabilitiesResult:
    requested = jlpt_level or enum_value(user.jlpt_level)
    effective = enum_value(effective_jlpt_level(user.jlpt_level)) if not jlpt_level else requested
    if effective == "ABSOLUTE_ZERO":
        effective = "N5"

    vocab_count = (await db.execute(select(func.count()).select_from(Vocabulary).where(Vocabulary.jlpt_level == effective))).scalar_one()
    grammar_count = (await db.execute(select(func.count()).select_from(Grammar).where(Grammar.jlpt_level == effective))).scalar_one()
    cloze_count = (
        await db.execute(select(func.count()).select_from(ClozeQuestion).where(ClozeQuestion.jlpt_level == effective))
    ).scalar_one()
    arrange_count = (
        await db.execute(select(func.count()).select_from(SentenceArrangeQuestion).where(SentenceArrangeQuestion.jlpt_level == effective))
    ).scalar_one()

    vocab_pool = (
        await db.execute(
            select(func.count())
            .select_from(UserVocabProgress)
            .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
            .where(
                UserVocabProgress.user_id == user.id,
                Vocabulary.jlpt_level == effective,
            )
        )
    ).scalar_one()
    grammar_pool = (
        await db.execute(
            select(func.count())
            .select_from(UserGrammarProgress)
            .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
            .where(
                UserGrammarProgress.user_id == user.id,
                Grammar.jlpt_level == effective,
            )
        )
    ).scalar_one()

    lesson_count = (
        await db.execute(
            select(func.count())
            .select_from(Chapter)
            .where(
                Chapter.jlpt_level == effective,
                Chapter.is_published.is_(True),
            )
        )
    ).scalar_one()

    stage_result = await db.execute(
        select(StudyStage.category, func.count()).where(StudyStage.jlpt_level == effective).group_by(StudyStage.category)
    )
    stage_map = dict(stage_result.all())

    return StudyCapabilitiesResult(
        requested_jlpt_level=requested,
        effective_jlpt_level=effective,
        quiz=QuizCapabilitiesData(
            vocabulary=vocab_count > 0,
            grammar=grammar_count > 0,
            kanji=False,
            listening=False,
            kana=True,
            cloze=cloze_count > 0,
            sentence_arrange=arrange_count > 0,
        ),
        smart=SmartCapabilitiesData(
            vocabulary=SmartCategoryCapabilityData(
                available=vocab_count > 0,
                has_pool=vocab_pool > 0,
            ),
            grammar=SmartCategoryCapabilityData(
                available=grammar_count > 0,
                has_pool=grammar_pool > 0,
            ),
        ),
        lesson=lesson_count > 0,
        stage=StageCapabilitiesData(
            vocabulary=stage_map.get("VOCABULARY", 0) > 0,
            grammar=stage_map.get("GRAMMAR", 0) > 0,
            sentence=stage_map.get("SENTENCE", 0) > 0,
        ),
    )
