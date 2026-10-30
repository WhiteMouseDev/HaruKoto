"""February reserve migration against real disposable PostgreSQL databases only."""

import asyncio
import importlib.util
import shutil
import subprocess
import uuid
from datetime import UTC, datetime
from pathlib import Path

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from app.models import QuizAnswer, UserVocabProgress, Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech, QuizType
from app.models.user import User
from app.schemas.quiz import QuizAnswerRequest, QuizCompleteRequest, QuizResumeRequest, SmartStartRequest
from app.services.quiz_answer import submit_quiz_answer
from app.services.quiz_complete import complete_quiz_session
from app.services.quiz_session_query import get_incomplete_quiz_session, resume_quiz_session
from app.services.quiz_start import start_smart_quiz_session
from app.services.review_partition_check import Status, inspect_review_partitions
from tests.test_empty_postgrest_schema_postgres import ROLE_SETTING
from tests.test_public_access_hardening_postgres import _alembic, _denied, _scalar, _sql
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url
from tests.test_review_event_partition_repair_postgres import EVENT_INSERT, _partition_count
from tests.test_review_event_partition_repair_postgres import repair_database as repair_database

REVISION = "n4o5p6q7r8s9"
PREVIOUS = "m3n4o5p6q7r8"
MIGRATION_PATH = Path(__file__).resolve().parents[1] / "alembic/versions/n4o5p6q7r8s9_add_february_2027_review_partition.py"
TARGET = "public.review_events_2027_02"


@pytest.fixture
async def february_database(repair_database):
    engine, url = repair_database
    baseline = await asyncio.to_thread(_alembic, url, "upgrade", PREVIOUS)
    assert baseline.returncode == 0, baseline.stderr
    assert await _partition_count(engine) == 11
    return engine, url


async def _existing_object_ids(engine: AsyncEngine) -> list[int]:
    return await _scalar(
        engine,
        "SELECT array_agg(c.oid ORDER BY c.oid) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
        "WHERE n.nspname IN ('public','auth')",
    )


async def _existing_metadata(engine: AsyncEngine, object_ids: list[int]):
    # Compare all pre-existing relation identities, ACLs, RLS, column/default
    # declarations, constraints and index attachments. Newly added child/index
    # OIDs are deliberately excluded; no old object is allowed to be rewritten.
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL TIME ZONE 'UTC'"))
        return await connection.scalar(
            text("""
            SELECT jsonb_build_object(
                'relations', (SELECT jsonb_agg(jsonb_build_array(c.oid,c.relname,c.relkind,c.relowner,c.relacl,c.reloptions,
                    c.relrowsecurity,c.relforcerowsecurity,pg_get_expr(c.relpartbound,c.oid)) ORDER BY c.oid)
                    FROM pg_class c WHERE c.oid=ANY(CAST(:ids AS oid[]))),
                'columns', (SELECT jsonb_agg(jsonb_build_array(a.attrelid,a.attnum,a.attname,a.atttypid,a.atttypmod,
                    a.attnotnull,a.attacl,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attrelid,a.attnum)
                    FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
                    WHERE a.attrelid=ANY(CAST(:ids AS oid[])) AND a.attnum>0 AND NOT a.attisdropped),
                'indexes', (SELECT jsonb_agg(jsonb_build_array(i.indexrelid,pg_get_indexdef(i.indexrelid),
                    i.indisvalid,i.indisready,i.indisprimary,i.indisunique,
                    (SELECT jsonb_agg(ii.inhparent ORDER BY ii.inhparent) FROM pg_inherits ii WHERE ii.inhrelid=i.indexrelid))
                    ORDER BY i.indexrelid) FROM pg_index i WHERE i.indexrelid=ANY(CAST(:ids AS oid[]))),
                'constraints', (SELECT jsonb_agg(jsonb_build_array(c.oid,c.conrelid,c.conparentid,
                    pg_get_constraintdef(c.oid)) ORDER BY c.oid) FROM pg_constraint c
                    WHERE c.conrelid=ANY(CAST(:ids AS oid[]))),
                'policies', (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.oid) FROM pg_policy p
                    WHERE p.polrelid=ANY(CAST(:ids AS oid[]))),
                'defaults', (SELECT jsonb_agg(to_jsonb(d) ORDER BY d.oid) FROM pg_default_acl d),
                'roles', (SELECT jsonb_agg(jsonb_build_array(r.oid,r.rolname,r.rolsuper,r.rolinherit,r.rolcreaterole,
                    r.rolcreatedb,r.rolcanlogin,r.rolreplication,r.rolbypassrls,r.rolconfig) ORDER BY r.oid) FROM pg_roles r),
                'membership', (SELECT jsonb_agg(to_jsonb(m) ORDER BY m.roleid,m.member) FROM pg_auth_members m),
                'guard', (SELECT jsonb_agg(jsonb_build_array(e.evtname,e.evtenabled,e.evttags,
                    pg_get_functiondef(e.evtfoid)) ORDER BY e.oid) FROM pg_event_trigger e),
                'auth_trigger', (SELECT jsonb_agg(jsonb_build_array(t.oid,t.tgenabled,pg_get_triggerdef(t.oid)) ORDER BY t.oid)
                    FROM pg_trigger t WHERE NOT t.tgisinternal)
            )
            """),
            {"ids": object_ids},
        )


