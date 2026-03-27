"""Tests for the review-queue endpoint.

Coverage:
  - test_review_queue_vocabulary_returns_needs_review_ids: vocabulary filter by review_status
  - test_review_queue_quiz_returns_merged_cloze_and_arrange: quiz merges cloze + sentence_arrange with quiz_type
  - test_review_queue_unknown_content_type_returns_400: invalid content_type gives 400
  - test_review_queue_empty_returns_empty_list: no needs_review items returns empty list
  - test_review_queue_respects_jlpt_filter: jlpt_level filter narrows results
"""

import pytest


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_review_queue_vocabulary_returns_needs_review_ids() -> None:
    """GET /vocabulary/review-queue returns only needs_review IDs in created_at ASC order."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_review_queue_quiz_returns_merged_cloze_and_arrange() -> None:
    """GET /quiz/review-queue returns merged cloze + sentence_arrange items with quiz_type discriminator."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_review_queue_unknown_content_type_returns_400() -> None:
    """GET /invalid/review-queue returns HTTP 400."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_review_queue_empty_returns_empty_list() -> None:
    """GET /{content_type}/review-queue with no needs_review items returns ids: [], total: 0, capped: false."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_review_queue_respects_jlpt_filter() -> None:
    """jlpt_level query param filters review queue to matching JLPT level only."""
    pass
