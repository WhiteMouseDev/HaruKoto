"""add tts_audio table for TTS metadata tracking

Separate table to track TTS generation metadata (provider, model, speed)
independent of vocabulary/kana content tables.

Revision ID: e5f6g7h8i9j0
Revises: d4e5f6g7h8i9
Create Date: 2026-03-18 09:30:00.000000
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "e5f6g7h8i9j0"
down_revision = "d4e5f6g7h8i9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tts_audio",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("target_type", sa.Text(), nullable=False),
        sa.Column("target_id", sa.Text(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("speed", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("provider", sa.Text(), nullable=False),
        sa.Column("model", sa.Text(), nullable=False),
        sa.Column("audio_url", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("target_type", "target_id", "speed"),
    )

    # Index for fast lookups by target
    op.create_index("ix_tts_audio_target", "tts_audio", ["target_type", "target_id"])

    # Index for filtering by provider (useful for batch re-generation)
    op.create_index("ix_tts_audio_provider", "tts_audio", ["provider"])


def downgrade() -> None:
    op.drop_index("ix_tts_audio_provider")
    op.drop_index("ix_tts_audio_target")
    op.drop_table("tts_audio")
