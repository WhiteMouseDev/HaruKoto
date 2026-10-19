"""Verify the disabled Data API workaround against a disposable PostgreSQL."""

import importlib.util
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
from tests.test_public_access_hardening_postgres import _alembic, _denied, _scalar, _sql
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url

REVISION = "l2m3n4o5p6q7"
MIGRATION_PATH = Path(__file__).resolve().parents[1] / "alembic/versions/l2m3n4o5p6q7_use_empty_postgrest_schema.py"
ROLE_SETTING = """
    SELECT setting FROM pg_roles r, LATERAL unnest(r.rolconfig) setting
    WHERE r.rolname='authenticator' AND setting LIKE 'pgrst.db_schemas=%'
"""


async def _apply_again(engine: AsyncEngine) -> None:
    spec = importlib.util.spec_from_file_location("empty_postgrest_schema", MIGRATION_PATH)
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    def upgrade(connection):
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

    async with engine.begin() as connection:
        await connection.run_sync(upgrade)


async def _protected_metadata(engine: AsyncEngine):
    return await _scalar(
        engine,
        """
        SELECT jsonb_build_object(
            'relations', (SELECT jsonb_agg(jsonb_build_array(n.nspname,c.relname,c.relowner,c.relacl,c.reloptions,
                               c.relrowsecurity,c.relforcerowsecurity) ORDER BY n.nspname,c.relname)
                          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                          WHERE n.nspname IN ('public','auth','storage')),
            'defaults', (SELECT jsonb_agg(to_jsonb(d) ORDER BY d.oid) FROM pg_default_acl d),
            'roles', (SELECT jsonb_agg(jsonb_build_array(rolname,rolbypassrls,rolconfig) ORDER BY rolname)
                      FROM pg_roles WHERE rolname IN ('postgres','anon','authenticated','service_role','supabase_auth_admin')),
            'guard', (SELECT evtenabled FROM pg_event_trigger WHERE evtname='zz_harukoto_secure_public_ddl'),
            'auth_trigger', (SELECT tgenabled FROM pg_trigger WHERE tgname='on_auth_user_created' AND NOT tgisinternal)
        )
        """,
    )