async def _rows(engine: AsyncEngine, table: str):
    assert table in {"users", "quiz_sessions", "quiz_answers", "user_vocab_progress", "review_events"}
    return await _scalar(engine, f"SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.{table} t")


async def _insert_event(engine: AsyncEngine, instant: datetime) -> uuid.UUID:
    event_id = uuid.uuid4()
    async with engine.begin() as connection:
        await connection.execute(
            text(EVENT_INSERT),
            {"id": event_id, "user_id": uuid.uuid4(), "reviewed_on": instant.date(), "created_at": instant},
        )
    return event_id


async def _apply_again(engine: AsyncEngine) -> None:
    spec = importlib.util.spec_from_file_location("add_february_review_partition", MIGRATION_PATH)
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    def apply(connection):
        migration.op = Operations(MigrationContext.configure(connection))
        migration.upgrade()

    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL search_path = public, pg_catalog"))
        await connection.run_sync(apply)
        assert await connection.scalar(text("SHOW search_path")) == "public, pg_catalog"
        assert await connection.scalar(text("SHOW timezone")) == "UTC"


@pytest.mark.asyncio
@pytest.mark.parametrize("timezone", ["UTC", "Asia/Seoul", "America/Los_Angeles"], ids=["utc", "korea", "los-angeles"])
async def test_february_preserves_existing_rows_security_and_routes_exact_utc_boundaries(february_database, timezone: str) -> None:
    engine, url = february_database
    await _insert_event(engine, datetime(2026, 3, 1, tzinfo=UTC))
    await _insert_event(engine, datetime(2027, 1, 31, 23, 59, 59, tzinfo=UTC))
    original_ids = await _existing_object_ids(engine)
    metadata = await _existing_metadata(engine, original_ids)
    rows = await _rows(engine, "review_events")
    setting = await _scalar(engine, ROLE_SETTING)
    database_name = make_url(url).database
    await _sql(engine, f"ALTER DATABASE \"{database_name}\" SET timezone TO '{timezone}'")
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode == 0, applied.stderr
    assert await _partition_count(engine) == 12
    assert await _existing_metadata(engine, original_ids) == metadata
    assert await _rows(engine, "review_events") == rows
    assert await _scalar(engine, ROLE_SETTING) == setting == "pgrst.db_schemas=pgrst_no_exposed_schemas"

    for timestamp, child in [
        ("2027-01-31T23:59:59.999999+00:00", "review_events_2027_01"),
        ("2027-02-01T00:00:00+00:00", "review_events_2027_02"),
        ("2027-02-01T09:00:00+09:00", "review_events_2027_02"),
        ("2027-02-28T23:59:59.999999+00:00", "review_events_2027_02"),
    ]:
        event_id = await _insert_event(engine, datetime.fromisoformat(timestamp))
        assert await _scalar(engine, f"SELECT tableoid::regclass::text FROM public.review_events WHERE id='{event_id}'") == child
    # 2027 is not a leap year: no March instant belongs to the February child.
    with pytest.raises(DBAPIError, match="no partition"):
        await _insert_event(engine, datetime(2027, 3, 1, tzinfo=UTC))
    for role in ["anon", "authenticated"]:
        await _denied(engine, role, f"SELECT * FROM {TARGET} LIMIT 0")
        await _denied(engine, role, f"UPDATE {TARGET} SET response_ms=0 WHERE false")
        assert await _scalar(engine, f"SELECT has_any_column_privilege('{role}','{TARGET}','SELECT,INSERT,UPDATE,REFERENCES')") is False
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL ROLE service_role"))
        assert await connection.scalar(text(f"SELECT count(*) FROM {TARGET}")) == 3
    result = await inspect_review_partitions(url, as_of=datetime(2026, 11, 1, tzinfo=UTC))
    assert result.status is Status.OK and result.exit_code == 0 and not result.missing_months
    assert result.required_end == result.continuous_coverage_end == datetime(2027, 3, 1, tzinfo=UTC)


