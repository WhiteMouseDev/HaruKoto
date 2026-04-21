from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy import cast, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.lesson import Chapter, UserLessonProgress
from app.models.user import User
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


def _effective_level(jlpt_level: str) -> str:
    return "N5" if jlpt_level == "ABSOLUTE_ZERO" else jlpt_level


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