@pytest.mark.asyncio
async def test_empty_postgrest_schema_is_fail_closed_and_preserves_auth_and_learning(isolated_postgres_url: str) -> None:
    engine = create_async_engine(isolated_postgres_url)
    try:
        for statement in [
            "CREATE ROLE anon NOLOGIN",
            "CREATE ROLE authenticated NOLOGIN",
            "CREATE ROLE service_role NOLOGIN BYPASSRLS",
            "CREATE ROLE supabase_auth_admin NOLOGIN",
            "CREATE ROLE schema_guest NOLOGIN",
            "CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin",
            "CREATE TABLE auth.users (id UUID PRIMARY KEY, email TEXT, raw_user_meta_data JSONB DEFAULT '{}')",
            "ALTER TABLE auth.users OWNER TO supabase_auth_admin",
            "CREATE SCHEMA storage",
            "CREATE TABLE storage.security_sentinel (id INTEGER)",
            "GRANT SELECT ON storage.security_sentinel TO authenticated",
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role",
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON TABLES TO authenticated",
        ]:
            await _sql(engine, statement)
        baseline = _alembic(isolated_postgres_url, "upgrade", "k1l2m3n4o5p6")
        assert baseline.returncode == 0, baseline.stderr
        metadata_before = await _protected_metadata(engine)

        # Vanilla PostgreSQL needs no fabricated platform role. The migration
        # can still run, downgrade safely, and later run in a Supabase fixture.
        applied = _alembic(isolated_postgres_url, "upgrade", REVISION)
        assert applied.returncode == 0, applied.stderr
        assert await _scalar(engine, "SELECT count(*) FROM pg_roles WHERE rolname='authenticator'") == 0
        downgraded = _alembic(isolated_postgres_url, "downgrade", "-1")
        assert downgraded.returncode == 0, downgraded.stderr
        await _sql(engine, "CREATE ROLE authenticator NOLOGIN NOINHERIT")
        await _sql(engine, "CREATE SCHEMA pgrst_no_exposed_schemas AUTHORIZATION postgres")

        # Refuse a pre-existing schema containing any object, including a type
        # or callable function. Never expose it or delete its contents.
        for create, drop in [
            ("CREATE TABLE pgrst_no_exposed_schemas.sentinel (id integer)", "DROP TABLE pgrst_no_exposed_schemas.sentinel"),
            (
                "CREATE FUNCTION pgrst_no_exposed_schemas.sentinel() RETURNS integer LANGUAGE sql AS 'SELECT 1'",
                "DROP FUNCTION pgrst_no_exposed_schemas.sentinel()",
            ),
            ("CREATE TYPE pgrst_no_exposed_schemas.sentinel AS ENUM ('test')", "DROP TYPE pgrst_no_exposed_schemas.sentinel"),
        ]:
            await _sql(engine, create)
            with pytest.raises(DBAPIError, match="placeholder schema is not empty"):
                await _apply_again(engine)
            assert await _scalar(engine, ROLE_SETTING) is None
            await _sql(engine, drop)
        await _sql(engine, "ALTER SCHEMA pgrst_no_exposed_schemas OWNER TO schema_guest")
        with pytest.raises(DBAPIError, match="must be owned by postgres"):
            await _apply_again(engine)
        await _sql(engine, "ALTER SCHEMA pgrst_no_exposed_schemas OWNER TO postgres")
        await _sql(engine, "GRANT ALL ON SCHEMA pgrst_no_exposed_schemas TO PUBLIC,anon,authenticated,authenticator,schema_guest")

        applied = _alembic(isolated_postgres_url, "upgrade", REVISION)
        assert applied.returncode == 0, applied.stderr
        await _apply_again(engine)
        assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == REVISION
        assert await _scalar(engine, ROLE_SETTING) == "pgrst.db_schemas=pgrst_no_exposed_schemas"
        assert (
            await _scalar(engine, "SELECT pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname='pgrst_no_exposed_schemas'")
            == "postgres"
        )
        assert (
            await _scalar(
                engine,
                "SELECT count(*) FROM pg_depend WHERE refclassid='pg_namespace'::regclass "
                "AND refobjid='pgrst_no_exposed_schemas'::regnamespace",
            )
            == 0
        )
        for role in ["anon", "authenticated", "authenticator", "schema_guest"]:
            assert await _scalar(engine, f"SELECT has_schema_privilege('{role}','pgrst_no_exposed_schemas','USAGE,CREATE')") is False
            await _denied(engine, role, "CREATE TABLE pgrst_no_exposed_schemas.forbidden (id integer)")
        # Even accidentally created owner objects remain inaccessible; remove
        # this synthetic object immediately to restore the empty-schema invariant.
        await _sql(engine, "CREATE FUNCTION pgrst_no_exposed_schemas.sentinel() RETURNS integer LANGUAGE sql AS 'SELECT 1'")
        await _denied(engine, "anon", "SELECT pgrst_no_exposed_schemas.sentinel()")
        await _denied(engine, "authenticated", "SELECT pgrst_no_exposed_schemas.sentinel()")
        blocked_downgrade = _alembic(isolated_postgres_url, "downgrade", "-1")
        assert blocked_downgrade.returncode != 0
        assert "placeholder schema is not empty" in blocked_downgrade.stderr
        assert await _scalar(engine, ROLE_SETTING) == "pgrst.db_schemas=pgrst_no_exposed_schemas"
        await _sql(engine, "DROP FUNCTION pgrst_no_exposed_schemas.sentinel()")
        assert await _protected_metadata(engine) == metadata_before

        # Auth's trigger and the trusted server connection still create a user
        # and complete a real home quiz with no client grants or RLS policies.
        auth_user_id = uuid.uuid4()
        async with engine.begin() as connection:
            await connection.execute(text("SET LOCAL ROLE supabase_auth_admin"))
            await connection.execute(
                text("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES (:id,:email,:metadata)"),
                {"id": auth_user_id, "email": f"{auth_user_id}@example.test", "metadata": '{"name":"빈 스키마 테스트"}'},
            )
        async with engine.begin() as connection:
            await connection.execute(text("SET LOCAL ROLE service_role"))
            assert await connection.scalar(text("SELECT count(*) FROM public.users")) == 1
        sessions = async_sessionmaker(engine, expire_on_commit=False)
        async with sessions() as db:
            for index in range(4):
                db.add(
                    Vocabulary(
                        jlpt_level=JlptLevel.N5,
                        word=f"単語{uuid.uuid4()}",
                        reading="たんご",
                        meaning_ko=f"빈 스키마 {index}",
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
        for role in ["anon", "authenticated"]:
            await _denied(engine, role, "SELECT email FROM public.users LIMIT 0")

        # Round-trip rollback explicitly selects the reserved disabled sentinel.
        # It never RESETs to a possibly public default or restores old ACLs.
        downgraded = _alembic(isolated_postgres_url, "downgrade", "-1")
        assert downgraded.returncode == 0, downgraded.stderr
        assert await _scalar(engine, ROLE_SETTING) == "pgrst.db_schemas=pg_pgrst_no_exposed_schemas"
        assert await _scalar(engine, "SELECT to_regnamespace('pgrst_no_exposed_schemas')") is None
        assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == "k1l2m3n4o5p6"
        reapplied = _alembic(isolated_postgres_url, "upgrade", REVISION)
        assert reapplied.returncode == 0, reapplied.stderr
        assert await _scalar(engine, ROLE_SETTING) == "pgrst.db_schemas=pgrst_no_exposed_schemas"
        assert await _protected_metadata(engine) == metadata_before
    finally:
        await engine.dispose()
