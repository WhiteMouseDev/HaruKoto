"""Add field column to tts_audio for per-field TTS

Each content type can have multiple TTS audio files (e.g. vocabulary has
reading, word, example_sentence). The new `field` column identifies which
field the audio corresponds to. Existing rows are backfilled with a
sensible default per target_type so the column can be NOT NULL.

Revision ID: j0k1l2m3n4o5
Revises: i9j0k1l2m3n4
Create Date: 2026-03-30 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "j0k1l2m3n4o5"
down_revision: str | None = "i9j0k1l2m3n4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Step 1: Add nullable field column
    op.add_column("tts_audio", sa.Column("field", sa.Text(), nullable=True))

    # Step 2: Backfill existing rows with default field per target_type
    op.execute("""
        UPDATE tts_audio SET field = CASE target_type
            WHEN 'vocabulary'        THEN 'reading'
            WHEN 'grammar'           THEN 'pattern'
            WHEN 'cloze'             THEN 'sentence'
            WHEN 'sentence_arrange'  THEN 'japanese_sentence'
            WHEN 'conversation'      THEN 'situation'
            ELSE 'reading'
        END
        WHERE field IS NULL
    """)

    # Step 3: Set NOT NULL + replace UniqueConstraint with 4-column version
    op.alter_column("tts_audio", "field", nullable=False)
    op.drop_constraint("tts_audio_target_type_target_id_speed_key", "tts_audio")
    op.create_unique_constraint(
        "uq_tts_audio_target_field",
        "tts_audio",
        ["target_type", "target_id", "speed", "field"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_tts_audio_target_field", "tts_audio")
    op.create_unique_constraint(
        "tts_audio_target_type_target_id_speed_key",
        "tts_audio",
        ["target_type", "target_id", "speed"],
    )
    op.drop_column("tts_audio", "field")
