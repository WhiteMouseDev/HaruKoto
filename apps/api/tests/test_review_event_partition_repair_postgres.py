"""Data-preserving partition repair against a real disposable PostgreSQL only."""

import asyncio
import importlib.util
import shutil
import subprocess
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from pathlib import Path

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from app.models import QuizAnswer, QuizSession, UserVocabProgress, Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech, QuizType
from app.models.lesson import Chapter, Lesson, LessonItemLink, UserLessonProgress
from app.models.user import User
from app.schemas.lesson import AnswerSubmission
from app.schemas.quiz import QuizAnswerRequest, QuizCompleteRequest, QuizResumeRequest, SmartStartRequest
from app.services.lesson_command import submit_lesson_attempt
from app.services.quiz_answer import submit_quiz_answer
from app.services.quiz_complete import complete_quiz_session
from app.services.quiz_session_query import get_incomplete_quiz_session, resume_quiz_session
from app.services.quiz_start import start_smart_quiz_session
from tests.test_empty_postgrest_schema_postgres import ROLE_SETTING
from tests.test_public_access_hardening_postgres import _alembic, _denied, _scalar, _sql
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url

REVISION = "m3n4o5p6q7r8"
PREVIOUS = "l2m3n4o5p6q7"
MIGRATION_PATH = Path(__file__).resolve().parents[1] / "alembic/versions/m3n4o5p6q7r8_repair_review_event_partitions.py"
EVENT_INSERT = """
    INSERT INTO public.review_events
      (id,user_id,item_type,direction,is_correct,response_ms,rating,state_before,state_after,reviewed_on,created_at)
    VALUES (:id,:user_id,'WORD','JP_KR',true,1000,3,'PROVISIONAL','LEARNING',:reviewed_on,:created_at)
"""


@pytest.fixture
async def repair_database(isolated_postgres_url: str) -> AsyncIterator[tuple[AsyncEngine, str]]:
    # One fresh database per case; roles are cluster-scoped and created once.
    name = f"partition_repair_{uuid.uuid4().hex}"
    admin = create_async_engine(isolated_postgres_url, isolation_level="AUTOCOMMIT")
    async with admin.connect() as connection:
        for role, attributes in [
            ("anon", "NOLOGIN"),
            ("authenticated", "NOLOGIN"),
            ("service_role", "NOLOGIN BYPASSRLS"),
            ("supabase_auth_admin", "NOLOGIN"),
            ("authenticator", "NOLOGIN NOINHERIT"),
            ("wrong_owner", "NOLOGIN"),
        ]:
            exists = await connection.scalar(text("SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=:role)"), {"role": role})
            if not exists:
                await connection.execute(text(f'CREATE ROLE "{role}" {attributes}'))
        await connection.execute(text(f'CREATE DATABASE "{name}"'))
        await connection.execute(text(f"ALTER DATABASE \"{name}\" SET timezone TO 'UTC'"))
    url = make_url(isolated_postgres_url).set(database=name).render_as_string(hide_password=False)
    engine = create_async_engine(url)
    try:
        for statement in [
            "CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin",
            "CREATE TABLE auth.users(id UUID PRIMARY KEY,email TEXT,raw_user_meta_data JSONB DEFAULT '{}')",
            "ALTER TABLE auth.users OWNER TO supabase_auth_admin",
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role",
        ]:
            await _sql(engine, statement)
        baseline = await asyncio.to_thread(_alembic, url, "upgrade", PREVIOUS)
        assert baseline.returncode == 0, baseline.stderr
        yield engine, url
    finally:
        await engine.dispose()
        async with admin.connect() as connection:
            await connection.execute(text(f'DROP DATABASE "{name}" WITH (FORCE)'))
        await admin.dispose()


async def _apply_again(engine: AsyncEngine) -> None:
    spec = importlib.util.spec_from_file_location("review_event_partition_repair", MIGRATION_PATH)
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    def apply(connection):
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL TIME ZONE 'Asia/Seoul'"))
        await connection.execute(text("SET LOCAL search_path = public, pg_catalog"))
        await connection.run_sync(apply)
        assert await connection.scalar(text("SHOW search_path")) == "public, pg_catalog"
        assert await connection.scalar(text("SHOW timezone")) == "UTC"


