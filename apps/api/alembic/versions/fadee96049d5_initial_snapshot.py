"""initial_snapshot

기존 Prisma가 관리하던 DB 스키마를 Alembic 기준점으로 등록.
실제 DDL 변경 없음 — 이미 존재하는 테이블을 있는 그대로 인식.

Revision ID: fadee96049d5
Revises:
Create Date: 2026-03-11 15:44:31.237887
"""
from typing import Sequence, Union


revision: str = 'fadee96049d5'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 기존 DB 스키마를 그대로 사용 (Prisma → Alembic 전환 기준점)
    pass


def downgrade() -> None:
    # 초기 스냅샷이므로 downgrade 없음
    pass
