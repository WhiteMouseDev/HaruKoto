"""add auth.users → public.users trigger

Supabase Auth에 유저가 생성되면 public.users에 자동으로 row를 생성하는 트리거.
기존에 웹(Prisma), 모바일(API sync)에서 각각 처리하던 유저 생성 로직을 DB 레벨로 통합.

Revision ID: a1b2c3d4e5f6
Revises: fadee96049d5
Create Date: 2026-03-12 18:00:00.000000
"""
from collections.abc import Sequence

from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: str | None = "fadee96049d5"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        CREATE OR REPLACE FUNCTION public.handle_new_user()
        RETURNS trigger
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = public
        AS $$
        BEGIN
            INSERT INTO public.users (id, email, nickname, avatar_url, created_at, updated_at)
            VALUES (
                NEW.id,
                COALESCE(NEW.email, ''),
                COALESCE(
                    NEW.raw_user_meta_data ->> 'full_name',
                    NEW.raw_user_meta_data ->> 'name',
                    ''
                ),
                NEW.raw_user_meta_data ->> 'avatar_url',
                NOW(),
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                email = EXCLUDED.email,
                updated_at = NOW();
            RETURN NEW;
        END;
        $$;
    """)

    # Only create trigger if auth schema exists (Supabase environment)
    # CI/test environments without auth schema will skip this safely
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth') THEN
                CREATE TRIGGER on_auth_user_created
                    AFTER INSERT ON auth.users
                    FOR EACH ROW
                    EXECUTE FUNCTION public.handle_new_user();
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth') THEN
                DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
            END IF;
        END $$;
    """)
    op.execute("DROP FUNCTION IF EXISTS public.handle_new_user();")
