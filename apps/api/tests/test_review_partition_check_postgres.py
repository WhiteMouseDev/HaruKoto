"""Read-only inspector integration tests, exclusively disposable PostgreSQL."""

import asyncio
import json
import re
import subprocess
import sys
import uuid
from datetime import UTC, datetime
from pathlib import Path

import pytest
from sqlalchemy import event, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import create_async_engine

from app.services import review_partition_check as check
from tests.test_empty_postgrest_schema_postgres import _protected_metadata
from tests.test_public_access_hardening_postgres import _alembic, _scalar, _sql
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url
from tests.test_review_event_partition_repair_postgres import repair_database as repair_database

AS_OF = datetime(2026, 10, 21, tzinfo=UTC)


@pytest.fixture
async def check_database(repair_database):
    engine, url = repair_database
    # These inspector regressions deliberately describe the original eleven
    # months, including detecting the missing February reserve. Later dated
    # additions have their own integration coverage and must not erase this gap.
    applied = await asyncio.to_thread(_alembic, url, "upgrade", "m3n4o5p6q7r8")
    assert applied.returncode == 0, applied.stderr
    return engine, url


@pytest.mark.asyncio
async def test_healthy_check_is_catalog_only_and_preserves_learning_and_security(check_database, monkeypatch) -> None:
    engine, url = check_database
    user_id, event_id = uuid.uuid4(), uuid.uuid4()
    async with engine.begin() as connection:
        await connection.execute(
            text("INSERT INTO public.users(id,email,updated_at) VALUES (:id,:email,now())"),
            {"id": user_id, "email": f"{user_id}@example.test"},
        )
        await connection.execute(
            text("""
            INSERT INTO public.review_events(id,user_id,item_type,direction,is_correct,response_ms,rating,
                                            state_before,state_after,reviewed_on,created_at)
            VALUES (:event,:user,'WORD','JP_KR',true,1000,3,'PROVISIONAL','LEARNING','2026-10-21','2026-10-21T00:00:00Z')
        """),
            {"event": event_id, "user": user_id},
        )
    # Fresh inspector connections begin in a non-UTC server default; the
    # collector must still obtain exact UTC bounds and verify its own settings.
    database_name = make_url(url).database
    await _sql(engine, f"ALTER DATABASE \"{database_name}\" SET timezone TO 'Asia/Seoul'")
    before_security = await _protected_metadata(engine)
    before_user = await _scalar(engine, f"SELECT row_to_json(u) FROM public.users u WHERE id='{user_id}'")
    before_event = await _scalar(engine, f"SELECT row_to_json(e) FROM public.review_events e WHERE id='{event_id}'")
    statements = []
    factory = check.create_async_engine

    def tracked_engine(*args, **kwargs):
        tracked = factory(*args, **kwargs)
        event.listen(tracked.sync_engine, "before_cursor_execute", lambda _c, _cursor, statement, *_args: statements.append(statement))
        return tracked

    monkeypatch.setattr(check, "create_async_engine", tracked_engine)
    first = await check.inspect_review_partitions(url, as_of=AS_OF)
    second = await check.inspect_review_partitions(url, as_of=AS_OF)
    assert first.status is check.Status.OK and first.to_dict() == second.to_dict()
    assert first.required_end == first.continuous_coverage_end == datetime(2027, 2, 1, tzinfo=UTC)
    assert first.to_dict()["dataApiPlatformSwitch"] == "not_verified"
    # Exercise the actual standalone CLI/asyncio.run path using only this
    # dedicated disposable URL, without inheriting application credentials.
    executable = Path(__file__).resolve().parents[1] / "scripts/check_review_event_partitions.py"
    cli = subprocess.run(
        [sys.executable, str(executable), "--as-of", AS_OF.isoformat()],
        env={"DATABASE_URL": url},
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )
    assert cli.returncode == 0 and cli.stderr == ""
    assert json.loads(cli.stdout) == first.to_dict()
    assert sum(statement == check.CATALOG_SQL for statement in statements) == 2
    assert all(not re.search(r"\b(?:FROM|JOIN)\s+(?:public|auth|storage)\.", statement, re.I) for statement in statements)
    assert all(statement.lstrip().split()[0].upper() in {"SET", "WITH"} for statement in statements)
    assert await _protected_metadata(engine) == before_security
    assert await _scalar(engine, f"SELECT row_to_json(u) FROM public.users u WHERE id='{user_id}'") == before_user
    assert await _scalar(engine, f"SELECT row_to_json(e) FROM public.review_events e WHERE id='{event_id}'") == before_event


