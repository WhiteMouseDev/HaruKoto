"""Seed lesson content from package lesson JSON files.

Usage:
    cd apps/api
    python -m app.seeds.lessons
"""

from __future__ import annotations

import argparse
import asyncio
import json
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy import cast, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models.content import Grammar, Vocabulary
from app.models.lesson import Chapter, Lesson, LessonItemLink

DEFAULT_LESSON_LEVEL = "N5"

# Content JSON root directory (relative to project root)
CONTENT_ROOT = Path(__file__).resolve().parents[4] / "packages" / "database" / "data" / "lessons"

# Lesson content files by JLPT level. Files can be PILOT/PUBLISHED or DRAFT.
CONTENT_FILES_BY_LEVEL = {
    "N5": [
        "ch01-greetings-and-first-meetings.json",
        "ch02-introducing-things-and-people.json",
        "ch03-location-and-movement.json",
        "ch04-verb-basics.json",
        "ch05-past-and-sequence.json",
        "ch06-progress-and-habits.json",
        "ch07-foundation-expression-reinforcement.json",
        "ch08-daily-expressions-and-verb-foundations.json",
        "ch09-expression-contrast-and-choice.json",
    ],
    "N4": [
        "ch01-core-directions-and-judgment.json",
        "ch02-reasons-conditions-and-intent.json",
    ],
}

# Backwards-compatible aliases for tests and one-off scripts that still inspect
# the default N5 seed source directly.
CONTENT_DIR = CONTENT_ROOT / DEFAULT_LESSON_LEVEL.lower()
CONTENT_FILES = CONTENT_FILES_BY_LEVEL[DEFAULT_LESSON_LEVEL]

PUBLISHABLE_META_STATUSES = {"PILOT", "PUBLISHED"}
ALLOWED_META_STATUSES = {"DRAFT", *PUBLISHABLE_META_STATUSES}


@dataclass(frozen=True, slots=True)
class SeedItemLink:
    item_type: str
    vocabulary_id: UUID | None
    grammar_id: UUID | None
    item_order: int


def _jlpt_str(level: object) -> str:
    """Extract string value from JlptLevel enum or plain string."""
    return level.value if hasattr(level, "value") else str(level)


def _normalize_lesson_level(level: str) -> str:
    normalized = level.strip().upper()
    if normalized not in CONTENT_FILES_BY_LEVEL:
        supported = ", ".join(sorted(CONTENT_FILES_BY_LEVEL))
        raise ValueError(f"Unsupported lesson seed level: {normalized} (supported: {supported})")
    return normalized


def _selected_lesson_levels(levels: Sequence[str] | None = None) -> tuple[str, ...]:
    selected_levels = levels or (DEFAULT_LESSON_LEVEL,)
    return tuple(dict.fromkeys(_normalize_lesson_level(level) for level in selected_levels))


def _content_dir_for_level(level: str) -> Path:
    return CONTENT_ROOT / level.lower()


def _iter_content_filepaths(levels: Sequence[str] | None = None) -> Iterator[Path]:
    for level in _selected_lesson_levels(levels):
        content_dir = _content_dir_for_level(level)
        for filename in CONTENT_FILES_BY_LEVEL[level]:
            yield content_dir / filename


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


async def _resolve_vocabulary(db: AsyncSession, *, jlpt_level: object, order: int) -> Vocabulary:
    result = await db.execute(
        select(Vocabulary).where(
            cast(Vocabulary.jlpt_level, sa.Text()) == _jlpt_str(jlpt_level),
            Vocabulary.order == order,
        )
    )
    vocab = result.scalar_one_or_none()
    if vocab is None:
        raise ValueError(f"Vocabulary order={order} not found for {_jlpt_str(jlpt_level)}")
    return vocab


async def _resolve_grammar(db: AsyncSession, *, jlpt_level: object, order: int) -> Grammar:
    result = await db.execute(
        select(Grammar).where(
            cast(Grammar.jlpt_level, sa.Text()) == _jlpt_str(jlpt_level),
            Grammar.order == order,
        )
    )
    grammar = result.scalar_one_or_none()
    if grammar is None:
        raise ValueError(f"Grammar order={order} not found for {_jlpt_str(jlpt_level)}")
    return grammar


