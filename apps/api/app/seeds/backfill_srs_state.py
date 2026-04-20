"""Backfill SRS state, introduced_by, and meaning_glosses_ko for existing progress data.

Maps existing user_vocab_progress and user_grammar_progress rows to new SRS columns.
Idempotent: safe to re-run (only updates rows still in default/NULL state).

Usage:
    cd apps/api
    python -m app.seeds.backfill_srs_state
"""

from __future__ import annotations

import asyncio
from typing import Any, cast

from sqlalchemy import text
from sqlalchemy.engine import CursorResult
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import settings

# ---------------------------------------------------------------------------
# SQL templates (parameterised by table name)
# ---------------------------------------------------------------------------

STATE_UPDATE_SQL = """
UPDATE {table} SET state = CASE
  WHEN mastered = TRUE THEN 'MASTERED'
  WHEN "interval" >= 4 THEN 'REVIEW'
  WHEN "interval" IN (1, 3) THEN 'LEARNING'
  WHEN "interval" = 0 AND incorrect_count > 0 THEN 'RELEARNING'
  ELSE 'UNSEEN'
END
WHERE state = 'UNSEEN';
"""

INTRODUCED_BY_SQL = """
UPDATE {table} SET introduced_by = 'QUIZ'
WHERE introduced_by IS NULL AND state != 'UNSEEN';
"""

# ---------------------------------------------------------------------------
# meaning_glosses_ko backfill
# Split meaning_ko by common delimiters into a TEXT[] array.
# Uses regexp_split_to_array with a pattern covering: ', ' '. ' '; ' '/' '·'
# Only touches rows where meaning_glosses_ko is NULL and meaning_ko is not.
# ---------------------------------------------------------------------------

GLOSSES_UPDATE_SQL = """
UPDATE {table}
SET meaning_glosses_ko = regexp_split_to_array(meaning_ko, E'\\s*[,;./·]\\s*|\\s*\\.\\s+')
WHERE (meaning_glosses_ko IS NULL OR meaning_glosses_ko = '{{}}'::text[])
  AND meaning_ko IS NOT NULL
  AND meaning_ko != '';
"""

PROGRESS_TABLES = [
    "user_vocab_progress",
    "user_grammar_progress",
]

CONTENT_TABLES = [
    "vocabularies",
    "grammars",
]


async def backfill_srs_state() -> None:
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as db:
        # --- 1. state backfill ---
        print("=== SRS state backfill ===")
        for table in PROGRESS_TABLES:
            result = cast(CursorResult[Any], await db.execute(text(STATE_UPDATE_SQL.format(table=table))))
            print(f"  {table}: {result.rowcount} rows updated (state)")

        # --- 2. introduced_by backfill ---
        print("\n=== introduced_by backfill ===")
        for table in PROGRESS_TABLES:
            result = cast(CursorResult[Any], await db.execute(text(INTRODUCED_BY_SQL.format(table=table))))
            print(f"  {table}: {result.rowcount} rows updated (introduced_by)")

        # --- 3. meaning_glosses_ko backfill ---
        print("\n=== meaning_glosses_ko backfill ===")
        for table in CONTENT_TABLES:
            result = cast(CursorResult[Any], await db.execute(text(GLOSSES_UPDATE_SQL.format(table=table))))
            print(f"  {table}: {result.rowcount} rows updated (meaning_glosses_ko)")

        await db.commit()

    await engine.dispose()
    print("\nDone!")


async def main() -> None:
    await backfill_srs_state()


if __name__ == "__main__":
    asyncio.run(main())
