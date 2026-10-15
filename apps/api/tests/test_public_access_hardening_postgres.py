"""Exercise real ACL/RLS behavior in a disposable local PostgreSQL only."""

import importlib.util
import os
import subprocess
import sys
import uuid
from pathlib import Path

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from app.models import Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech, QuizType
from app.models.user import User
from app.schemas.quiz import QuizAnswerRequest, QuizCompleteRequest, SmartStartRequest
from app.services.quiz_answer import submit_quiz_answer
from app.services.quiz_complete import complete_quiz_session
from app.services.quiz_start import start_smart_quiz_session
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url

API_ROOT = Path(__file__).resolve().parents[1]
MIGRATION_PATH = API_ROOT / "alembic/versions/k1l2m3n4o5p6_harden_public_data_access.py"


def _alembic(url: str, *arguments: str) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ)
    environment.update(DATABASE_URL=url, SUPABASE_URL="https://test.supabase.co", SENTRY_DSN="", ENVIRONMENT="test")
    return subprocess.run(
        [sys.executable, "-m", "alembic", *arguments], cwd=API_ROOT, env=environment, capture_output=True, text=True, check=False
    )


async def _sql(engine: AsyncEngine, statement: str) -> None:
    async with engine.begin() as connection:
        await connection.execute(text(statement))


async def _scalar(engine: AsyncEngine, statement: str):
    async with engine.connect() as connection:
        return await connection.scalar(text(statement))


async def _denied(engine: AsyncEngine, role: str, statement: str) -> None:
    with pytest.raises(DBAPIError) as error:
        async with engine.begin() as connection:
            await connection.execute(text(f'SET LOCAL ROLE "{role}"'))
            await connection.execute(text(statement))
    assert error.value.orig.sqlstate == "42501"


async def _apply_again(engine: AsyncEngine) -> None:
    spec = importlib.util.spec_from_file_location("public_access_hardening", MIGRATION_PATH)
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    def upgrade(connection):
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

    async with engine.begin() as connection:
        await connection.run_sync(upgrade)


