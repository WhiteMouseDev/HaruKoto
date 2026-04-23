from __future__ import annotations

import uuid
from collections.abc import Sequence
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, UserGrammarProgress, UserVocabProgress, Vocabulary
from app.models.enums import JlptLevel
from app.schemas.stats import (
    JlptLevelProgress,
    JlptProgressResponse,
    JlptProgressStat,
)

MasteryCounts = dict[tuple[JlptLevel, bool], int]


async def get_jlpt_progress_data(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    current_jlpt_level: JlptLevel,
) -> JlptProgressResponse:
    vocab_totals = await _load_content_totals(db, Vocabulary)
    grammar_totals = await _load_content_totals(db, Grammar)
    vocab_progress = await _load_vocab_progress_counts(db, user_id=user_id)
    grammar_progress = await _load_grammar_progress_counts(db, user_id=user_id)

    return JlptProgressResponse(
        levels=[
            _build_level_progress(
                jlpt_level=jlpt_level,
                vocab_total=vocab_totals.get(jlpt_level, 0),
                grammar_total=grammar_totals.get(jlpt_level, 0),
                vocab_progress=vocab_progress,
                grammar_progress=grammar_progress,
            )
            for jlpt_level in JlptLevel
            if _should_include_level(
                jlpt_level=jlpt_level,
                current_jlpt_level=current_jlpt_level,
                vocab_total=vocab_totals.get(jlpt_level, 0),
                grammar_total=grammar_totals.get(jlpt_level, 0),
                vocab_progress=vocab_progress,
                grammar_progress=grammar_progress,
            )
        ]
    )


async def _load_content_totals(
    db: AsyncSession,
    model: type[Vocabulary] | type[Grammar],
) -> dict[JlptLevel, int]:
    result = await db.execute(select(model.jlpt_level, func.count(model.id)).group_by(model.jlpt_level))
    return {row[0]: row[1] for row in result.all()}


async def _load_vocab_progress_counts(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
) -> MasteryCounts:
    result = await db.execute(
        select(Vocabulary.jlpt_level, UserVocabProgress.mastered, func.count(UserVocabProgress.id))
        .join(Vocabulary)
        .where(UserVocabProgress.user_id == user_id)
        .group_by(Vocabulary.jlpt_level, UserVocabProgress.mastered)
    )
    return _mastery_counts(result.all())


async def _load_grammar_progress_counts(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
) -> MasteryCounts:
    result = await db.execute(
        select(Grammar.jlpt_level, UserGrammarProgress.mastered, func.count(UserGrammarProgress.id))
        .join(Grammar)
        .where(UserGrammarProgress.user_id == user_id)
        .group_by(Grammar.jlpt_level, UserGrammarProgress.mastered)
    )
    return _mastery_counts(result.all())


def _mastery_counts(rows: Sequence[Any]) -> MasteryCounts:
    counts: MasteryCounts = {}
    for row in rows:
        counts[(row[0], row[1])] = row[2]
    return counts


def _should_include_level(
    *,
    jlpt_level: JlptLevel,
    current_jlpt_level: JlptLevel,
    vocab_total: int,
    grammar_total: int,
    vocab_progress: MasteryCounts,
    grammar_progress: MasteryCounts,
) -> bool:
    if vocab_total == 0 and grammar_total == 0:
        return False

    return _has_progress(jlpt_level, vocab_progress, grammar_progress) or jlpt_level == current_jlpt_level


def _has_progress(
    jlpt_level: JlptLevel,
    vocab_progress: MasteryCounts,
    grammar_progress: MasteryCounts,
) -> bool:
    return (
        vocab_progress.get((jlpt_level, True), 0)
        + vocab_progress.get((jlpt_level, False), 0)
        + grammar_progress.get((jlpt_level, True), 0)
        + grammar_progress.get((jlpt_level, False), 0)
        > 0
    )


def _build_level_progress(
    *,
    jlpt_level: JlptLevel,
    vocab_total: int,
    grammar_total: int,
    vocab_progress: MasteryCounts,
    grammar_progress: MasteryCounts,
) -> JlptLevelProgress:
    return JlptLevelProgress(
        level=jlpt_level.value,
        vocabulary=JlptProgressStat(
            total=vocab_total,
            mastered=vocab_progress.get((jlpt_level, True), 0),
            in_progress=vocab_progress.get((jlpt_level, False), 0),
        ),
        grammar=JlptProgressStat(
            total=grammar_total,
            mastered=grammar_progress.get((jlpt_level, True), 0),
            in_progress=grammar_progress.get((jlpt_level, False), 0),
        ),
    )