async def _old_metadata(engine: AsyncEngine):
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL TIME ZONE 'UTC'"))
        return await connection.scalar(
            text("""
            SELECT jsonb_agg(jsonb_build_array(c.oid,c.relname,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity,
                     pg_get_expr(c.relpartbound,c.oid)) ORDER BY c.oid)
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname='public' AND (c.relname='review_events' OR c.relname ~ '^review_events_2026_0[3-6]$')
        """)
        )


async def _partition_count(engine: AsyncEngine) -> int:
    return await _scalar(engine, "SELECT count(*) FROM pg_inherits WHERE inhparent='public.review_events'::regclass")


@pytest.mark.asyncio
async def test_repair_preserves_records_security_boundaries_and_repeat_application(repair_database) -> None:
    engine, url = repair_database
    historical_id, user_id = uuid.uuid4(), uuid.uuid4()
    async with engine.begin() as connection:
        await connection.execute(
            text(EVENT_INSERT),
            {
                "id": historical_id,
                "user_id": user_id,
                "reviewed_on": datetime(2026, 6, 30).date(),
                "created_at": datetime(2026, 6, 30, 23, 59, 59, tzinfo=UTC),
            },
        )
    metadata_before = await _old_metadata(engine)
    setting_before = await _scalar(engine, ROLE_SETTING)
    # The subprocess opens a fresh non-UTC connection. The migration itself
    # must normalize UTC rather than relying on the original database default.
    database_name = make_url(url).database
    await _sql(engine, f"ALTER DATABASE \"{database_name}\" SET timezone TO 'America/Los_Angeles'")
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode == 0, applied.stderr
    assert await _partition_count(engine) == 11
    assert await _old_metadata(engine) == metadata_before
    assert await _scalar(engine, ROLE_SETTING) == setting_before == "pgrst.db_schemas=pgrst_no_exposed_schemas"
    assert await _scalar(engine, f"SELECT id FROM public.review_events WHERE id='{historical_id}'") == historical_id

    # Use a non-UTC server session and absolute instants on both sides of the
    # July gap, each month boundary, and December/January year rollover.
    for timestamp, expected_partition in [
        ("2026-06-30T23:59:59.999999+00:00", "review_events_2026_06"),
        *[(f"2026-{month:02d}-01T00:00:00+00:00", f"review_events_2026_{month:02d}") for month in range(7, 13)],
        ("2026-12-31T23:59:59.999999+00:00", "review_events_2026_12"),
        ("2027-01-01T09:00:00+09:00", "review_events_2027_01"),
        ("2027-01-31T23:59:59.999999+00:00", "review_events_2027_01"),
    ]:
        event_id = uuid.uuid4()
        instant = datetime.fromisoformat(timestamp)
        async with engine.begin() as connection:
            await connection.execute(text("SET LOCAL TIME ZONE 'America/Los_Angeles'"))
            await connection.execute(
                text(EVENT_INSERT),
                {
                    "id": event_id,
                    "user_id": user_id,
                    "reviewed_on": instant.date(),
                    "created_at": instant,
                },
            )
            child = await connection.scalar(
                text("SELECT tableoid::regclass::text FROM public.review_events WHERE id=:id"), {"id": event_id}
            )
            assert child == expected_partition
    for timestamp in ["2026-02-28T23:59:59+00:00", "2027-02-01T00:00:00+00:00"]:
        instant = datetime.fromisoformat(timestamp)
        with pytest.raises(DBAPIError, match="no partition"):
            async with engine.begin() as connection:
                await connection.execute(
                    text(EVENT_INSERT),
                    {
                        "id": uuid.uuid4(),
                        "user_id": user_id,
                        "reviewed_on": instant.date(),
                        "created_at": instant,
                    },
                )

    for role in ["anon", "authenticated"]:
        for name in ["review_events", *[f"review_events_2026_{month:02d}" for month in range(3, 13)], "review_events_2027_01"]:
            await _denied(engine, role, f"SELECT * FROM public.{name} LIMIT 0")
            await _denied(engine, role, f"UPDATE public.{name} SET response_ms=0 WHERE false")
            assert (
                await _scalar(engine, f"SELECT has_any_column_privilege('{role}','public.{name}','SELECT,INSERT,UPDATE,REFERENCES')")
                is False
            )
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL ROLE service_role"))
        assert await connection.scalar(text("SELECT count(*) FROM public.review_events")) == 11
    await asyncio.gather(_apply_again(engine), _apply_again(engine))
    assert await _partition_count(engine) == 11
    assert await _old_metadata(engine) == metadata_before
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == REVISION
    downgraded = await asyncio.to_thread(_alembic, url, "downgrade", "-1")
    assert downgraded.returncode != 0
    assert "intentionally blocked" in downgraded.stderr
    assert await _partition_count(engine) == 11
    assert await _scalar(engine, "SELECT count(*) FROM public.review_events") == 11
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == REVISION


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "conflict",
    [
        "CREATE TABLE public.review_events_2026_10(id integer)",
        "CREATE VIEW public.review_events_2026_10 AS SELECT 1 AS id",
        "CREATE TABLE public.review_events_2026_10 PARTITION OF public.review_events "
        "FOR VALUES FROM ('2026-09-01+00') TO ('2026-10-01+00')",
        "CREATE TABLE public.unexpected_october PARTITION OF public.review_events FOR VALUES FROM ('2026-10-01+00') TO ('2026-11-01+00')",
        "CREATE TABLE public.review_events_default PARTITION OF public.review_events DEFAULT",
        "ALTER TABLE public.review_events OWNER TO wrong_owner",
        "ALTER TABLE public.review_events DISABLE ROW LEVEL SECURITY",
        "ALTER EVENT TRIGGER zz_harukoto_secure_public_ddl DISABLE",
        "DROP INDEX public.idx_review_events_user_day",
        "GRANT SELECT(user_id) ON public.review_events TO authenticated",
    ],
    ids=[
        "table-name",
        "view-name",
        "wrong-bounds",
        "unexpected-child",
        "default-partition",
        "wrong-owner",
        "parent-rls",
        "ddl-guard",
        "missing-index",
        "column-privilege",
    ],
)
async def test_repair_fails_atomically_on_conflicting_catalog_or_security(repair_database, conflict: str) -> None:
    engine, url = repair_database
    await _sql(engine, conflict)
    count_before = await _partition_count(engine)
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode != 0
    assert await _partition_count(engine) == count_before
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == PREVIOUS
    assert await _scalar(engine, "SELECT to_regclass('public.review_events_2026_07')") is None


