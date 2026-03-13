"""add app_settings to users, grammar/sentences/study_minutes to daily_progress

Tasks 2-8, 2-12, 2-13: Add app_settings JSONB column to users table,
grammar_studied, sentences_studied, study_minutes columns to daily_progress table.

Revision ID: c3d4e5f6g7h8
Revises: b2c3d4e5f6g7
Create Date: 2026-03-13 14:00:00.000000
"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "c3d4e5f6g7h8"
down_revision: str | None = "b2c3d4e5f6g7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Task 2-8: Add app_settings JSONB column to users
    op.add_column("users", sa.Column("app_settings", postgresql.JSONB(), nullable=True))

    # Task 2-12: Add grammar_studied and sentences_studied to daily_progress
    op.add_column("daily_progress", sa.Column("grammar_studied", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("daily_progress", sa.Column("sentences_studied", sa.Integer(), nullable=False, server_default="0"))

    # Task 2-13: Add study_minutes to daily_progress
    op.add_column("daily_progress", sa.Column("study_minutes", sa.Integer(), nullable=False, server_default="0"))


def downgrade() -> None:
    op.drop_column("daily_progress", "study_minutes")
    op.drop_column("daily_progress", "sentences_studied")
    op.drop_column("daily_progress", "grammar_studied")
    op.drop_column("users", "app_settings")
