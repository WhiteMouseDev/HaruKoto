"""add goals column and ABSOLUTE_ZERO level

Revision ID: f6g7h8i9j0k1
Revises: e5f6g7h8i9j0
Create Date: 2026-03-20 14:00:00.000000
"""

import sqlalchemy as sa
from alembic import op

revision = "f6g7h8i9j0k1"
down_revision = "e5f6g7h8i9j0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. JlptLevel enum에 ABSOLUTE_ZERO 추가
    op.execute("ALTER TYPE \"JlptLevel\" ADD VALUE IF NOT EXISTS 'ABSOLUTE_ZERO' BEFORE 'N5'")

    # 2. goals 컬럼 추가 (text 배열)
    op.add_column("users", sa.Column("goals", sa.ARRAY(sa.Text()), nullable=True))

    # 3. UserGoal enum에 새 값 추가
    op.execute("ALTER TYPE \"UserGoal\" ADD VALUE IF NOT EXISTS 'CONTENT'")
    op.execute("ALTER TYPE \"UserGoal\" ADD VALUE IF NOT EXISTS 'JLPT'")
    op.execute("ALTER TYPE \"UserGoal\" ADD VALUE IF NOT EXISTS 'WORK'")
    op.execute("ALTER TYPE \"UserGoal\" ADD VALUE IF NOT EXISTS 'STUDY_ABROAD'")
    op.execute("ALTER TYPE \"UserGoal\" ADD VALUE IF NOT EXISTS 'LIVING'")


def downgrade() -> None:
    op.drop_column("users", "goals")
    # enum 값 제거는 PostgreSQL에서 직접 불가 — 마이그레이션 참고용
