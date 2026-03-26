"""Tests for admin content endpoints.

Coverage plan:
  - test_vocabulary_list: GET /api/v1/admin/content/vocabulary returns paginated list
  - test_grammar_list: GET /api/v1/admin/content/grammar returns paginated list
  - test_quiz_list: GET /api/v1/admin/content/quiz returns merged cloze + sentence_arrange list
  - test_conversation_list: GET /api/v1/admin/content/conversation returns paginated list
  - test_filter_params: jlpt_level, review_status, search filters narrow results
  - test_search: search param filters by text across key columns
  - test_stats: GET /api/v1/admin/content/stats returns counts per content type
  - test_non_reviewer_rejected: non-reviewer JWT receives 403
"""

import pytest


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_vocabulary_list() -> None:
    """GET /api/v1/admin/content/vocabulary returns paginated vocabulary list with review_status field."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_grammar_list() -> None:
    """GET /api/v1/admin/content/grammar returns paginated grammar list."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_quiz_list() -> None:
    """GET /api/v1/admin/content/quiz returns merged cloze and sentence_arrange items."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_conversation_list() -> None:
    """GET /api/v1/admin/content/conversation returns paginated conversation scenario list."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_filter_params() -> None:
    """jlpt_level, review_status, and quiz_type/category filter params narrow results correctly."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_search() -> None:
    """search query param filters vocabulary by word/reading/meaning_ko, grammar by pattern/meaning_ko, etc."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_stats() -> None:
    """GET /api/v1/admin/content/stats returns needs_review/approved/rejected counts per content type."""
    pass


@pytest.mark.skip(reason="Wave 1 — DB fixture setup pending")
def test_non_reviewer_rejected() -> None:
    """A JWT without app_metadata.reviewer=true receives HTTP 403 from all admin content endpoints."""
    pass