async def _build_expected_item_links(
    db: AsyncSession,
    *,
    jlpt_level: object,
    vocab_orders: list[int],
    grammar_order: int | None,
) -> list[SeedItemLink]:
    """Resolve seed order references into the exact link list a lesson should have."""
    expected_links: list[SeedItemLink] = []

    for idx, order in enumerate(vocab_orders):
        vocab = await _resolve_vocabulary(db, jlpt_level=jlpt_level, order=order)
        expected_links.append(
            SeedItemLink(
                item_type="WORD",
                vocabulary_id=vocab.id,
                grammar_id=None,
                item_order=idx + 1,
            )
        )

    if grammar_order is not None:
        grammar = await _resolve_grammar(db, jlpt_level=jlpt_level, order=grammar_order)
        expected_links.append(
            SeedItemLink(
                item_type="GRAMMAR",
                vocabulary_id=None,
                grammar_id=grammar.id,
                item_order=len(vocab_orders) + 1,
            )
        )

    return expected_links


async def _replace_item_links(
    db: AsyncSession,
    lesson: Lesson,
    vocab_orders: list[int],
    grammar_order: int | None,
) -> dict[str, int]:
    """Replace lesson item links with the seed file's canonical order."""
    expected_links = await _build_expected_item_links(
        db,
        jlpt_level=lesson.jlpt_level,
        vocab_orders=vocab_orders,
        grammar_order=grammar_order,
    )

    delete_result = await db.execute(sa.delete(LessonItemLink).where(LessonItemLink.lesson_id == lesson.id))
    rowcount = getattr(delete_result, "rowcount", 0) or 0
    deleted_count = max(int(rowcount), 0)

    for expected_link in expected_links:
        stmt = pg_insert(LessonItemLink).values(
            lesson_id=lesson.id,
            item_type=expected_link.item_type,
            vocabulary_id=expected_link.vocabulary_id,
            grammar_id=expected_link.grammar_id,
            item_order=expected_link.item_order,
            is_core=True,
        )
        stmt = stmt.on_conflict_do_nothing()
        await db.execute(stmt)

    return {"created": len(expected_links), "deleted": deleted_count}


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
    deleted_link_count = 0

    for ld in lessons_data:
        lesson = await _upsert_lesson(db, chapter, ld, is_published=is_published)
        print(f"  ✅ Lesson {ld['lesson_id']}: {ld['title']}")

        links = await _replace_item_links(
            db,
            lesson,
            vocab_orders=ld["vocab_orders"],
            grammar_order=ld["grammar"]["grammar_order"],
        )
        print(f"     → {links['created']} items linked ({links['deleted']} stale removed)")

        lesson_count += 1
        link_count += links["created"]
        deleted_link_count += links["deleted"]

    return {"chapters": 1, "lessons": lesson_count, "item_links": link_count, "item_links_deleted": deleted_link_count}


async def seed_lessons(db: AsyncSession, *, levels: Sequence[str] | None = None) -> dict[str, int]:
    """Seed lessons for configured levels. Returns counts summary."""
    totals: dict[str, int] = {"chapters": 0, "lessons": 0, "item_links": 0, "item_links_deleted": 0}

    for filepath in _iter_content_filepaths(levels):
        if not filepath.exists():
            print(f"⚠️  {filepath.name} not found, skipping")
            continue

        counts = await _seed_one_chapter(db, filepath)
        for key in totals:
            totals[key] += counts[key]

    await db.commit()
    return totals


def _item_link_identity(item: SeedItemLink | LessonItemLink) -> tuple[str, str | None, str | None, int]:
    return (
        item.item_type,
        str(item.vocabulary_id) if item.vocabulary_id is not None else None,
        str(item.grammar_id) if item.grammar_id is not None else None,
        item.item_order,
    )


