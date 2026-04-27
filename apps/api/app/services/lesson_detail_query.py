from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.content import Grammar, Vocabulary
from app.models.lesson import Lesson, UserLessonProgress
from app.models.user import User
from app.schemas.lesson import LessonContent
from app.utils.helpers import enum_value


@dataclass(slots=True)
class LessonProgressData:
    status: str
    attempts: int
    score_correct: int
    score_total: int
    started_at: datetime | None
    completed_at: datetime | None
    srs_registered_at: datetime | None


@dataclass(slots=True)
class VocabItemData:
    id: UUID
    word: str
    reading: str
    meaning_ko: str
    part_of_speech: str


@dataclass(slots=True)
class GrammarItemData:
    id: UUID
    pattern: str
    meaning_ko: str
    explanation: str


@dataclass(slots=True)
class LessonDetailData:
    id: UUID
    lesson_no: int
    chapter_lesson_no: int
    title: str
    topic: str
    estimated_minutes: int
    content: LessonContent
    vocab_items: list[VocabItemData]
    grammar_items: list[GrammarItemData]
    progress: LessonProgressData | None


def _serialize_progress(progress: UserLessonProgress | None) -> LessonProgressData | None:
    if progress is None:
        return None

    return LessonProgressData(
        status=progress.status,
        attempts=progress.attempts,
        score_correct=progress.score_correct,
        score_total=progress.score_total,
        started_at=progress.started_at,
        completed_at=progress.completed_at,
        srs_registered_at=getattr(progress, "srs_registered_at", None),
    )


async def get_lesson_detail_data(
    db: AsyncSession,
    user: User,
    *,
    lesson_id: UUID,
) -> LessonDetailData | None:
    result = await db.execute(
        select(Lesson).where(Lesson.id == lesson_id, Lesson.is_published.is_(True)).options(selectinload(Lesson.item_links))
    )
    lesson = result.scalar_one_or_none()
    if lesson is None:
        return None

    content = LessonContent.model_validate(lesson.content_jsonb or {})
    for question in content.questions:
        question.correct_answer = None
        question.correct_order = None

    vocab_ids = [link.vocabulary_id for link in lesson.item_links if link.item_type == "WORD" and link.vocabulary_id]
    grammar_ids = [link.grammar_id for link in lesson.item_links if link.item_type == "GRAMMAR" and link.grammar_id]

    vocab_map: dict[UUID, Vocabulary] = {}
    if vocab_ids:
        vocab_result = await db.execute(select(Vocabulary).where(Vocabulary.id.in_(vocab_ids)))
        vocab_map = {vocab.id: vocab for vocab in vocab_result.scalars().all()}

    grammar_map: dict[UUID, Grammar] = {}
    if grammar_ids:
        grammar_result = await db.execute(select(Grammar).where(Grammar.id.in_(grammar_ids)))
        grammar_map = {grammar.id: grammar for grammar in grammar_result.scalars().all()}

    vocab_items: list[VocabItemData] = []
    grammar_items: list[GrammarItemData] = []
    seen_vocab_ids: set[UUID] = set()
    seen_grammar_ids: set[UUID] = set()
    for link in sorted(lesson.item_links, key=lambda item: item.item_order):
        if link.item_type == "WORD" and link.vocabulary_id:
            if link.vocabulary_id in seen_vocab_ids:
                continue
            seen_vocab_ids.add(link.vocabulary_id)
            vocab = vocab_map.get(link.vocabulary_id)
            if vocab:
                vocab_items.append(
                    VocabItemData(
                        id=vocab.id,
                        word=vocab.word,
                        reading=vocab.reading,
                        meaning_ko=vocab.meaning_ko,
                        part_of_speech=enum_value(vocab.part_of_speech),
                    )
                )
        elif link.item_type == "GRAMMAR" and link.grammar_id:
            if link.grammar_id in seen_grammar_ids:
                continue
            seen_grammar_ids.add(link.grammar_id)
            grammar = grammar_map.get(link.grammar_id)
            if grammar:
                grammar_items.append(
                    GrammarItemData(
                        id=grammar.id,
                        pattern=grammar.pattern,
                        meaning_ko=grammar.meaning_ko,
                        explanation=grammar.explanation,
                    )
                )

    progress_result = await db.execute(
        select(UserLessonProgress).where(
            UserLessonProgress.user_id == user.id,
            UserLessonProgress.lesson_id == lesson.id,
        )
    )
    progress = _serialize_progress(progress_result.scalar_one_or_none())

    return LessonDetailData(
        id=lesson.id,
        lesson_no=lesson.lesson_no,
        chapter_lesson_no=lesson.chapter_lesson_no,
        title=lesson.title,
        topic=lesson.topic,
        estimated_minutes=lesson.estimated_minutes,
        content=content,
        vocab_items=vocab_items,
        grammar_items=grammar_items,
        progress=progress,
    )
