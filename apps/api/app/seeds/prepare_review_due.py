"""Prepare existing SRS progress rows for review CTA UAT.

Usage:
    cd apps/api
    uv run python -m app.seeds.prepare_review_due --email test1@test.com
    uv run python -m app.seeds.prepare_review_due --email test1@test.com --apply
"""

from __future__ import annotations

import argparse
import asyncio
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING, cast

import sqlalchemy as sa
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

if TYPE_CHECKING:
    from app.models.progress import UserGrammarProgress, UserVocabProgress
    from app.models.user import User

DUE_STATES = ("RELEARNING", "LEARNING", "REVIEW", "PROVISIONAL")


@dataclass(frozen=True, slots=True)
class PrepareReviewDueOptions:
    email: str
    jlpt_level: str
    word_count: int
    grammar_count: int
    due_minutes_ago: int
    apply: bool


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        msg = "value must be 0 or greater"
        raise argparse.ArgumentTypeError(msg)
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Mark existing SRS progress rows as due for review CTA UAT.",
    )
    parser.add_argument(
        "--email",
        required=True,
        help="Target UAT account email. Use a test account only.",
    )
    parser.add_argument(
        "--jlpt-level",
        default="N5",
        help="JLPT level to prepare. Defaults to N5.",
    )
    parser.add_argument(
        "--word-count",
        type=_positive_int,
        default=3,
        help="Maximum vocabulary progress rows to mark due. Defaults to 3.",
    )
    parser.add_argument(
        "--grammar-count",
        type=_positive_int,
        default=2,
        help="Maximum grammar progress rows to mark due. Defaults to 2.",
    )
    parser.add_argument(
        "--due-minutes-ago",
        type=_positive_int,
        default=5,
        help="How far in the past next_review_at should be set. Defaults to 5.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply the update. Without this flag the command is a dry run.",
    )
    return parser


def parse_options(argv: Sequence[str] | None = None) -> PrepareReviewDueOptions:
    namespace = build_parser().parse_args(argv)
    return PrepareReviewDueOptions(
        email=cast(str, namespace.email).strip(),
        jlpt_level=cast(str, namespace.jlpt_level).strip().upper(),
        word_count=cast(int, namespace.word_count),
        grammar_count=cast(int, namespace.grammar_count),
        due_minutes_ago=cast(int, namespace.due_minutes_ago),
        apply=cast(bool, namespace.apply),
    )


async def _load_user(db: AsyncSession, email: str) -> User:
    from app.models.user import User

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None:
        msg = f"UAT user not found: {email}"
        raise ValueError(msg)
    return user


async def _load_vocab_progress(
    db: AsyncSession,
    *,
    user_id: object,
    jlpt_level: str,
    limit: int,
) -> list[UserVocabProgress]:
    from app.models.content import Vocabulary
    from app.models.progress import UserVocabProgress

    if limit == 0:
        return []

    result = await db.execute(
        select(UserVocabProgress)
        .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(
            UserVocabProgress.user_id == user_id,
            UserVocabProgress.state.in_(DUE_STATES),
            sa.cast(Vocabulary.jlpt_level, sa.Text) == jlpt_level,
        )
        .order_by(UserVocabProgress.next_review_at.asc(), UserVocabProgress.updated_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def _load_grammar_progress(
    db: AsyncSession,
    *,
    user_id: object,
    jlpt_level: str,
    limit: int,
) -> list[UserGrammarProgress]:
    from app.models.content import Grammar
    from app.models.progress import UserGrammarProgress

    if limit == 0:
        return []

    result = await db.execute(
        select(UserGrammarProgress)
        .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
        .where(
            UserGrammarProgress.user_id == user_id,
            UserGrammarProgress.state.in_(DUE_STATES),
            sa.cast(Grammar.jlpt_level, sa.Text) == jlpt_level,
        )
        .order_by(UserGrammarProgress.next_review_at.asc(), UserGrammarProgress.updated_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def prepare_review_due(options: PrepareReviewDueOptions) -> None:
    from app.config import settings
    from app.services.lesson_review_summary_query import get_review_summary_data

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)
    now = datetime.now(UTC)
    due_at = now - timedelta(minutes=options.due_minutes_ago)

    try:
        async with async_session() as db:
            user = await _load_user(db, options.email)
            before = await get_review_summary_data(db, user, jlpt_level=options.jlpt_level)
            vocab_progress = await _load_vocab_progress(
                db,
                user_id=user.id,
                jlpt_level=options.jlpt_level,
                limit=options.word_count,
            )
            grammar_progress = await _load_grammar_progress(
                db,
                user_id=user.id,
                jlpt_level=options.jlpt_level,
                limit=options.grammar_count,
            )

            if options.apply:
                for vocab_row in vocab_progress:
                    vocab_row.next_review_at = due_at
                    vocab_row.updated_at = now
                for grammar_row in grammar_progress:
                    grammar_row.next_review_at = due_at
                    grammar_row.updated_at = now
                await db.flush()
                after = await get_review_summary_data(db, user, jlpt_level=options.jlpt_level)
                await db.commit()
            else:
                after = before

            mode = "APPLY" if options.apply else "DRY RUN"
            print(f"[{mode}] review due preparation for {options.email} / {options.jlpt_level}")
            print(f"  before: wordDue={before.word_due}, grammarDue={before.grammar_due}, totalDue={before.total_due}")
            print(f"  selected: word={len(vocab_progress)}, grammar={len(grammar_progress)}, dueAt={due_at.isoformat()}")
            print(f"  after:  wordDue={after.word_due}, grammarDue={after.grammar_due}, totalDue={after.total_due}")
            if not options.apply:
                print("  no rows updated; rerun with --apply to mutate the test account")
    finally:
        await engine.dispose()


async def main(argv: Sequence[str] | None = None) -> None:
    await prepare_review_due(parse_options(argv))


if __name__ == "__main__":
    asyncio.run(main())
