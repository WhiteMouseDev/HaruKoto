"""add SRS state columns to user_vocab_progress and user_grammar_progress,
add meaning_glosses_ko/synonym_group_id/category_tag to vocabularies/grammars.

Based on 04-DATA-SCHEMA.md §4 + ADR-001 (synonym_groups table deferred).

Revision ID: h8i9j0k1l2m3
Revises: g7h8i9j0k1l2
Create Date: 2026-03-20 22:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "h8i9j0k1l2m3"
down_revision: str | None = "g7h8i9j0k1l2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Columns to add to both user_vocab_progress and user_grammar_progress
SRS_COLUMNS = [
    ("state", sa.Text(), False, "UNSEEN"),
    ("introduced_by", sa.Text(), True, None),
    ("learning_step", sa.SmallInteger(), False, "0"),
    ("source_lesson_id", postgresql.UUID(as_uuid=True), True, None),
    ("fsrs_stability", sa.Float(), False, "0"),
    ("fsrs_difficulty", sa.Float(), False, "5"),
    ("fsrs_last_rating", sa.SmallInteger(), True, None),
    ("fsrs_reps", sa.Integer(), False, "0"),
    ("fsrs_lapses", sa.Integer(), False, "0"),
    ("scheduler_version", sa.SmallInteger(), False, "1"),
    ("jp_kr_correct", sa.Integer(), False, "0"),
    ("jp_kr_total", sa.Integer(), False, "0"),
    ("kr_jp_correct", sa.Integer(), False, "0"),
    ("kr_jp_total", sa.Integer(), False, "0"),
    ("guess_risk", sa.Numeric(4, 3), False, "0"),
    ("last_presented_on", sa.Date(), True, None),
]


def upgrade() -> None:
    # ── 1. user_vocab_progress SRS columns ──
    for col_name, col_type, nullable, default in SRS_COLUMNS:
        op.add_column(
            "user_vocab_progress",
            sa.Column(
                col_name,
                col_type,
                nullable=nullable,
                server_default=default,
            ),
        )

    op.create_index("idx_uvp_state_due", "user_vocab_progress", ["user_id", "state", "next_review_at"])
    op.create_index("idx_uvp_today_seen", "user_vocab_progress", ["user_id", "last_presented_on"])

    # ── 2. user_grammar_progress SRS columns (동일) ──
    for col_name, col_type, nullable, default in SRS_COLUMNS:
        op.add_column(
            "user_grammar_progress",
            sa.Column(
                col_name,
                col_type,
                nullable=nullable,
                server_default=default,
            ),
        )

    op.create_index("idx_ugp_state_due", "user_grammar_progress", ["user_id", "state", "next_review_at"])
    op.create_index("idx_ugp_today_seen", "user_grammar_progress", ["user_id", "last_presented_on"])

    # ── 3. vocabularies 오답 안전장치 컬럼 ──
    op.add_column("vocabularies", sa.Column("meaning_glosses_ko", postgresql.ARRAY(sa.Text()), nullable=False, server_default="{}"))
    op.add_column("vocabularies", sa.Column("synonym_group_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column("vocabularies", sa.Column("category_tag", sa.Text(), nullable=True))

    # ── 4. grammars 확장 ──
    op.add_column("grammars", sa.Column("meaning_glosses_ko", postgresql.ARRAY(sa.Text()), nullable=False, server_default="{}"))
    op.add_column("grammars", sa.Column("synonym_group_id", postgresql.UUID(as_uuid=True), nullable=True))


def downgrade() -> None:
    # grammars
    op.drop_column("grammars", "synonym_group_id")
    op.drop_column("grammars", "meaning_glosses_ko")

    # vocabularies
    op.drop_column("vocabularies", "category_tag")
    op.drop_column("vocabularies", "synonym_group_id")
    op.drop_column("vocabularies", "meaning_glosses_ko")

    # user_grammar_progress
    op.drop_index("idx_ugp_today_seen", table_name="user_grammar_progress")
    op.drop_index("idx_ugp_state_due", table_name="user_grammar_progress")
    for col_name, _, _, _ in reversed(SRS_COLUMNS):
        op.drop_column("user_grammar_progress", col_name)

    # user_vocab_progress
    op.drop_index("idx_uvp_today_seen", table_name="user_vocab_progress")
    op.drop_index("idx_uvp_state_due", table_name="user_vocab_progress")
    for col_name, _, _, _ in reversed(SRS_COLUMNS):
        op.drop_column("user_vocab_progress", col_name)
