"""Seed Ch.01 pilot lessons from 08-CH01-PILOT-CONTENT.json.

Usage:
    cd apps/api
    python -m app.seeds.lessons
"""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import Any

import sqlalchemy as sa
from sqlalchemy import cast, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings
from app.models.content import Grammar, Vocabulary
from app.models.lesson import Chapter, Lesson, LessonItemLink

# Content JSON directory (relative to project root)
CONTENT_DIR = Path(__file__).resolve().parents[4] / "packages" / "database" / "data" / "lessons" / "n5"

# All Part 1 content files (Ch.01~06)
CONTENT_FILES = [
    "ch01-greetings-and-first-meetings.json",
    "ch02-introducing-things-and-people.json",
    "ch03-location-and-movement.json",
    "ch04-verb-basics.json",
    "ch05-past-and-sequence.json",
    "ch06-progress-and-habits.json",
]

PUBLISHABLE_META_STATUSES = {"PILOT", "PUBLISHED"}
ALLOWED_META_STATUSES = {"DRAFT", *PUBLISHABLE_META_STATUSES}


def _jlpt_str(level: object) -> str:
    """Extract string value from JlptLevel enum or plain string."""
    return level.value if hasattr(level, "value") else str(level)


def _lesson_is_published(meta: dict[str, Any]) -> bool:
    """Map content review status to DB publish state."""
    status = str(meta.get("status", "")).upper()
    if status not in ALLOWED_META_STATUSES:
        raise ValueError(f"Unsupported lesson meta.status: {status}")
    return status in PUBLISHABLE_META_STATUSES


async def _upsert_chapter(db: AsyncSession, meta: dict[str, Any]) -> Chapter:
    """Create or update chapter record."""
    is_published = _lesson_is_published(meta)
    stmt = pg_insert(Chapter).values(
        jlpt_level=meta["jlpt_level"],
        part_no=meta["part_no"],
        chapter_no=meta["chapter_no"],
        title=meta["chapter_title"],
        topic=meta.get("topic"),
        order_no=meta["chapter_no"],
        is_published=is_published,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["jlpt_level", "part_no", "chapter_no"],
        set_={
            "title": meta["chapter_title"],
            "is_published": is_published,
        },
    )
    await db.execute(stmt)

    result = await db.execute(
        select(Chapter).where(
            cast(Chapter.jlpt_level, sa.Text()) == meta["jlpt_level"],
            Chapter.part_no == meta["part_no"],
            Chapter.chapter_no == meta["chapter_no"],
        )
    )
    return result.scalar_one()


async def _upsert_lesson(db: AsyncSession, chapter: Chapter, lesson_data: dict[str, Any], *, is_published: bool) -> Lesson:
    """Create or update lesson record."""
    stmt = pg_insert(Lesson).values(
        chapter_id=chapter.id,
        jlpt_level=_jlpt_str(chapter.jlpt_level),
        lesson_no=lesson_data["lesson_no"],
        chapter_lesson_no=lesson_data["chapter_lesson_no"],
        title=lesson_data["title"],
        topic=lesson_data["topic"],
        estimated_minutes=lesson_data["estimated_minutes"],
        content_jsonb=lesson_data["content_jsonb"],
        is_published=is_published,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["jlpt_level", "lesson_no"],
        set_={
            "title": lesson_data["title"],
            "topic": lesson_data["topic"],
            "content_jsonb": lesson_data["content_jsonb"],
            "is_published": is_published,
        },
    )
    await db.execute(stmt)

    result = await db.execute(
        select(Lesson).where(
            cast(Lesson.jlpt_level, sa.Text()) == _jlpt_str(chapter.jlpt_level),
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
                cast(Vocabulary.jlpt_level, sa.Text()) == _jlpt_str(lesson.jlpt_level),
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
                cast(Grammar.jlpt_level, sa.Text()) == _jlpt_str(lesson.jlpt_level),
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


async def _seed_one_chapter(db: AsyncSession, filepath: Path) -> dict[str, int]:
    """Seed one chapter from a content JSON file."""
    data = json.loads(filepath.read_text(encoding="utf-8"))
    meta = data["meta"]
    lessons_data = data["lessons"]
    is_published = _lesson_is_published(meta)

    chapter = await _upsert_chapter(db, meta)
    print(f"✅ Chapter {meta['chapter_no']}: {chapter.title} (id={chapter.id}, status={meta['status']}, published={is_published})")

    lesson_count = 0
    link_count = 0

    for ld in lessons_data:
        lesson = await _upsert_lesson(db, chapter, ld, is_published=is_published)
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

    return {"chapters": 1, "lessons": lesson_count, "item_links": link_count}


async def seed_lessons(db: AsyncSession) -> dict[str, int]:
    """Seed Part 1 lessons (Ch.01~06). Returns counts summary."""
    totals: dict[str, int] = {"chapters": 0, "lessons": 0, "item_links": 0}

    for filename in CONTENT_FILES:
        filepath = CONTENT_DIR / filename
        if not filepath.exists():
            print(f"⚠️  {filename} not found, skipping")
            continue

        counts = await _seed_one_chapter(db, filepath)
        for key in totals:
            totals[key] += counts[key]

    await db.commit()
    return totals


async def main() -> None:
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    print("Seeding Part 1 lessons (Ch.01~06)...")
    async with async_session() as db:
        counts = await seed_lessons(db)
        for key, val in counts.items():
            print(f"  {key}: {val}")

    await engine.dispose()
    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
