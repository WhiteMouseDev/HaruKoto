from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy import cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.content import Grammar, Vocabulary
from app.models.lesson import Chapter, Lesson, UserLessonProgress
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.models.user import User
from app.schemas.lesson import LessonContent
from app.utils.helpers import enum_value


@dataclass(slots=True)
class LessonSummaryData:
    id: UUID
    lesson_no: int
    chapter_lesson_no: int
    title: str
    topic: str
    estimated_minutes: int
    status: str
    score_correct: int
    score_total: int


@dataclass(slots=True)
class ChapterData:
    id: UUID
    jlpt_level: str
    part_no: int
    chapter_no: int
    title: str
    topic: str | None
    lessons: list[LessonSummaryData]
    completed_lessons: int
    total_lessons: int


@dataclass(slots=True)
class ReviewSummaryData:
    word_due: int
    grammar_due: int
    total_due: int
    word_new: int
    grammar_new: int


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


def _effective_level(jlpt_level: str) -> str:
    return "N5" if jlpt_level == "ABSOLUTE_ZERO" else jlpt_level


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


async def get_chapters_data(
    db: AsyncSession,
    user: User,
    *,
    jlpt_level: str,
) -> list[ChapterData]:
    effective_level = _effective_level(jlpt_level)

    result = await db.execute(
        select(Chapter)
        .where(
            cast(Chapter.jlpt_level, sa.Text()) == effective_level,
            Chapter.is_published.is_(True),
        )
        .options(selectinload(Chapter.lessons))
        .order_by(Chapter.part_no, Chapter.chapter_no)
    )
    chapters = result.scalars().unique().all()

    lesson_ids = [lesson.id for chapter in chapters for lesson in chapter.lessons]
    progress_map: dict[UUID, UserLessonProgress] = {}
    if lesson_ids:
        progress_result = await db.execute(
            select(UserLessonProgress).where(
                UserLessonProgress.user_id == user.id,
                UserLessonProgress.lesson_id.in_(lesson_ids),
            )
        )
        progress_map = {progress.lesson_id: progress for progress in progress_result.scalars().all()}

    chapter_entries: list[ChapterData] = []
    for chapter in chapters:
        published_lessons = sorted(
            [lesson for lesson in chapter.lessons if lesson.is_published],
            key=lambda lesson: lesson.chapter_lesson_no,
        )
        lesson_entries: list[LessonSummaryData] = []
        completed_lessons = 0

        for lesson in published_lessons:
            progress = progress_map.get(lesson.id)
            status = progress.status if progress else "NOT_STARTED"
            if status == "COMPLETED":
                completed_lessons += 1

            lesson_entries.append(
                LessonSummaryData(
                    id=lesson.id,
                    lesson_no=lesson.lesson_no,
                    chapter_lesson_no=lesson.chapter_lesson_no,
                    title=lesson.title,
                    topic=lesson.topic,
                    estimated_minutes=lesson.estimated_minutes,
                    status=status,
                    score_correct=progress.score_correct if progress else 0,
                    score_total=progress.score_total if progress else 0,
                )
            )

        chapter_entries.append(
            ChapterData(
                id=chapter.id,
                jlpt_level=enum_value(chapter.jlpt_level),
                part_no=chapter.part_no,
                chapter_no=chapter.chapter_no,
                title=chapter.title,
                topic=chapter.topic,
                lessons=lesson_entries,
                completed_lessons=completed_lessons,
                total_lessons=len(published_lessons),
            )
        )

    return chapter_entries


async def get_review_summary_data(
    db: AsyncSession,
    user: User,
    *,
    jlpt_level: str,
) -> ReviewSummaryData:
    effective_level = _effective_level(jlpt_level)
    now = datetime.now(UTC)
    due_states = ("RELEARNING", "LEARNING", "REVIEW", "PROVISIONAL")

    word_due = (
        await db.execute(
            select(func.count())
            .select_from(UserVocabProgress)
            .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
            .where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.state.in_(due_states),
                UserVocabProgress.next_review_at <= now,
                Vocabulary.jlpt_level == effective_level,
            )
        )
    ).scalar() or 0

    grammar_due = (
        await db.execute(
            select(func.count())
            .select_from(UserGrammarProgress)
            .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
            .where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.state.in_(due_states),
                UserGrammarProgress.next_review_at <= now,
                Grammar.jlpt_level == effective_level,
            )
        )
    ).scalar() or 0

    word_unseen = (
        await db.execute(
            select(func.count())
            .select_from(UserVocabProgress)
            .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
            .where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.state == "UNSEEN",
                Vocabulary.jlpt_level == effective_level,
            )
        )
    ).scalar() or 0

    existing_vocab_ids = select(UserVocabProgress.vocabulary_id).where(UserVocabProgress.user_id == user.id).scalar_subquery()
    word_no_record = (
        await db.execute(
            select(func.count())
            .select_from(Vocabulary)
            .where(
                Vocabulary.jlpt_level == effective_level,
                Vocabulary.id.notin_(existing_vocab_ids),
            )
        )
    ).scalar() or 0

    grammar_unseen = (
        await db.execute(
            select(func.count())
            .select_from(UserGrammarProgress)
            .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
            .where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.state == "UNSEEN",
                Grammar.jlpt_level == effective_level,
            )
        )
    ).scalar() or 0

    existing_grammar_ids = select(UserGrammarProgress.grammar_id).where(UserGrammarProgress.user_id == user.id).scalar_subquery()
    grammar_no_record = (
        await db.execute(
            select(func.count())
            .select_from(Grammar)
            .where(
                Grammar.jlpt_level == effective_level,
                Grammar.id.notin_(existing_grammar_ids),
            )
        )
    ).scalar() or 0

    return ReviewSummaryData(
        word_due=word_due,
        grammar_due=grammar_due,
        total_due=word_due + grammar_due,
        word_new=word_unseen + word_no_record,
        grammar_new=grammar_unseen + grammar_no_record,
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
    for link in sorted(lesson.item_links, key=lambda item: item.item_order):
        if link.item_type == "WORD" and link.vocabulary_id:
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
