"""merge heads — review_status + audit_logs

Revision ID: 6d79ca027510
Revises: a1b2c3d4e5f7, i9j0k1l2m3n4
Create Date: 2026-03-27 10:56:56.201466
"""

from collections.abc import Sequence

revision: str = "6d79ca027510"
down_revision: str | None = ("a1b2c3d4e5f7", "i9j0k1l2m3n4")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
