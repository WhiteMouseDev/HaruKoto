"""add SRS performance indexes for smart quiz

Indexes for 3-pool smart quiz queries:
- vocab_progress_lookup: (vocabulary_id, user_id) for answer verification
- vocab_progress_review: (user_id, next_review_at) WHERE next_review_at IS NOT NULL
- vocab_progress_retry: (user_id, interval) WHERE interval = 0 AND incorrect_count > 0

Revision ID: d4e5f6g7h8i9
Revises: c3d4e5f6g7h8
Create Date: 2026-03-17 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "d4e5f6g7h8i9"
down_revision: str | None = "c3d4e5f6g7h8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "idx_vocab_progress_lookup",
        "user_vocab_progress",
        ["vocabulary_id", "user_id"],
    )
    op.create_index(
        "idx_vocab_progress_review",
        "user_vocab_progress",
        ["user_id", "next_review_at"],
        postgresql_where="next_review_at IS NOT NULL",
    )
    op.create_index(
        "idx_vocab_progress_retry",
        "user_vocab_progress",
        ["user_id", "interval"],
        postgresql_where="interval = 0 AND incorrect_count > 0",
    )
    # Grammar equivalents
    op.create_index(
        "idx_grammar_progress_review",
        "user_grammar_progress",
        ["user_id", "next_review_at"],
        postgresql_where="next_review_at IS NOT NULL",
    )
    op.create_index(
        "idx_grammar_progress_retry",
        "user_grammar_progress",
        ["user_id", "interval"],
        postgresql_where="interval = 0 AND incorrect_count > 0",
    )


def downgrade() -> None:
    op.drop_index("idx_grammar_progress_retry", table_name="user_grammar_progress")
    op.drop_index("idx_grammar_progress_review", table_name="user_grammar_progress")
    op.drop_index("idx_vocab_progress_retry", table_name="user_vocab_progress")
    op.drop_index("idx_vocab_progress_review", table_name="user_vocab_progress")
    op.drop_index("idx_vocab_progress_lookup", table_name="user_vocab_progress")