@pytest.mark.asyncio
async def test_middle_gap_is_detected_even_with_later_future_partition(check_database) -> None:
    engine, url = check_database
    await _sql(engine, "ALTER TABLE public.review_events DETACH PARTITION public.review_events_2026_09")
    await _sql(engine, "DROP TABLE public.review_events_2026_09")  # Empty disposable synthetic fixture only.
    result = await check.inspect_review_partitions(url, as_of=AS_OF)
    assert result.status is check.Status.ERROR and result.exit_code == 2
    assert result.continuous_coverage_end == datetime(2026, 9, 1, tzinfo=UTC)
    assert result.missing_months == ("2026-09",)
    assert "HISTORICAL_MONTH_MISSING" in {finding.code for finding in result.findings}


@pytest.mark.asyncio
async def test_rolling_horizon_requires_february_on_november_first(check_database) -> None:
    _, url = check_database
    result = await check.inspect_review_partitions(url, as_of=datetime(2026, 11, 1, tzinfo=UTC))
    assert result.status is check.Status.ADVISORY and result.exit_code == 1
    assert result.required_end == datetime(2027, 3, 1, tzinfo=UTC)
    assert result.missing_months == ("2027-02",)
    assert result.continuous_coverage_end == datetime(2027, 2, 1, tzinfo=UTC)


@pytest.mark.asyncio
async def test_valid_extra_future_partitions_are_accepted(check_database) -> None:
    engine, url = check_database
    await _sql(
        engine,
        "CREATE TABLE public.review_events_2027_02 PARTITION OF public.review_events "
        "FOR VALUES FROM ('2027-02-01 00:00:00+00') TO ('2027-03-01 00:00:00+00')",
    )
    result = await check.inspect_review_partitions(url, as_of=AS_OF)
    assert result.status is check.Status.OK and result.exit_code == 0
    assert result.continuous_coverage_end == datetime(2027, 3, 1, tzinfo=UTC)


@pytest.mark.parametrize(
    "mutation",
    [
        "renamed",
        "detached",
        "wrong-bounds",
        "default-partition",
        "missing-index",
        "parent-rls",
        "child-rls",
        "table-grant",
        "column-grant",
        "inherited-grant",
        "public-grant",
        "policy",
        "ddl-guard",
        "guard-search-path",
        "guard-tags",
        "missing-placeholder",
        "placeholder-grant",
        "authenticator-override",
        "database-override",
        "missing-role",
    ],
)
@pytest.mark.asyncio
async def test_metadata_and_security_fail_closed(check_database, mutation: str) -> None:
    engine, url = check_database
    statements = {
        "renamed": ["ALTER TABLE public.review_events_2026_10 RENAME TO renamed_month"],
        "detached": ["ALTER TABLE public.review_events DETACH PARTITION public.review_events_2026_10"],
        "wrong-bounds": [
            "ALTER TABLE public.review_events DETACH PARTITION public.review_events_2026_10",
            "DROP TABLE public.review_events_2026_10",
            "CREATE TABLE public.review_events_2026_10 PARTITION OF public.review_events "
            "FOR VALUES FROM ('2026-10-02 00:00:00+00') TO ('2026-11-01 00:00:00+00')",
        ],
        "default-partition": ["CREATE TABLE public.review_events_2027_02 PARTITION OF public.review_events DEFAULT"],
        "missing-index": ["DROP INDEX public.idx_review_events_user_day"],
        "parent-rls": ["ALTER TABLE public.review_events DISABLE ROW LEVEL SECURITY"],
        "child-rls": ["ALTER TABLE public.review_events_2026_10 DISABLE ROW LEVEL SECURITY"],
        "table-grant": ["GRANT SELECT ON public.review_events TO authenticated"],
        "column-grant": ["GRANT SELECT(user_id) ON public.review_events_2026_10 TO anon"],
        "inherited-grant": [
            "CREATE ROLE inspector_test_inherited NOLOGIN",
            "GRANT SELECT ON public.review_events TO inspector_test_inherited",
            "GRANT inspector_test_inherited TO authenticated",
        ],
        "public-grant": ["GRANT SELECT ON public.review_events TO PUBLIC"],
        "policy": ["CREATE POLICY unexpected_client_policy ON public.review_events FOR SELECT TO authenticated USING (true)"],
        "ddl-guard": ["ALTER EVENT TRIGGER zz_harukoto_secure_public_ddl DISABLE"],
        "guard-search-path": ["ALTER FUNCTION public.harukoto_secure_public_ddl() RESET search_path"],
        "guard-tags": [
            "DROP EVENT TRIGGER zz_harukoto_secure_public_ddl",
            "CREATE EVENT TRIGGER zz_harukoto_secure_public_ddl ON ddl_command_end WHEN TAG IN ('CREATE VIEW') "
            "EXECUTE FUNCTION public.harukoto_secure_public_ddl()",
        ],
        "missing-placeholder": ["DROP SCHEMA pgrst_no_exposed_schemas"],
        "placeholder-grant": ["GRANT USAGE ON SCHEMA pgrst_no_exposed_schemas TO authenticator"],
        "authenticator-override": ["ALTER ROLE authenticator SET pgrst.db_schemas='public'"],
        "database-override": [f"ALTER ROLE authenticator IN DATABASE \"{make_url(url).database}\" SET pgrst.db_schemas='public'"],
        "missing-role": ["ALTER ROLE authenticated RENAME TO inspector_missing_authenticated"],
    }
    for statement in statements[mutation]:
        await _sql(engine, statement)
    result = await check.inspect_review_partitions(url, as_of=AS_OF)
    expected = check.Status.UNKNOWN if mutation in {"missing-placeholder", "missing-role"} else check.Status.ERROR
    assert result.status is expected and result.exit_code != 0
    assert result.findings and result.to_dict()["dataApiPlatformSwitch"] == "not_verified"


