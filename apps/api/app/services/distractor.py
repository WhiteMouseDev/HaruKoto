"""Distractor (wrong answer) safety filter service.

Generates safe distractors for MCQ quiz questions by ensuring no meaning
overlap between the correct answer and distractor options.

Safety rules (from 03-SRS-ENGINE.md §오답 안전장치):
1. Token intersection check on meaning_glosses_ko — any overlap → exclude
2. Same JLPT level preferred
3. Prefer items the user has already seen (if user_id provided)
4. Prefer items from same category_tag (WORD only)
5. Never include the correct answer itself
6. Distractors must not overlap with each other either

MVP-β: text-based filter only (ADR-001 — synonym_groups table deferred).
"""

from __future__ import annotations

import logging
import random
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Grammar, Vocabulary
from app.models.progress import UserGrammarProgress, UserVocabProgress

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Token extraction
# ---------------------------------------------------------------------------


def _extract_tokens(glosses: list[str]) -> set[str]:
    """Extract meaning tokens from a meaning_glosses_ko array.

    Each gloss element is split by whitespace to handle compound meanings
    like "~하는 것" → {"~하는", "것"}.

    Single-character particles (e.g. "을", "를", "이", "가") are kept because
    Korean meaning tokens are typically 2+ chars and particles rarely cause
    false collisions with actual meaning words.
    """
    tokens: set[str] = set()
    for gloss in glosses:
        gloss = gloss.strip()
        if not gloss:
            continue
        # Add the full gloss as a token
        tokens.add(gloss)
        # Also add sub-tokens split by whitespace
        for sub in gloss.split():
            sub = sub.strip()
            if sub:
                tokens.add(sub)
    return tokens


def _has_meaning_overlap(tokens_a: set[str], tokens_b: set[str]) -> bool:
    """Check if two token sets share any common meaning tokens."""
    return bool(tokens_a & tokens_b)


# ---------------------------------------------------------------------------
# Main API
# ---------------------------------------------------------------------------


async def generate_distractors(
    db: AsyncSession,
    correct_item_id: UUID,
    item_type: str,  # 'WORD' | 'GRAMMAR'
    jlpt_level: str,
    count: int = 3,
    user_id: UUID | None = None,
) -> list[dict]:
    """Generate safe distractor options for a quiz question.

    Returns list of {id, text} dicts for wrong answer options.

    Safety rules:
    1. Distractor meaning must NOT overlap with correct answer meaning
       (token intersection check on meaning_glosses_ko)
    2. Distractors should be from same JLPT level
    3. Prefer items the user has seen before (if user_id provided)
    4. Prefer items from same category_tag (if available)
    5. Never include the correct answer itself
    """
    if item_type == "WORD":
        model = Vocabulary
        progress_model = UserVocabProgress
        fk_col = UserVocabProgress.vocabulary_id
    elif item_type == "GRAMMAR":
        model = Grammar
        progress_model = UserGrammarProgress
        fk_col = UserGrammarProgress.grammar_id
    else:
        raise ValueError(f"Unknown item_type: {item_type!r}. Expected 'WORD' or 'GRAMMAR'.")

    # ── 1. Fetch correct item ──
    correct_item = await db.get(model, correct_item_id)
    if correct_item is None:
        logger.warning("Correct item %s not found (type=%s)", correct_item_id, item_type)
        return []

    correct_glosses = correct_item.meaning_glosses_ko or []
    correct_tokens = _extract_tokens(correct_glosses)

    # If no glosses, fall back to meaning_ko split by common delimiters
    if not correct_tokens and correct_item.meaning_ko:
        import re

        fallback = re.split(r"\s*[,;./·]\s*|\s*\.\s+", correct_item.meaning_ko)
        correct_tokens = _extract_tokens(fallback)

    correct_category_tag = getattr(correct_item, "category_tag", None)

    # ── 2. Fetch candidates from same JLPT level (exclude correct item) ──
    stmt = select(model).where(
        model.jlpt_level == jlpt_level,
        model.id != correct_item_id,
    )
    result = await db.execute(stmt)
    candidates = list(result.scalars().all())

    # ── 3. Fetch user-seen item IDs (if user_id provided) ──
    seen_ids: set[UUID] = set()
    if user_id is not None:
        seen_stmt = select(fk_col).where(
            progress_model.user_id == user_id,
            progress_model.state != "UNSEEN",
        )
        seen_result = await db.execute(seen_stmt)
        seen_ids = {row[0] for row in seen_result.all()}

    # ── 4. Filter out candidates with meaning overlap ──
    safe_candidates: list[tuple] = []  # (item, is_same_category, is_seen)
    accepted_token_sets: list[set[str]] = [correct_tokens]  # track to avoid inter-distractor overlap

    for candidate in candidates:
        candidate_glosses = candidate.meaning_glosses_ko or []
        candidate_tokens = _extract_tokens(candidate_glosses)

        # Fallback if no glosses
        if not candidate_tokens and candidate.meaning_ko:
            import re

            fallback = re.split(r"\s*[,;./·]\s*|\s*\.\s+", candidate.meaning_ko)
            candidate_tokens = _extract_tokens(fallback)

        # Skip if empty tokens (can't verify safety)
        if not candidate_tokens:
            continue

        # Check overlap with correct answer
        if _has_meaning_overlap(correct_tokens, candidate_tokens):
            continue

        is_same_category = correct_category_tag is not None and getattr(candidate, "category_tag", None) == correct_category_tag
        is_seen = candidate.id in seen_ids

        safe_candidates.append((candidate, is_same_category, is_seen, candidate_tokens))

    # ── 5. Sort: same category_tag first, then user-seen, then random ──
    # Shuffle first to randomize within same priority group
    random.shuffle(safe_candidates)
    safe_candidates.sort(key=lambda x: (not x[1], not x[2]))

    # ── 6. Select top `count`, ensuring no inter-distractor overlap ──
    selected: list[dict] = []

    for candidate, _is_cat, _is_seen, candidate_tokens in safe_candidates:
        if len(selected) >= count:
            break

        # Check overlap with already-selected distractors
        has_inter_overlap = any(
            _has_meaning_overlap(candidate_tokens, existing_tokens)
            for existing_tokens in accepted_token_sets[1:]  # skip correct_tokens (index 0)
        )
        if has_inter_overlap:
            continue

        accepted_token_sets.append(candidate_tokens)
        selected.append(
            {
                "id": str(candidate.id),
                "text": candidate.meaning_ko,
            }
        )

    if len(selected) < count:
        logger.warning(
            "Only %d safe distractors found for item %s (requested %d). JLPT level=%s, type=%s",
            len(selected),
            correct_item_id,
            count,
            jlpt_level,
            item_type,
        )

    return selected