async def _audit_one_chapter(db: AsyncSession, filepath: Path) -> dict[str, int]:
    data = json.loads(filepath.read_text(encoding="utf-8"))
    meta = data["meta"]
    lessons_data = data["lessons"]
    counts = {"chapters": 1, "lessons": 0, "missing_lessons": 0, "content_mismatches": 0, "item_link_mismatches": 0}

    for ld in lessons_data:
        result = await db.execute(
            select(Lesson)
            .where(
                cast(Lesson.jlpt_level, sa.Text()) == meta["jlpt_level"],
                Lesson.lesson_no == ld["lesson_no"],
            )
            .options(selectinload(Lesson.item_links))
        )
        lesson = result.scalar_one_or_none()
        counts["lessons"] += 1
        if lesson is None:
            print(f"  Missing lesson: {ld['lesson_id']} ({meta['jlpt_level']} #{ld['lesson_no']})")
            counts["missing_lessons"] += 1
            continue

        if lesson.content_jsonb != ld["content_jsonb"]:
            print(f"  Content mismatch: {ld['lesson_id']} ({meta['jlpt_level']} #{ld['lesson_no']})")
            counts["content_mismatches"] += 1

        expected_links = await _build_expected_item_links(
            db,
            jlpt_level=meta["jlpt_level"],
            vocab_orders=ld["vocab_orders"],
            grammar_order=ld["grammar"]["grammar_order"],
        )
        expected_identities = sorted((_item_link_identity(link) for link in expected_links), key=lambda item: item[3])
        actual_identities = sorted((_item_link_identity(link) for link in lesson.item_links), key=lambda item: item[3])
        if actual_identities != expected_identities:
            print(f"  Item link mismatch: {ld['lesson_id']} (expected={len(expected_identities)}, actual={len(actual_identities)})")
            counts["item_link_mismatches"] += 1

    return counts


async def audit_lesson_seed_sync(db: AsyncSession, *, levels: Sequence[str] | None = None) -> dict[str, int]:
    """Compare current DB lessons against the seed source without writing data."""
    totals = {"chapters": 0, "lessons": 0, "missing_lessons": 0, "content_mismatches": 0, "item_link_mismatches": 0}

    for filepath in _iter_content_filepaths(levels):
        if not filepath.exists():
            print(f"⚠️  {filepath.name} not found, skipping")
            continue

        counts = await _audit_one_chapter(db, filepath)
        for key in totals:
            totals[key] += counts[key]

    return totals


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed or audit Part 1 lesson data.")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Compare DB lessons with seed files without writing changes.",
    )
    parser.add_argument(
        "--level",
        action="append",
        dest="levels",
        help="JLPT lesson level to process. Repeat for multiple levels. Defaults to N5.",
    )
    parser.add_argument(
        "--all-levels",
        action="store_true",
        help="Process every configured lesson seed level.",
    )
    args = parser.parse_args()
    if args.all_levels and args.levels:
        parser.error("--level cannot be combined with --all-levels")
    return args


def _levels_from_args(args: argparse.Namespace) -> tuple[str, ...]:
    if args.all_levels:
        return tuple(CONTENT_FILES_BY_LEVEL)
    return _selected_lesson_levels(args.levels)


def _levels_label(levels: Sequence[str]) -> str:
    return ", ".join(levels)


async def main() -> None:
    args = _parse_args()
    levels = _levels_from_args(args)
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)
    has_mismatch = False

    try:
        if args.check:
            print(f"Checking lesson seed sync for {_levels_label(levels)}...")
            async with async_session() as db:
                counts = await audit_lesson_seed_sync(db, levels=levels)
                for key, val in counts.items():
                    print(f"  {key}: {val}")
            has_mismatch = any(counts[key] for key in ("missing_lessons", "content_mismatches", "item_link_mismatches"))
        else:
            print(f"Seeding lessons for {_levels_label(levels)}...")
            async with async_session() as db:
                counts = await seed_lessons(db, levels=levels)
                for key, val in counts.items():
                    print(f"  {key}: {val}")
    finally:
        await engine.dispose()

    if has_mismatch:
        raise SystemExit(1)

    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