@pytest.mark.asyncio
async def test_minimal_catalog_role_cannot_read_learning_rows_or_execute_ddl(check_database) -> None:
    engine, url = check_database
    role = "partition_observer"
    await _sql(engine, f"CREATE ROLE {role} LOGIN NOSUPERUSER NOBYPASSRLS")
    observer_url = make_url(url).set(username=role, password=None).render_as_string(hide_password=False)
    result = await check.inspect_review_partitions(observer_url, as_of=AS_OF)
    assert result.status is check.Status.OK and result.exit_code == 0
    observer = create_async_engine(observer_url)
    try:
        for query in [
            "SELECT * FROM public.users LIMIT 0",
            "SELECT * FROM public.review_events LIMIT 0",
            "CREATE TABLE public.forbidden_inspector_table(id integer)",
            "ALTER TABLE public.review_events DISABLE ROW LEVEL SECURITY",
        ]:
            with pytest.raises(DBAPIError) as error:
                async with observer.begin() as connection:
                    await connection.execute(text(query))
            assert error.value.orig.sqlstate == "42501"
        async with observer.connect() as connection:
            assert (
                await connection.scalar(text("SELECT has_schema_privilege(current_user,'pgrst_no_exposed_schemas','USAGE,CREATE')"))
                is False
            )
    finally:
        await observer.dispose()


@pytest.mark.asyncio
async def test_read_only_repeatable_snapshot_rejects_writes(check_database) -> None:
    engine, _ = check_database
    async with engine.connect() as connection:
        transaction = await connection.begin()
        await check.configure_read_only_transaction(connection)
        first = await check.read_catalog_snapshot(connection)
        assert first.read_only is True and first.isolation == "repeatable read" and first.timezone == "UTC"
        query = "SELECT count(*) FROM pg_catalog.pg_class WHERE relname='readonly_snapshot_sentinel'"
        assert await connection.scalar(text(query)) == 0
        await _sql(engine, "CREATE TABLE public.readonly_snapshot_sentinel(id integer)")
        assert await connection.scalar(text(query)) == 0  # Same transaction snapshot, not a fresh catalog view.
        assert await check.read_catalog_snapshot(connection) == first
        with pytest.raises(DBAPIError) as denied:
            await connection.execute(text("CREATE TABLE public.readonly_forbidden(id integer)"))
        assert denied.value.orig.sqlstate == "25006"
        await transaction.rollback()
    assert await _scalar(engine, query) == 1
    assert await _scalar(engine, "SELECT to_regclass('public.readonly_forbidden')") is None


@pytest.mark.asyncio
async def test_connection_errors_are_sanitized(check_database) -> None:
    _, url = check_database
    secret = "private_error_database_secret"
    missing = make_url(url).set(database=secret).render_as_string(hide_password=False)
    result = await check.inspect_review_partitions(missing, as_of=AS_OF)
    assert result.status is check.Status.UNKNOWN and result.exit_code == 3
    output = json.dumps(result.to_dict())
    assert secret not in output and missing not in output
