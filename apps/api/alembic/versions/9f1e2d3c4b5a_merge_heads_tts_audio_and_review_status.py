"""merge heads — tts_audio field + review workflow

Revision ID: 9f1e2d3c4b5a
Revises: 6d79ca027510, j0k1l2m3n4o5
Create Date: 2026-04-18 15:30:00.000000
"""

from collections.abc import Sequence

revision: str = "9f1e2d3c4b5a"
down_revision: str | None = ("6d79ca027510", "j0k1l2m3n4o5")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