@pytest.mark.asyncio
async def test_february_preserves_auth_saved_answers_and_partial_quiz_resume(february_database) -> None:
    engine, url = february_database
    # Keep synthetic event timestamps within the old coverage before migration;
    # UTC routing of February events is covered separately above.
    await _sql(engine, "ALTER TABLE public.review_events ALTER COLUMN created_at SET DEFAULT '2027-01-20T00:00:00Z'::timestamptz")
    user_id = uuid.uuid4()
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL ROLE supabase_auth_admin"))
        await connection.execute(
            text("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES (:id,:email,'{}')"),
            {"id": user_id, "email": f"{user_id}@example.test"},
        )
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    async with sessions() as db:
        user = await db.get(User, user_id)
        assert user is not None
        for index in range(4):
            db.add(
                Vocabulary(
                    id=uuid.uuid4(),
                    jlpt_level=JlptLevel.N5,
                    word=f"言葉{uuid.uuid4()}",
                    reading="ことば",
                    meaning_ko=f"2월 회귀 {index}",
                    part_of_speech=PartOfSpeech.NOUN,
                )
            )
        await db.commit()
        started = await start_smart_quiz_session(db, user, SmartStartRequest(category="VOCABULARY", jlpt_level=JlptLevel.N5, count=2))
        first, second = started.questions
        quiz_id = started.session.id
        await submit_quiz_answer(
            db,
            user,
            QuizAnswerRequest(
                session_id=quiz_id,
                question_id=uuid.UUID(first["id"]),
                selected_option_id=first["correctOptionId"],
                question_type=QuizType.VOCABULARY,
            ),
        )
    row_tables = ["users", "quiz_sessions", "quiz_answers", "user_vocab_progress", "review_events"]
    rows_before = {table: await _rows(engine, table) for table in row_tables}
    original_ids = await _existing_object_ids(engine)
    metadata = await _existing_metadata(engine, original_ids)
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode == 0, applied.stderr
    assert {table: await _rows(engine, table) for table in row_tables} == rows_before
    assert await _existing_metadata(engine, original_ids) == metadata

    # A new DB session represents a process restart; restore the exact original
    # question and answer IDs, then complete without replaying the first answer.
    async with sessions() as db:
        user = await db.get(User, user_id)
        assert user is not None
        incomplete = await get_incomplete_quiz_session(db, user)
        assert incomplete is not None and incomplete.id == str(quiz_id) and incomplete.answered_count == 1
        resumed = await resume_quiz_session(db, user, QuizResumeRequest(session_id=quiz_id))
        assert resumed.answered_question_ids == [first["id"]]
        assert [question.question_id for question in resumed.questions] == [first["id"], second["id"]]
        await submit_quiz_answer(
            db,
            user,
            QuizAnswerRequest(
                session_id=quiz_id,
                question_id=uuid.UUID(second["id"]),
                selected_option_id=second["correctOptionId"],
                question_type=QuizType.VOCABULARY,
            ),
        )
        result = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=quiz_id))
        assert (result.correct_count, result.total_questions, result.accuracy, result.xp_earned) == (2, 2, 100.0, 20)
        assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == quiz_id)) == 2
        assert await db.scalar(select(func.count()).select_from(UserVocabProgress).where(UserVocabProgress.user_id == user_id)) == 2
    # Existing Auth SECURITY DEFINER trigger still works after the migration.
    second_user = uuid.uuid4()
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL ROLE supabase_auth_admin"))
        await connection.execute(
            text("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES (:id,:email,'{}')"),
            {"id": second_user, "email": f"{second_user}@example.test"},
        )
    assert await _scalar(engine, f"SELECT id FROM public.users WHERE id='{second_user}'") == second_user


