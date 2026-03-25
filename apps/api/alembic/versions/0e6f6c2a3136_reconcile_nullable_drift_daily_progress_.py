"""reconcile schema drift — nullable columns, unique constraints, defaults

Reconciliation migration: 프로덕션 DB에 이미 적용된 변경을
Alembic 히스토리에 기록합니다.

변경 내용:
1. daily_progress 3개 컬럼 nullable 전환
2. study_stages 2개 컬럼 nullable 전환
3. user_study_stage_progress 5개 컬럼 nullable 전환
4. 4개 테이블에 unique constraint 추가 (IF NOT EXISTS)

Revision ID: 0e6f6c2a3136
Revises: h8i9j0k1l2m3
Create Date: 2026-03-25 09:20:39.783232
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0e6f6c2a3136"
down_revision: str | None = "h8i9j0k1l2m3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # -- 1. daily_progress: 신규 컬럼 nullable 전환 --
    op.alter_column(
        "daily_progress",
        "grammar_studied",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.alter_column(
        "daily_progress",
        "sentences_studied",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.alter_column(
        "daily_progress",
        "study_minutes",
        existing_type=sa.Integer(),
        nullable=True,
    )

    # -- 2. study_stages: order, created_at nullable 전환 --
    op.alter_column(
        "study_stages",
        "order",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.alter_column(
        "study_stages",
        "created_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=True,
    )
    # study_stages.content_ids: server_default를 '[]'로 설정 (Prisma 기대값)
    op.alter_column(
        "study_stages",
        "content_ids",
        existing_type=sa.JSON(),
        server_default=sa.text("'[]'::json"),
    )

    # -- 3. user_study_stage_progress: 다수 컬럼 nullable 전환 --
    op.alter_column(
        "user_study_stage_progress",
        "best_score",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.alter_column(
        "user_study_stage_progress",
        "attempts",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.alter_column(
        "user_study_stage_progress",
        "completed",
        existing_type=sa.Boolean(),
        nullable=True,
    )
    op.alter_column(
        "user_study_stage_progress",
        "created_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=True,
    )
    op.alter_column(
        "user_study_stage_progress",
        "updated_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=True,
    )

    # -- 4. Unique constraints (프로덕션에 이미 존재, Alembic 히스토리에 누락) --
    # IF NOT EXISTS는 PostgreSQL에서 직접 지원하므로 raw SQL 사용
    op.execute(
        """
        DO $$ BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE tablename = 'vocabularies'
                AND indexname = 'vocabularies_word_reading_jlpt_level_key'
            ) THEN
                CREATE UNIQUE INDEX vocabularies_word_reading_jlpt_level_key
                ON vocabularies (word, reading, jlpt_level);
            END IF;
        END $$;
        """
    )
    op.execute(
        """
        DO $$ BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE tablename = 'grammars'
                AND indexname = 'grammars_pattern_jlpt_level_key'
            ) THEN
                CREATE UNIQUE INDEX grammars_pattern_jlpt_level_key
                ON grammars (pattern, jlpt_level);
            END IF;
        END $$;
        """
    )
    op.execute(
        """
        DO $$ BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE tablename = 'sentence_arrange_questions'
                AND indexname = 'sentence_arrange_questions_korean_sentence_jlpt_level_key'
            ) THEN
                CREATE UNIQUE INDEX sentence_arrange_questions_korean_sentence_jlpt_level_key
                ON sentence_arrange_questions (korean_sentence, jlpt_level);
            END IF;
        END $$;
        """
    )
    op.execute(
        """
        DO $$ BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE tablename = 'conversation_scenarios'
                AND indexname = 'conversation_scenarios_title_key'
            ) THEN
                CREATE UNIQUE INDEX conversation_scenarios_title_key
                ON conversation_scenarios (title);
            END IF;
        END $$;
        """
    )

    op.execute(
        """
        DO $$ BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE tablename = 'cloze_questions'
                AND indexname = 'cloze_questions_sentence_jlpt_level_key'
            ) THEN
                CREATE UNIQUE INDEX cloze_questions_sentence_jlpt_level_key
                ON cloze_questions (sentence, jlpt_level);
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    # -- Unique constraints --
    op.execute("DROP INDEX IF EXISTS cloze_questions_sentence_jlpt_level_key")
    op.execute("DROP INDEX IF EXISTS conversation_scenarios_title_key")
    op.execute("DROP INDEX IF EXISTS sentence_arrange_questions_korean_sentence_jlpt_level_key")
    op.execute("DROP INDEX IF EXISTS grammars_pattern_jlpt_level_key")
    op.execute("DROP INDEX IF EXISTS vocabularies_word_reading_jlpt_level_key")

    # -- user_study_stage_progress --
    op.alter_column(
        "user_study_stage_progress",
        "updated_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
    )
    op.alter_column(
        "user_study_stage_progress",
        "created_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
    )
    op.alter_column(
        "user_study_stage_progress",
        "completed",
        existing_type=sa.Boolean(),
        nullable=False,
    )
    op.alter_column(
        "user_study_stage_progress",
        "attempts",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.alter_column(
        "user_study_stage_progress",
        "best_score",
        existing_type=sa.Integer(),
        nullable=False,
    )

    # -- study_stages --
    op.alter_column(
        "study_stages",
        "created_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
    )
    op.alter_column(
        "study_stages",
        "order",
        existing_type=sa.Integer(),
        nullable=False,
    )

    # -- daily_progress --
    op.alter_column(
        "daily_progress",
        "study_minutes",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.alter_column(
        "daily_progress",
        "sentences_studied",
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.alter_column(
        "daily_progress",
        "grammar_studied",
        existing_type=sa.Integer(),
        nullable=False,
    )
