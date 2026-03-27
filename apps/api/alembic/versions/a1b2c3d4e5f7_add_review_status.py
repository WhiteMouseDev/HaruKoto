"""add review_status to content and conversation tables

Revision ID: a1b2c3d4e5f7
Revises: 0e6f6c2a3136
Create Date: 2026-03-26 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "a1b2c3d4e5f7"
down_revision: str | None = "0e6f6c2a3136"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# PostgreSQL ENUM type for review_status
reviewstatus_enum = postgresql.ENUM(
    "needs_review",
    "approved",
    "rejected",
    name="reviewstatus",
    create_type=True,
)

_TABLES = [
    "vocabularies",
    "grammars",
    "cloze_questions",
    "sentence_arrange_questions",
    "conversation_scenarios",
]


def upgrade() -> None:
    # Create the enum type
    reviewstatus_enum.create(op.get_bind(), checkfirst=True)

    # Add review_status column and index to each table
    for table in _TABLES:
        op.add_column(
            table,
            sa.Column(
                "review_status",
                postgresql.ENUM(
                    "needs_review",
                    "approved",
                    "rejected",
                    name="reviewstatus",
                    create_type=False,
                ),
                nullable=False,
                server_default="needs_review",
            ),
        )
        op.create_index(
            f"idx_{table}_review_status",
            table,
            ["review_status"],
        )


def downgrade() -> None:
    # Drop indexes and columns in reverse order
    for table in reversed(_TABLES):
        op.drop_index(f"idx_{table}_review_status", table_name=table)
        op.drop_column(table, "review_status")

    # Drop the enum type
    reviewstatus_enum.drop(op.get_bind(), checkfirst=True)