@pytest.mark.asyncio
async def test_february_accepts_exact_existing_target_and_concurrent_reapplication(february_database) -> None:
    engine, url = february_database
    await _sql(
        engine,
        f"CREATE TABLE {TARGET} PARTITION OF public.review_events FOR VALUES FROM ('2027-02-01 00:00:00+00') TO ('2027-03-01 00:00:00+00')",
    )
    await _insert_event(engine, datetime(2027, 2, 20, tzinfo=UTC))
    original_ids = await _existing_object_ids(engine)
    metadata = await _existing_metadata(engine, original_ids)
    rows = await _rows(engine, "review_events")
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode == 0, applied.stderr
    await asyncio.wait_for(asyncio.gather(_apply_again(engine), _apply_again(engine)), timeout=10)
    assert await _partition_count(engine) == 12
    assert await _existing_metadata(engine, original_ids) == metadata
    assert await _rows(engine, "review_events") == rows
    assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == REVISION


@pytest.mark.asyncio
async def test_february_lock_timeout_rolls_back_and_allows_bounded_retry(february_database) -> None:
    engine, url = february_database
    original_ids = await _existing_object_ids(engine)
    metadata = await _existing_metadata(engine, original_ids)
    async with engine.connect() as blocker:
        transaction = await blocker.begin()
        await blocker.execute(text("LOCK TABLE ONLY public.review_events IN ACCESS SHARE MODE"))
        applied = await asyncio.wait_for(asyncio.to_thread(_alembic, url, "upgrade", REVISION), timeout=8)
        assert applied.returncode != 0 and "lock timeout" in applied.stderr
        assert await _partition_count(engine) == 11
        assert await _scalar(engine, f"SELECT to_regclass('{TARGET}')") is None
        assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == PREVIOUS
        assert await _existing_metadata(engine, original_ids) == metadata
        await transaction.rollback()
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode == 0, applied.stderr
    assert await _partition_count(engine) == 12


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "mutation",
    [
        "table-name",
        "view-name",
        "wrong-bounds",
        "unexpected-child",
        "default-partition",
        "wrong-owner",
        "parent-rls",
        "old-child-rls",
        "ddl-guard",
        "guard-search-path",
        "guard-tags",
        "missing-index",
        "column-privilege",
        "old-column-privilege",
        "public-privilege",
        "historical-gap",
        "target-rls",
        "target-privilege",
        "target-column-privilege",
        "target-owner",
    ],
)
async def test_february_rejects_conflicting_catalog_or_security_without_repairing_old_objects(february_database, mutation: str) -> None:
    engine, url = february_database
    exact = (
        f"CREATE TABLE {TARGET} PARTITION OF public.review_events FOR VALUES FROM ('2027-02-01 00:00:00+00') TO ('2027-03-01 00:00:00+00')"
    )
    mutations = {
        "table-name": [f"CREATE TABLE {TARGET}(id integer)"],
        "view-name": [f"CREATE VIEW {TARGET} AS SELECT 1 AS id"],
        "wrong-bounds": [
            f"CREATE TABLE {TARGET} PARTITION OF public.review_events "
            "FOR VALUES FROM ('2027-02-02 00:00:00+00') TO ('2027-03-01 00:00:00+00')"
        ],
        "unexpected-child": [
            "CREATE TABLE public.unexpected_february PARTITION OF public.review_events "
            "FOR VALUES FROM ('2027-02-01 00:00:00+00') TO ('2027-03-01 00:00:00+00')"
        ],
        "default-partition": [f"CREATE TABLE {TARGET} PARTITION OF public.review_events DEFAULT"],
        "wrong-owner": ["ALTER TABLE public.review_events OWNER TO wrong_owner"],
        "parent-rls": ["ALTER TABLE public.review_events DISABLE ROW LEVEL SECURITY"],
        "old-child-rls": ["ALTER TABLE public.review_events_2027_01 DISABLE ROW LEVEL SECURITY"],
        "ddl-guard": ["ALTER EVENT TRIGGER zz_harukoto_secure_public_ddl DISABLE"],
        "guard-search-path": ["ALTER FUNCTION public.harukoto_secure_public_ddl() RESET search_path"],
        "guard-tags": [
            "DROP EVENT TRIGGER zz_harukoto_secure_public_ddl",
            "CREATE EVENT TRIGGER zz_harukoto_secure_public_ddl ON ddl_command_end WHEN TAG IN ('CREATE VIEW') "
            "EXECUTE FUNCTION public.harukoto_secure_public_ddl()",
        ],
        "missing-index": ["DROP INDEX public.idx_review_events_user_day"],
        "column-privilege": ["GRANT SELECT(user_id) ON public.review_events TO authenticated"],
        "old-column-privilege": ["GRANT SELECT(user_id) ON public.review_events_2027_01 TO anon"],
        "public-privilege": ["GRANT SELECT ON public.review_events TO PUBLIC"],
        "historical-gap": ["ALTER TABLE public.review_events DETACH PARTITION public.review_events_2026_03"],
        "target-rls": [exact, f"ALTER TABLE {TARGET} DISABLE ROW LEVEL SECURITY"],
        "target-privilege": [exact, f"GRANT SELECT ON {TARGET} TO authenticated"],
        "target-column-privilege": [exact, f"GRANT SELECT(user_id) ON {TARGET} TO anon"],
        "target-owner": [exact, f"ALTER TABLE {TARGET} OWNER TO wrong_owner"],
    }
    for statement in mutations[mutation]:
        await _sql(engine, statement)
    original_ids = await _existing_object_ids(engine)
    metadata = await _existing_metadata(engine, original_ids)
    count = await _partition_count(engine)
    target_oid = await _scalar(engine, f"SELECT to_regclass('{TARGET}')::oid")
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode != 0
    assert await _partition_count(engine) == count
    assert await _scalar(engine, f"SELECT to_regclass('{TARGET}')::oid") == target_oid
    assert await _existing_metadata(engine, original_ids) == metadata
    assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == PREVIOUS


