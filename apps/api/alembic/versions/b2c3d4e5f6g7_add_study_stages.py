"""add study_stages and user_study_stage_progress tables

Revision ID: b2c3d4e5f6g7
Revises: a1b2c3d4e5f6
Create Date: 2026-03-13 12:00:00.000000
"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "b2c3d4e5f6g7"
down_revision: str | None = "a1b2c3d4e5f6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "study_stages",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("category", sa.Text(), nullable=False),
        sa.Column("jlpt_level", sa.Enum("N5", "N4", "N3", "N2", "N1", name="JlptLevel", create_constraint=False), nullable=False),
        sa.Column("stage_number", sa.Integer(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("content_ids", postgresql.JSON(astext_type=sa.Text()), nullable=False),
        sa.Column("unlock_after", postgresql.UUID(as_uuid=True), sa.ForeignKey("study_stages.id"), nullable=True),
        sa.Column("order", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("category", "jlpt_level", "stage_number"),
    )

    op.create_table(
        "user_study_stage_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("stage_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("study_stages.id", ondelete="CASCADE"), nullable=False),
        sa.Column("best_score", sa.Integer(), server_default="0", nullable=False),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        sa.Column("completed", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_attempted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "stage_id"),
    )


def downgrade() -> None:
    op.drop_table("user_study_stage_progress")
    op.drop_table("study_stages")
