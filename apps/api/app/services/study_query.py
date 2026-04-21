from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import effective_jlpt_level
from app.models import StudyStage, UserStudyStageProgress, UserVocabProgress, Vocabulary
from app.models.content import ClozeQuestion, Grammar, SentenceArrangeQuestion
from app.models.lesson import Chapter
from app.models.progress import UserGrammarProgress
from app.models.user import User
from app.utils.helpers import enum_value


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
    stage_map: dict[str, int] = {row[0]: row[1] for row in stage_result.all()}

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