@pytest.mark.asyncio
async def test_repair_lock_timeout_rolls_back_and_allows_bounded_retry(repair_database) -> None:
    engine, url = repair_database
    async with engine.connect() as blocker:
        transaction = await blocker.begin()
        await blocker.execute(text("LOCK TABLE ONLY public.review_events IN ACCESS SHARE MODE"))
        result = await asyncio.wait_for(asyncio.to_thread(_alembic, url, "upgrade", REVISION), timeout=8)
        assert result.returncode != 0
        assert "lock timeout" in result.stderr
        assert await _partition_count(engine) == 4
        assert await _scalar(engine, "SELECT version_num FROM alembic_version") == PREVIOUS
        await transaction.rollback()
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode == 0, applied.stderr
    assert await _partition_count(engine) == 11


@pytest.mark.asyncio
async def test_repair_preserves_auth_quiz_resume_and_atomic_lesson_srs_events(repair_database) -> None:
    engine, url = repair_database
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode == 0, applied.stderr
    # Pin only synthetic event routing, so this test remains meaningful after
    # this dated migration's coverage expires. Production defaults are untouched.
    await _sql(engine, "ALTER TABLE public.review_events ALTER COLUMN created_at SET DEFAULT '2026-10-19T01:00:00Z'::timestamptz")
    user_id = uuid.uuid4()
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL ROLE supabase_auth_admin"))
        await connection.execute(
            text("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES (:id,:email,'{}')"),
            {"id": user_id, "email": f"{user_id}@example.test"},
        )
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    vocabulary_ids = [uuid.uuid4() for _ in range(4)]
    async with sessions() as db:
        user = await db.get(User, user_id)
        assert user is not None  # Existing Auth SECURITY DEFINER trigger works.
        for index, item_id in enumerate(vocabulary_ids):
            db.add(
                Vocabulary(
                    id=item_id,
                    jlpt_level=JlptLevel.N5,
                    word=f"単語{item_id}",
                    reading="たんご",
                    meaning_ko=f"보완 검증 {index}",
                    part_of_speech=PartOfSpeech.NOUN,
                )
            )
        await db.commit()
        quiz = await start_smart_quiz_session(db, user, SmartStartRequest(category="VOCABULARY", jlpt_level=JlptLevel.N5, count=2))
        quiz_id = quiz.session.id
        assert len(quiz.questions) == 2
        first, second = quiz.questions
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
    # A fresh session simulates process restart/reconnect; persisted quiz answer
    # and optional SAVEPOINT event must both survive before resuming next item.
    async with sessions() as db:
        user = await db.get(User, user_id)
        assert user is not None
        incomplete = await get_incomplete_quiz_session(db, user)
        assert incomplete is not None and incomplete.id == str(quiz_id) and incomplete.answered_count == 1
        resumed = await resume_quiz_session(db, user, QuizResumeRequest(session_id=quiz_id))
        assert resumed.answered_question_ids == [first["id"]]
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
        assert await get_incomplete_quiz_session(db, user) is None
        assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == quiz_id)) == 2
        assert await db.scalar(text("SELECT count(*) FROM review_events WHERE session_id=:id"), {"id": quiz_id}) == 2
        assert await db.scalar(select(func.count()).select_from(UserVocabProgress).where(UserVocabProgress.user_id == user_id)) == 2
        saved = await db.get(QuizSession, quiz_id)
        assert saved is not None and saved.completed_at is not None

        chapter = Chapter(id=uuid.uuid4(), jlpt_level="N5", part_no=1, chapter_no=1, title="합성 파티션 검증")
        db.add(chapter)
        await db.flush()
        lesson_id = uuid.uuid4()
        db.add(
            Lesson(
                id=lesson_id,
                chapter_id=chapter.id,
                jlpt_level=JlptLevel.N5,
                lesson_no=1,
                chapter_lesson_no=1,
                title="레슨 저장 검증",
                topic="검증",
                is_published=True,
                content_jsonb={
                    "questions": [{"order": 1, "type": "VOCAB_MCQ", "correct_answer": "correct", "vocabulary_id": str(vocabulary_ids[-1])}]
                },
            )
        )
        await db.flush()
        db.add(LessonItemLink(lesson_id=lesson_id, item_type="WORD", vocabulary_id=vocabulary_ids[-1], item_order=1))
        await db.commit()
        lesson_result = await submit_lesson_attempt(
            db, user, lesson_id=lesson_id, answers=[AnswerSubmission(order=1, selected_answer="correct", response_ms=1000)]
        )
        assert (lesson_result.score_correct, lesson_result.score_total, lesson_result.status) == (1, 1, "COMPLETED")
    async with sessions() as db:
        lesson_progress = await db.scalar(
            select(UserLessonProgress).where(UserLessonProgress.user_id == user_id, UserLessonProgress.lesson_id == lesson_id)
        )
        assert lesson_progress is not None and lesson_progress.status == "COMPLETED" and lesson_progress.score_correct == 1
        assert await db.scalar(text("SELECT count(*) FROM review_events_2026_10 WHERE lesson_id=:id"), {"id": lesson_id}) == 1
        assert (
            await db.scalar(
                select(func.count())
                .select_from(UserVocabProgress)
                .where(UserVocabProgress.user_id == user_id, UserVocabProgress.vocabulary_id == vocabulary_ids[-1])
            )
            == 1
        )