@pytest.mark.asyncio
async def test_public_boundary_migration_preserves_server_auth_and_learning_and_blocks_clients(isolated_postgres_url: str) -> None:
    engine = create_async_engine(isolated_postgres_url)
    try:
        for statement in [
            "CREATE ROLE anon NOLOGIN",
            "CREATE ROLE authenticated NOLOGIN",
            "CREATE ROLE service_role NOLOGIN BYPASSRLS",
            "CREATE ROLE supabase_auth_admin NOLOGIN",
            "CREATE ROLE managed_owner NOLOGIN",
            "CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin",
            "CREATE TABLE auth.users (id UUID PRIMARY KEY, email TEXT, raw_user_meta_data JSONB DEFAULT '{}')",
            "ALTER TABLE auth.users OWNER TO supabase_auth_admin",
            "CREATE SCHEMA storage",
            "CREATE TABLE storage.security_sentinel (id INTEGER)",
            "GRANT ALL ON storage.security_sentinel TO anon, authenticated",
            "CREATE TABLE public.managed_sentinel (id INTEGER)",
            "ALTER TABLE public.managed_sentinel OWNER TO managed_owner",
            "GRANT ALL ON public.managed_sentinel TO anon, authenticated",
            "CREATE EXTENSION hstore WITH SCHEMA public",
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role",
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role",
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role",
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON TABLES TO anon, authenticated",
        ]:
            await _sql(engine, statement)
        baseline = _alembic(isolated_postgres_url, "upgrade", "9f1e2d3c4b5a")
        assert baseline.returncode == 0, baseline.stderr
        await _sql(engine, "GRANT SELECT (email) ON public.users TO anon")
        await _sql(engine, "CREATE SEQUENCE public.security_sentinel_sequence")
        storage_defaults = await _scalar(
            engine,
            "SELECT defaclacl::text FROM pg_default_acl WHERE defaclrole = 'postgres'::regrole "
            "AND defaclnamespace = 'storage'::regnamespace AND defaclobjtype = 'r'",
        )
        assert await _scalar(engine, "SELECT has_table_privilege('anon', 'public.users', 'SELECT')") is True
        applied = _alembic(isolated_postgres_url, "upgrade", "k1l2m3n4o5p6")
        assert applied.returncode == 0, applied.stderr
        await _apply_again(engine)

        assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == "k1l2m3n4o5p6"
        assert (
            await _scalar(
                engine,
                "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
                "WHERE n.nspname='public' AND c.relkind IN ('r','p') AND c.relowner='postgres'::regrole "
                "AND (NOT c.relrowsecurity OR c.relforcerowsecurity)",
            )
            == 0
        )
        assert (
            await _scalar(
                engine,
                "SELECT reloptions @> ARRAY['security_invoker=true'] FROM pg_class WHERE oid='public.user_chapter_progress_v'::regclass",
            )
            is True
        )
        for role in ["anon", "authenticated"]:
            for query in [
                "SELECT email FROM public.users LIMIT 0",
                "INSERT INTO public.users (id, email, updated_at) VALUES (gen_random_uuid(), 'blocked@example.test', now())",
                "UPDATE public.users SET is_premium = true WHERE false",
                "DELETE FROM public.users WHERE false",
                "SELECT * FROM public.user_chapter_progress_v LIMIT 0",
                "SELECT * FROM public.review_events_2026_03 LIMIT 0",
                "SELECT nextval('public.security_sentinel_sequence')",
            ]:
                await _denied(engine, role, query)
            assert await _scalar(engine, f"SELECT has_function_privilege('{role}', 'public.handle_new_user()', 'EXECUTE')") is False
            assert await _scalar(engine, f"SELECT has_column_privilege('{role}', 'public.users', 'email', 'SELECT')") is False
        assert await _scalar(engine, "SELECT has_function_privilege('anon', 'public.harukoto_secure_public_ddl()', 'EXECUTE')") is False

        # Auth's SECURITY DEFINER trigger must continue to create a public user
        # even though the Auth role has no direct access to the application table.
        auth_user_id = uuid.uuid4()
        async with engine.begin() as connection:
            await connection.execute(text("SET LOCAL ROLE supabase_auth_admin"))
            await connection.execute(
                text("INSERT INTO auth.users (id,email,raw_user_meta_data) VALUES (:id, :email, :metadata)"),
                {"id": auth_user_id, "email": f"{auth_user_id}@example.test", "metadata": '{"name":"권한 테스트"}'},
            )
        assert await _scalar(engine, f"SELECT id FROM public.users WHERE id='{auth_user_id}'") == auth_user_id
        async with engine.begin() as connection:
            await connection.execute(text("SET LOCAL ROLE service_role"))
            assert await connection.scalar(text("SELECT count(*) FROM public.users")) == 1

        # RLS is also an independent deny layer if a table grant is later
        # introduced accidentally. Roll back this test-only grant afterward.
        async with engine.connect() as connection:
            transaction = await connection.begin()
            await connection.execute(text("GRANT SELECT ON public.users TO authenticated"))
            await connection.execute(text("SET LOCAL ROLE authenticated"))
            assert await connection.scalar(text("SELECT count(*) FROM public.users")) == 0
            await transaction.rollback()

        # The real home smart quiz still creates, saves and completes using the
        # server connection, without opening client write access or RLS policies.
        sessions = async_sessionmaker(engine, expire_on_commit=False)
        async with sessions() as db:
            for index in range(4):
                db.add(
                    Vocabulary(
                        jlpt_level=JlptLevel.N5,
                        word=f"単語{uuid.uuid4()}",
                        reading="たんご",
                        meaning_ko=f"권한 테스트 {index}",
                        part_of_speech=PartOfSpeech.NOUN,
                    )
                )
            await db.commit()
            user = await db.get(User, auth_user_id)
            assert user is not None
            quiz = await start_smart_quiz_session(db, user, SmartStartRequest(category="VOCABULARY", jlpt_level=JlptLevel.N5, count=2))
            for question in quiz.questions:
                await submit_quiz_answer(
                    db,
                    user,
                    QuizAnswerRequest(
                        session_id=quiz.session.id,
                        question_id=uuid.UUID(question["id"]),
                        selected_option_id=question["correctOptionId"],
                        question_type=QuizType.VOCABULARY,
                    ),
                )
            result = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=quiz.session.id))
            assert (result.correct_count, result.total_questions, result.accuracy, result.xp_earned) == (2, 2, 100.0, 20)

        # Future public DDL is secured, including built-in PUBLIC function
        # EXECUTE which cannot be removed by schema-only default privileges.
        for statement in [
            "CREATE TABLE public.future_security_test (id INTEGER)",
            "CREATE TABLE public.future_security_test_as AS SELECT 1 AS id",
            "SELECT 1 AS id INTO public.future_security_select_into",
            "CREATE SEQUENCE public.future_security_sequence",
            "CREATE VIEW public.future_security_view AS SELECT id FROM public.future_security_test",
            "CREATE FUNCTION public.future_security_function() RETURNS integer LANGUAGE sql AS 'SELECT 1'",
            "CREATE TABLE public.review_events_2026_10 PARTITION OF public.review_events FOR VALUES FROM ('2026-10-01') TO ('2026-11-01')",
            "CREATE TABLE storage.future_security_sentinel (id INTEGER)",
            "CREATE EXTENSION pg_trgm WITH SCHEMA public",
        ]:
            await _sql(engine, statement)
        await _denied(engine, "anon", "SELECT public.future_security_function()")
        await _denied(engine, "authenticated", "SELECT public.future_security_function()")
        async with engine.begin() as connection:
            await connection.execute(text("GRANT CREATE ON SCHEMA public TO managed_owner"))
            await connection.execute(text("SET LOCAL ROLE managed_owner"))
            await connection.execute(text("CREATE TABLE public.future_managed_sentinel (id INTEGER)"))
            await connection.execute(text("GRANT SELECT ON public.future_managed_sentinel TO anon"))
        for name in ["future_security_test", "future_security_test_as", "future_security_select_into", "review_events_2026_10"]:
            assert await _scalar(engine, f"SELECT relrowsecurity FROM pg_class WHERE oid='public.{name}'::regclass") is True
            assert await _scalar(engine, f"SELECT has_table_privilege('anon', 'public.{name}', 'SELECT')") is False
        assert await _scalar(engine, "SELECT has_function_privilege('anon', 'public.future_security_function()', 'EXECUTE')") is False
        assert (
            await _scalar(engine, "SELECT has_function_privilege('authenticated', 'public.future_security_function()', 'EXECUTE')") is False
        )
        assert await _scalar(engine, "SELECT has_sequence_privilege('anon', 'public.future_security_sequence', 'USAGE')") is False
        assert await _scalar(engine, "SELECT has_table_privilege('anon', 'public.future_security_view', 'SELECT')") is False
        assert await _scalar(engine, "SELECT has_function_privilege('anon', 'public.hstore(text,text)', 'EXECUTE')") is True
        assert await _scalar(engine, "SELECT has_function_privilege('anon', 'public.similarity(text,text)', 'EXECUTE')") is True
        for name in [
            "storage.security_sentinel",
            "storage.future_security_sentinel",
            "public.managed_sentinel",
            "public.future_managed_sentinel",
        ]:
            assert await _scalar(engine, f"SELECT has_table_privilege('anon', '{name}', 'SELECT')") is True
            assert await _scalar(engine, f"SELECT relrowsecurity FROM pg_class WHERE oid='{name}'::regclass") is False
        assert (
            await _scalar(
                engine,
                "SELECT defaclacl::text FROM pg_default_acl WHERE defaclrole = 'postgres'::regrole "
                "AND defaclnamespace = 'storage'::regnamespace AND defaclobjtype = 'r'",
            )
            == storage_defaults
        )

        # Unsafe automatic rollback must neither reopen access nor move the
        # version marker; manual recovery requires the external ACL snapshot.
        downgraded = _alembic(isolated_postgres_url, "downgrade", "-1")
        assert downgraded.returncode != 0
        assert "Automatic downgrade would reopen public data access" in downgraded.stderr
        assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == "k1l2m3n4o5p6"
        await _denied(engine, "anon", "SELECT email FROM public.users LIMIT 0")
    finally:
        await engine.dispose()
