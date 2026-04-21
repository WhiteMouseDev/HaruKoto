from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import effective_jlpt_level
from app.models import StudyStage, UserVocabProgress, Vocabulary
from app.models.content import ClozeQuestion, Grammar, SentenceArrangeQuestion
from app.models.lesson import Chapter
from app.models.progress import UserGrammarProgress
from app.models.user import User
from app.utils.helpers import enum_value


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