@pytest.mark.asyncio
async def test_repair_accepts_only_an_exact_existing_target_partition(repair_database) -> None:
    engine, url = repair_database
    await _sql(
        engine,
        "CREATE TABLE public.review_events_2026_07 PARTITION OF public.review_events "
        "FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00')",
    )
    existing_oid = await _scalar(engine, "SELECT 'public.review_events_2026_07'::regclass::oid")
    applied = await asyncio.to_thread(_alembic, url, "upgrade", REVISION)
    assert applied.returncode == 0, applied.stderr
    assert await _partition_count(engine) == 11
    assert await _scalar(engine, "SELECT 'public.review_events_2026_07'::regclass::oid") == existing_oid


@pytest.mark.asyncio
async def test_reviewed_offline_sql_replays_as_one_transaction(repair_database) -> None:
    engine, url = repair_database
    rendered = await asyncio.to_thread(_alembic, url, "upgrade", f"{PREVIOUS}:{REVISION}", "--sql")
    assert rendered.returncode == 0, rendered.stderr
    assert rendered.stdout.startswith("BEGIN;")
    assert rendered.stdout.rstrip().endswith("COMMIT;")
    psql = shutil.which("psql")
    assert psql is not None
    result = await asyncio.to_thread(
        subprocess.run,
        [psql, url.replace("postgresql+asyncpg:", "postgresql:"), "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--file=-"],
        input=rendered.stdout,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    assert "UPDATE 1" in result.stdout
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == REVISION
    assert await _partition_count(engine) == 11
