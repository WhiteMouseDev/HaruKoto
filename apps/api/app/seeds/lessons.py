"""Seed Ch.01 pilot lessons from 08-CH01-PILOT-CONTENT.json.

Usage:
    cd apps/api
    python -m app.seeds.lessons
"""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings
from app.models.content import Grammar, Vocabulary
from app.models.lesson import Chapter, Lesson, LessonItemLink

# Path to pilot content JSON (relative to project root)
CONTENT_PATH = Path(__file__).resolve().parents[4] / "docs" / "learning-quiz-strategy" / "08-CH01-PILOT-CONTENT.json"


async def _upsert_chapter(db: AsyncSession, meta: dict) -> Chapter:
    """Create or update chapter record."""
    stmt = pg_insert(Chapter).values(
        jlpt_level=meta["jlpt_level"],
        part_no=meta["part_no"],
        chapter_no=meta["chapter_no"],
        title=meta["chapter_title"],
        topic=meta.get("topic"),
        order_no=meta["chapter_no"],
        is_published=True,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["jlpt_level", "part_no", "chapter_no"],
        set_={
            "title": meta["chapter_title"],
            "is_published": True,
        },
    )
    await db.execute(stmt)

    result = await db.execute(
        select(Chapter).where(
            Chapter.jlpt_level == meta["jlpt_level"],
            Chapter.part_no == meta["part_no"],
            Chapter.chapter_no == meta["chapter_no"],
        )
    )
    return result.scalar_one()


async def _upsert_lesson(db: AsyncSession, chapter: Chapter, lesson_data: dict) -> Lesson:
    """Create or update lesson record."""
    stmt = pg_insert(Lesson).values(
        chapter_id=chapter.id,
        jlpt_level=str(chapter.jlpt_level),
        lesson_no=lesson_data["lesson_no"],
        chapter_lesson_no=lesson_data["chapter_lesson_no"],
        title=lesson_data["title"],
        topic=lesson_data["topic"],
        estimated_minutes=lesson_data["estimated_minutes"],
        content_jsonb=lesson_data["content_jsonb"],
        is_published=True,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["jlpt_level", "lesson_no"],
        set_={
            "title": lesson_data["title"],
            "topic": lesson_data["topic"],
            "content_jsonb": lesson_data["content_jsonb"],
            "is_published": True,
        },
    )
    await db.execute(stmt)

    result = await db.execute(
        select(Lesson).where(
            Lesson.jlpt_level == str(chapter.jlpt_level),
            Lesson.lesson_no == lesson_data["lesson_no"],
        )
    )
    return result.scalar_one()


async def _link_items(
    db: AsyncSession,
    lesson: Lesson,
    vocab_orders: list[int],
    grammar_order: int | None,
) -> int:
    """Link vocabulary and grammar items to a lesson. Returns count of links created."""
    count = 0

    # Link vocabulary items
    for idx, order in enumerate(vocab_orders):
        result = await db.execute(
            select(Vocabulary).where(
                Vocabulary.jlpt_level == str(lesson.jlpt_level),
                Vocabulary.order == order,
            )
        )
        vocab = result.scalar_one_or_none()
        if vocab is None:
            print(f"  ⚠️  Vocabulary order={order} not found, skipping")
            continue

        stmt = pg_insert(LessonItemLink).values(
            lesson_id=lesson.id,
            item_type="WORD",
            vocabulary_id=vocab.id,
            grammar_id=None,
            item_order=idx + 1,
            is_core=True,
        )
        stmt = stmt.on_conflict_do_nothing()
        await db.execute(stmt)
        count += 1

    # Link grammar item
    if grammar_order is not None:
        result = await db.execute(
            select(Grammar).where(
                Grammar.jlpt_level == str(lesson.jlpt_level),
                Grammar.order == grammar_order,
            )
        )
        grammar = result.scalar_one_or_none()
        if grammar is None:
            print(f"  ⚠️  Grammar order={grammar_order} not found, skipping")
        else:
            stmt = pg_insert(LessonItemLink).values(
                lesson_id=lesson.id,
                item_type="GRAMMAR",
                vocabulary_id=None,
                grammar_id=grammar.id,
                item_order=len(vocab_orders) + 1,
                is_core=True,
            )
            stmt = stmt.on_conflict_do_nothing()
            await db.execute(stmt)
            count += 1

    return count


async def seed_lessons(db: AsyncSession) -> dict[str, int]:
    """Seed Ch.01 pilot lessons. Returns counts summary."""
    if not CONTENT_PATH.exists():
        raise FileNotFoundError(f"Content file not found: {CONTENT_PATH}")

    data = json.loads(CONTENT_PATH.read_text(encoding="utf-8"))
    meta = data["meta"]
    lessons_data = data["lessons"]

    # 1. Create chapter
    chapter = await _upsert_chapter(db, meta)
    print(f"✅ Chapter: {chapter.title} (id={chapter.id})")

    # 2. Create lessons + link items
    lesson_count = 0
    link_count = 0

    for ld in lessons_data:
        lesson = await _upsert_lesson(db, chapter, ld)
        print(f"  ✅ Lesson {ld['lesson_id']}: {ld['title']}")

        links = await _link_items(
            db,
            lesson,
            vocab_orders=ld["vocab_orders"],
            grammar_order=ld["grammar"]["grammar_order"],
        )
        print(f"     → {links} items linked")

        lesson_count += 1
        link_count += links

    await db.commit()
    return {"chapters": 1, "lessons": lesson_count, "item_links": link_count}


async def main() -> None:
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    print("Seeding Ch.01 pilot lessons...")
    async with async_session() as db:
        counts = await seed_lessons(db)
        for key, val in counts.items():
            print(f"  {key}: {val}")

    await engine.dispose()
    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
