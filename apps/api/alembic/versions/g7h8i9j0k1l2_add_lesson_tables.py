"""add chapters, lessons, lesson_item_links, user_lesson_progress tables
and review_events partitioned table for SRS event logging.

Based on 04-DATA-SCHEMA.md design document.

Revision ID: g7h8i9j0k1l2
Revises: f6g7h8i9j0k1
Create Date: 2026-03-20 18:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "g7h8i9j0k1l2"
down_revision: str | None = "f6g7h8i9j0k1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # ── 1. chapters ──
    op.create_table(
        "chapters",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("jlpt_level", sa.Text(), nullable=False),
        sa.Column("part_no", sa.SmallInteger(), nullable=False),
        sa.Column("chapter_no", sa.SmallInteger(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("topic", sa.Text(), nullable=True),
        sa.Column("order_no", sa.SmallInteger(), nullable=False, server_default="0"),
        sa.Column("is_published", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("jlpt_level", "part_no", "chapter_no"),
    )

    # ── 2. lessons ──
    op.create_table(
        "lessons",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("chapter_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("chapters.id"), nullable=False),
        sa.Column("jlpt_level", sa.Text(), nullable=False),
        sa.Column("lesson_no", sa.Integer(), nullable=False),
        sa.Column("chapter_lesson_no", sa.SmallInteger(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("topic", sa.Text(), nullable=False),
        sa.Column("estimated_minutes", sa.SmallInteger(), nullable=False, server_default="10"),
        sa.Column("content_jsonb", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("is_published", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("chapter_id", "chapter_lesson_no"),
        sa.UniqueConstraint("jlpt_level", "lesson_no"),
    )
    op.create_index("idx_lessons_chapter", "lessons", ["chapter_id", "chapter_lesson_no"])

    # ── 3. lesson_item_links ──
    op.create_table(
        "lesson_item_links",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("lesson_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lessons.id", ondelete="CASCADE"), nullable=False),
        sa.Column("item_type", sa.Text(), nullable=False),
        sa.Column("vocabulary_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("vocabularies.id"), nullable=True),
        sa.Column("grammar_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("grammars.id"), nullable=True),
        sa.Column("item_order", sa.SmallInteger(), nullable=False),
        sa.Column("is_core", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("lesson_id", "item_type", "vocabulary_id", "grammar_id"),
        sa.CheckConstraint(
            "(item_type = 'WORD' AND vocabulary_id IS NOT NULL AND grammar_id IS NULL) OR "
            "(item_type = 'GRAMMAR' AND grammar_id IS NOT NULL AND vocabulary_id IS NULL)",
            name="ck_lesson_item_links_type",
        ),
    )
    op.create_index("idx_lesson_item_links_lesson", "lesson_item_links", ["lesson_id", "item_order"])
    op.create_index("idx_lesson_item_links_vocab", "lesson_item_links", ["vocabulary_id"])
    op.create_index("idx_lesson_item_links_grammar", "lesson_item_links", ["grammar_id"])

    # ── 4. user_lesson_progress ──
    op.create_table(
        "user_lesson_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lesson_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("lessons.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.Text(), nullable=False, server_default="NOT_STARTED"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("score_correct", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("score_total", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("srs_registered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "lesson_id"),
    )
    op.create_index("idx_user_lesson_progress_user", "user_lesson_progress", ["user_id", "status"])

    # ── 5. review_events (월별 파티션 테이블) ──
    # Alembic의 op.create_table는 PARTITION BY를 지원하지 않으므로 raw SQL 사용
    op.execute("""
        CREATE TABLE review_events (
            id UUID NOT NULL DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL,
            item_type TEXT NOT NULL,
            vocabulary_id UUID,
            grammar_id UUID,
            session_id UUID,
            lesson_id UUID,
            direction TEXT NOT NULL,
            is_correct BOOLEAN NOT NULL,
            response_ms INTEGER NOT NULL,
            rating SMALLINT NOT NULL,
            state_before TEXT NOT NULL,
            state_after TEXT NOT NULL,
            distractor_difficulty TEXT,
            is_provisional_phase BOOLEAN NOT NULL DEFAULT FALSE,
            is_new_card BOOLEAN NOT NULL DEFAULT FALSE,
            reviewed_on DATE NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (id, created_at)
        ) PARTITION BY RANGE (created_at)
    """)

    # 2026년 3~6월 파티션 미리 생성
    for month in range(3, 7):
        next_month = month + 1 if month < 12 else 1
        next_year = 2026 if month < 12 else 2027
        op.execute(f"""
            CREATE TABLE review_events_2026_{month:02d}
            PARTITION OF review_events
            FOR VALUES FROM ('2026-{month:02d}-01') TO ('{next_year}-{next_month:02d}-01')
        """)

    op.create_index("idx_review_events_user", "review_events", ["user_id", sa.text("created_at DESC")])
    op.execute("""
        CREATE INDEX idx_review_events_user_day
        ON review_events (user_id, reviewed_on)
        WHERE is_new_card = TRUE
    """)

    # ── 6. 챕터 진도 뷰 ──
    op.execute("""
        CREATE OR REPLACE VIEW user_chapter_progress_v AS
        SELECT
            ulp.user_id,
            l.chapter_id,
            COUNT(*) FILTER (WHERE ulp.status = 'COMPLETED') as completed_lessons,
            COUNT(*) as total_lessons,
            BOOL_AND(ulp.status = 'COMPLETED') as all_completed
        FROM user_lesson_progress ulp
        JOIN lessons l ON l.id = ulp.lesson_id
        GROUP BY ulp.user_id, l.chapter_id
    """)


def downgrade() -> None:
    op.execute("DROP VIEW IF EXISTS user_chapter_progress_v")
    op.execute("DROP INDEX IF EXISTS idx_review_events_user_day")
    op.execute("DROP INDEX IF EXISTS idx_review_events_user")
    for month in range(3, 7):
        op.execute(f"DROP TABLE IF EXISTS review_events_2026_{month:02d}")
    op.execute("DROP TABLE IF EXISTS review_events")
    op.drop_index("idx_user_lesson_progress_user", table_name="user_lesson_progress")
    op.drop_table("user_lesson_progress")
    op.drop_index("idx_lesson_item_links_grammar", table_name="lesson_item_links")
    op.drop_index("idx_lesson_item_links_vocab", table_name="lesson_item_links")
    op.drop_index("idx_lesson_item_links_lesson", table_name="lesson_item_links")
    op.drop_table("lesson_item_links")
    op.drop_index("idx_lessons_chapter", table_name="lessons")
    op.drop_table("lessons")
    op.drop_table("chapters")