@pytest.mark.asyncio
async def test_february_offline_sql_is_atomic_and_downgrade_never_drops_data(february_database) -> None:
    engine, url = february_database
    rendered = await asyncio.to_thread(_alembic, url, "upgrade", f"{PREVIOUS}:{REVISION}", "--sql")
    assert rendered.returncode == 0, rendered.stderr
    assert rendered.stdout.startswith("BEGIN;") and rendered.stdout.rstrip().endswith("COMMIT;")
    psql = shutil.which("psql")
    assert psql is not None
    replay = await asyncio.to_thread(
        subprocess.run,
        [psql, url.replace("postgresql+asyncpg:", "postgresql:"), "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--file=-"],
        input=rendered.stdout,
        capture_output=True,
        text=True,
        check=False,
    )
    assert replay.returncode == 0, replay.stderr
    assert "UPDATE 1" in replay.stdout
    assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == REVISION
    assert await _partition_count(engine) == 12
    await _insert_event(engine, datetime(2027, 2, 28, 12, tzinfo=UTC))
    original_ids = await _existing_object_ids(engine)
    metadata = await _existing_metadata(engine, original_ids)
    rows = await _rows(engine, "review_events")
    downgraded = await asyncio.to_thread(_alembic, url, "downgrade", "-1")
    assert downgraded.returncode != 0 and "intentionally blocked" in downgraded.stderr
    assert await _partition_count(engine) == 12
    assert await _existing_metadata(engine, original_ids) == metadata
    assert await _rows(engine, "review_events") == rows
    assert await _scalar(engine, "SELECT version_num FROM public.alembic_version") == REVISION
