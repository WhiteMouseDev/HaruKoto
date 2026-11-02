"""Real disposable PostgreSQL: study-day receipts, migration, races and rollback."""

import asyncio
import importlib.util
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
import pytest_asyncio
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import event, select, text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models import Conversation, DailyProgress, KanaLearningStage, QuizAnswer, QuizSession
from app.models.enums import ConversationType, JlptLevel, KanaType, QuizType
from app.models.lesson import LessonSubmission
from app.models.user import User
from app.schemas.kana import KanaQuizCompleteRequest, KanaStageCompleteRequest
from app.schemas.lesson import LessonSubmissionRequest, LessonSubmissionResponse
from app.schemas.quiz import QuizCompleteRequest
from app.services import (
    conversation_rewards,
    kana_quiz_complete,
    kana_stage_complete,
    lesson_submission,
    quiz_complete,
    quiz_session,
    stats_dashboard,
)
from app.services.gamification import update_streak
from app.services.lesson_command import LessonServiceError, start_lesson_progress, submit_lesson_attempt
from app.services.lesson_submission import submission_fingerprint, submit_lesson_once
from app.services.stats_dashboard import get_dashboard_data
from app.services.stats_history import get_history_data
from app.services.study_day_recording import canonical_study_instant, lock_study_user
from app.services.vocabulary_goal import get_vocabulary_goal
from app.utils.date import study_date_kst
from tests.test_lesson_submissions_postgres import _get, _legacy_hash, _metadata, _seed, _seed_legacy_history, _submit
from tests.test_public_access_hardening_postgres import _alembic, _denied, _scalar, _sql
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url

REVISION = "p6q7r8s9t0u1"
MIGRATION = Path(__file__).resolve().parents[1] / f"alembic/versions/{REVISION}_add_lesson_study_day_marker.py"
NOW = datetime(2026, 11, 2, 1, tzinfo=UTC)


@pytest.fixture(autouse=True)
def enable_recognition_for_feature_regressions(monkeypatch):
    # Both compatibility and activation commits execute every feature regression.
    monkeypatch.setattr(lesson_submission, "LESSON_STUDY_DAY_RECOGNITION_ENABLED", True)


def _freeze(monkeypatch, module, instant):
    class FrozenDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return instant.astimezone(tz) if tz is not None else instant.replace(tzinfo=None)

    monkeypatch.setattr(module, "datetime", FrozenDatetime)


async def _daily_rows(engine, user_id, *, old_columns=False):
    projection = "to_jsonb(d)-'lesson_completed'" if old_columns else "to_jsonb(d)"
    async with engine.connect() as connection:
        return await connection.scalar(
            text(f"SELECT COALESCE(jsonb_agg({projection} ORDER BY date),'[]') FROM daily_progress d WHERE user_id=:uid"),
            {"uid": user_id},
        )


async def _state(engine, user_id):
    async with engine.connect() as connection:
        return await connection.scalar(
            text("""SELECT jsonb_build_object(
                'user',(SELECT to_jsonb(u) FROM users u WHERE id=:uid),
                'daily',(SELECT jsonb_agg(to_jsonb(d) ORDER BY date) FROM daily_progress d WHERE user_id=:uid),
                'progress',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_lesson_progress p WHERE user_id=:uid),
                'words',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_vocab_progress p WHERE user_id=:uid),
                'grammar',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_grammar_progress p WHERE user_id=:uid),
                'receipts',(SELECT jsonb_agg(to_jsonb(r) ORDER BY submission_id) FROM lesson_submissions r WHERE user_id=:uid),
                'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM review_events e WHERE user_id=:uid))"""),
            {"uid": user_id},
        )


@pytest_asyncio.fixture(scope="module")
async def study_day_database(isolated_postgres_url):
    assert isolated_postgres_url.startswith("postgresql+asyncpg://postgres@/postgres?host=/tmp/hk-quiz-")
    engine = create_async_engine(isolated_postgres_url)
    try:
        for statement in [
            "ALTER DATABASE postgres SET timezone TO UTC",
            "CREATE ROLE anon NOLOGIN",
            "CREATE ROLE authenticated NOLOGIN",
            "CREATE ROLE service_role NOLOGIN BYPASSRLS",
            "CREATE ROLE supabase_auth_admin NOLOGIN",
            "CREATE ROLE authenticator NOLOGIN NOINHERIT",
            "CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin",
            "CREATE TABLE auth.users(id UUID PRIMARY KEY,email TEXT,raw_user_meta_data JSONB DEFAULT '{}')",
            "ALTER TABLE auth.users OWNER TO supabase_auth_admin",
        ]:
            await _sql(engine, statement)
        prior = _alembic(isolated_postgres_url, "upgrade", "o5p6q7r8s9t0")
        assert prior.returncode == 0, prior.stderr
        # Existing hardening intentionally keeps trusted service_role grants.
        # Exercise table, column-only and default grants rather than an empty role.
        for statement in [
            "GRANT SELECT,INSERT,UPDATE,DELETE ON public.daily_progress TO service_role",
            "GRANT REFERENCES (date) ON public.daily_progress TO service_role",
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO service_role",
        ]:
            await _sql(engine, statement)
        await _sql(engine, "ALTER TABLE review_events ALTER COLUMN created_at SET DEFAULT '2026-11-02T01:00:00Z'::timestamptz")
        historical = await _seed(engine)
        audio_id = await _seed_legacy_history(engine, historical)
        async with engine.begin() as connection:
            await connection.execute(
                text("""INSERT INTO daily_progress
                  (id,user_id,date,words_studied,quizzes_completed,correct_answers,total_answers,
                   conversation_count,study_time_seconds,xp_earned,kana_learned,grammar_studied,sentences_studied,study_minutes)
                  VALUES(:id,:uid,'2026-10-30',7,2,8,10,1,90,80,2,3,1,2)"""),
                {"id": uuid4(), "uid": historical.user_id},
            )
        response = LessonSubmissionResponse.model_validate(
            {
                "submissionId": str(historical.request.submission_id),
                "processedAt": "2026-10-30T01:00:00Z",
                "result": {"scoreCorrect": 3, "scoreTotal": 3, "results": [], "status": "COMPLETED", "srsItemsRegistered": 2},
            }
        )
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            db.add(
                LessonSubmission(
                    user_id=historical.user_id,
                    submission_id=historical.request.submission_id,
                    lesson_id=historical.lesson_id,
                    request_fingerprint=submission_fingerprint(historical.lesson_id, historical.request),
                    fingerprint_version=1,
                    response_schema_version=1,
                    response_body=response.model_dump(mode="json", by_alias=True),
                    processed_at=response.processed_at,
                )
            )
            await db.commit()
        legacy_hash = await _legacy_hash(engine, historical, audio_id)
        before_daily = await _daily_rows(engine, historical.user_id)
        before_security = await _metadata(engine)
        for action in [("upgrade", REVISION), ("downgrade", "-1"), ("upgrade", REVISION)]:
            migrated = _alembic(isolated_postgres_url, *action)
            assert migrated.returncode == 0, migrated.stderr
            assert await _metadata(engine) == before_security
            assert await _legacy_hash(engine, historical, audio_id) == legacy_hash
            assert await _daily_rows(engine, historical.user_id, old_columns=True) == before_daily
        assert not any(row["lesson_completed"] for row in await _daily_rows(engine, historical.user_id))
        yield isolated_postgres_url, historical
    finally:
        await engine.dispose()


@pytest_asyncio.fixture
async def engine(study_day_database):
    value = create_async_engine(study_day_database[0], pool_size=20, max_overflow=5)
    try:
        yield value
    finally:
        await value.dispose()


async def test_marker_migration_keeps_old_columns_private_and_rejects_existing_marker(engine):
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == REVISION
    assert await _scalar(engine, "SELECT relrowsecurity FROM pg_class WHERE oid='daily_progress'::regclass")
    assert await _scalar(engine, "SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='daily_progress'::regclass") == "postgres"
    for role in ["anon", "authenticated"]:
        assert not await _scalar(
            engine, f"SELECT has_column_privilege('{role}','daily_progress','lesson_completed','SELECT,INSERT,UPDATE,REFERENCES')"
        )
        await _denied(engine, role, "SELECT lesson_completed FROM daily_progress LIMIT 0")
    spec = importlib.util.spec_from_file_location("study_day_marker", MIGRATION)
    assert spec and spec.loader
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    def upgrade(connection):
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

    before = await _metadata(engine)
    with pytest.raises(DBAPIError, match="already exists; refusing to overwrite"):
        async with engine.begin() as connection:
            await connection.run_sync(upgrade)
    assert await _metadata(engine) == before


async def test_existing_trusted_service_role_grants_survive_without_reopening_clients(engine, study_day_database):
    historical = study_day_database[1]
    for privilege in ["SELECT", "INSERT", "UPDATE", "DELETE"]:
        assert await _scalar(engine, f"SELECT has_table_privilege('service_role','daily_progress','{privilege}')")
    for privilege in ["TRUNCATE", "REFERENCES", "TRIGGER"]:
        assert not await _scalar(engine, f"SELECT has_table_privilege('service_role','daily_progress','{privilege}')")
    assert await _scalar(engine, "SELECT has_column_privilege('service_role','daily_progress','date','REFERENCES')")
    assert not await _scalar(engine, "SELECT has_column_privilege('service_role','daily_progress','lesson_completed','REFERENCES')")
    assert await _scalar(
        engine,
        "SELECT has_column_privilege('service_role','daily_progress','lesson_completed','SELECT,INSERT,UPDATE')",
    )
    assert await _scalar(engine, "SELECT rolbypassrls FROM pg_roles WHERE rolname='service_role'")
    assert await _scalar(engine, "SELECT relrowsecurity AND NOT relforcerowsecurity FROM pg_class WHERE oid='daily_progress'::regclass")
    assert (
        await _scalar(
            engine,
            "SELECT count(*) FROM pg_default_acl WHERE defaclrole='postgres'::regrole "
            "AND defaclnamespace='public'::regnamespace AND defaclobjtype='r' "
            "AND EXISTS(SELECT 1 FROM aclexplode(defaclacl) a WHERE a.grantee='service_role'::regrole AND a.privilege_type='SELECT')",
        )
        == 1
    )
    assert await _scalar(
        engine,
        "SELECT 'pgrst.db_schemas=pgrst_no_exposed_schemas'=ANY(rolconfig) FROM pg_roles WHERE rolname='authenticator'",
    )
    async with engine.connect() as connection, connection.begin():
        await connection.execute(text("SET LOCAL ROLE service_role"))
        assert (
            await connection.scalar(
                text("SELECT lesson_completed FROM daily_progress WHERE user_id=:uid AND date='2026-10-30'"),
                {"uid": historical.user_id},
            )
            is False
        )
    for role in ["anon", "authenticated"]:
        assert not await _scalar(engine, f"SELECT has_any_column_privilege('{role}','daily_progress','SELECT,INSERT,UPDATE,REFERENCES')")
        await _denied(engine, role, "SELECT lesson_completed FROM daily_progress LIMIT 0")


async def test_preexisting_receipt_replay_never_backfills_a_study_day(engine, study_day_database):
    historical = study_day_database[1]
    before = await _state(engine, historical.user_id)
    result = await _get(engine, historical)
    assert (await _submit(engine, historical)).model_dump(mode="json") == result.model_dump(mode="json")
    assert await _state(engine, historical.user_id) == before
    assert len(before["daily"]) == 1 and before["daily"][0]["lesson_completed"] is False


@pytest.mark.parametrize("wrong", [False, True], ids=["all-correct", "zero-score-completed"])
async def test_first_keyed_completion_marks_study_without_xp_goal_or_fake_aggregates(engine, monkeypatch, wrong):
    _freeze(monkeypatch, lesson_submission, NOW)
    monkeypatch.setattr(stats_dashboard, "get_today_kst", lambda: study_date_kst(NOW))
    attempt = await _seed(engine)
    request = attempt.request
    if wrong:
        raw = request.model_dump(mode="json", by_alias=True)
        raw["answers"][0]["selectedAnswer"] = "b"
        raw["answers"][1]["selectedAnswer"] = "b"
        raw["answers"][2]["submittedOrder"] = ["です", "本"]
        request = LessonSubmissionRequest.model_validate(raw)
    result = await _submit(engine, attempt, request)
    assert result.result.status == "COMPLETED" and result.processed_at == NOW
    assert result.result.score_correct == (0 if wrong else 3)
    state = await _state(engine, attempt.user_id)
    assert state["user"]["streak_count"] == state["user"]["longest_streak"] == 1
    assert state["user"]["experience_points"] == 0
    row = state["daily"][0]
    assert row["date"] == "2026-11-02" and row["lesson_completed"] is True
    assert all(
        row[k] == 0
        for k in [
            "words_studied",
            "quizzes_completed",
            "correct_answers",
            "total_answers",
            "conversation_count",
            "xp_earned",
            "kana_learned",
            "grammar_studied",
            "sentences_studied",
            "study_minutes",
            "study_time_seconds",
        ]
    )
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        dashboard = await get_dashboard_data(db, user)
        history = await get_history_data(db, user_id=user.id, year=2026, month=11)
        goal = await get_vocabulary_goal(db, user_id=user.id, day=date(2026, 11, 2))
    assert dashboard.today.has_studied and dashboard.streak.studied_today
    assert dashboard.streak.current == dashboard.streak.longest == 1
    assert history.records[0].has_studied and history.records[0].xp_earned == 0
    assert goal.answered_count == 0 and dashboard.today.vocabulary_goal.answered_count == 0


async def test_compatibility_receipt_stays_unrecognized_after_activation(engine, monkeypatch):
    attempt = await _seed(engine)
    before = await _state(engine, attempt.user_id)
    _freeze(monkeypatch, lesson_submission, NOW)
    monkeypatch.setattr(lesson_submission, "LESSON_STUDY_DAY_RECOGNITION_ENABLED", False)
    completed = await _submit(engine, attempt)
    assert completed.result.status == "COMPLETED" and completed.result.srs_items_registered == 2
    compatibility_state = await _state(engine, attempt.user_id)
    assert compatibility_state["progress"][0]["attempts"] == 1
    assert len(compatibility_state["receipts"]) == 1
    assert len(compatibility_state["words"]) == len(before["words"]) + 1
    assert len(compatibility_state["grammar"]) == 1
    assert compatibility_state["user"] == before["user"]
    assert len(compatibility_state["events"]) == 3
    assert compatibility_state["daily"] is None
    assert compatibility_state["user"]["streak_count"] == 0
    assert compatibility_state["user"]["last_study_date"] is None

    monkeypatch.setattr(lesson_submission, "LESSON_STUDY_DAY_RECOGNITION_ENABLED", True)
    _freeze(monkeypatch, lesson_submission, NOW + timedelta(days=1))
    assert (await _get(engine, attempt)) == completed
    assert (await _submit(engine, attempt)) == completed
    assert await _state(engine, attempt.user_id) == compatibility_state
    raw = attempt.request.model_dump(mode="json", by_alias=True)
    raw["submissionId"] = str(uuid4())
    await _submit(engine, attempt, LessonSubmissionRequest.model_validate(raw))
    activated_state = await _state(engine, attempt.user_id)
    assert activated_state["user"]["streak_count"] == 1
    assert len(activated_state["daily"]) == 1
    assert activated_state["daily"][0]["date"] == "2026-11-03"
    assert activated_state["daily"][0]["lesson_completed"] is True
    assert activated_state["progress"][0]["attempts"] == 2


async def test_same_id_next_day_get_and_post_recovery_change_no_rows(engine, monkeypatch):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_submission, NOW)
    first = await _submit(engine, attempt)
    before = await _state(engine, attempt.user_id)
    _freeze(monkeypatch, lesson_submission, NOW + timedelta(days=1))
    for _ in range(3):
        assert (await _get(engine, attempt)).model_dump(mode="json") == first.model_dump(mode="json")
        assert (await _submit(engine, attempt)).model_dump(mode="json") == first.model_dump(mode="json")
    assert await _state(engine, attempt.user_id) == before


async def test_same_day_new_attempt_and_next_day_new_attempt_count_days_once(engine, monkeypatch):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_submission, NOW)
    await _submit(engine, attempt)
    await _submit(engine, attempt, attempt.request.model_copy(update={"submission_id": uuid4()}))
    state = await _state(engine, attempt.user_id)
    assert len(state["daily"]) == 1 and state["user"]["streak_count"] == 1
    assert state["progress"][0]["attempts"] == 2
    _freeze(monkeypatch, lesson_submission, NOW + timedelta(days=1))
    await _submit(engine, attempt, attempt.request.model_copy(update={"submission_id": uuid4()}))
    state = await _state(engine, attempt.user_id)
    assert len(state["daily"]) == 2 and state["user"]["streak_count"] == state["user"]["longest_streak"] == 2
    assert state["progress"][0]["attempts"] == 3 and state["user"]["experience_points"] == 0


@pytest.mark.parametrize(
    "instant",
    [
        datetime(2026, 11, 1, 14, 59, 59, 999999, tzinfo=UTC),
        datetime(2026, 11, 1, 15, tzinfo=UTC),
        datetime(2026, 11, 30, 14, 59, 59, tzinfo=UTC),
        datetime(2026, 11, 30, 15, tzinfo=UTC),
        datetime(2026, 12, 31, 14, 59, 59, tzinfo=UTC),
        datetime(2026, 12, 31, 15, tzinfo=UTC),
    ],
    ids=["before-kst-midnight", "after-kst-midnight", "before-month", "after-month", "before-year", "after-year"],
)
async def test_receipt_daily_and_user_share_single_kst_boundary_instant(engine, monkeypatch, instant):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_submission, instant)
    result = await _submit(engine, attempt)
    state = await _state(engine, attempt.user_id)
    assert result.processed_at == canonical_study_instant(instant)
    assert state["daily"][0]["date"] == study_date_kst(instant).isoformat()
    assert datetime.fromisoformat(state["user"]["last_study_date"]).replace(tzinfo=UTC) == result.processed_at


@pytest.mark.parametrize("failure", ["marker", "after-marker", "receipt-flush", "precommit"])
async def test_study_day_and_streak_rollback_with_failed_receipt_transaction(engine, monkeypatch, failure):
    attempt = await _seed(engine)
    before = await _state(engine, attempt.user_id)
    original = lesson_submission.record_lesson_study_day

    async def fail_marker(*args, **kwargs):
        if failure != "marker":
            await original(*args, **kwargs)
        raise RuntimeError("injected study-day transaction failure")

    if failure in {"marker", "after-marker"}:
        monkeypatch.setattr(lesson_submission, "record_lesson_study_day", fail_marker)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        if failure == "precommit":
            monkeypatch.setattr(db, "commit", AsyncMock(side_effect=RuntimeError("injected commit failure")))
        if failure == "receipt-flush":

            def fail_flush(session, *args):
                if any(isinstance(obj, LessonSubmission) for obj in session.new):
                    raise RuntimeError("injected receipt flush failure")

            event.listen(db.sync_session, "before_flush", fail_flush)
        with pytest.raises(LessonServiceError):
            await submit_lesson_once(db, user, lesson_id=attempt.lesson_id, request=attempt.request)
    assert await _state(engine, attempt.user_id) == before


async def test_legacy_unkeyed_submission_does_not_create_attendance(engine):
    attempt = await _seed(engine)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        await submit_lesson_attempt(db, user, lesson_id=attempt.lesson_id, answers=list(attempt.request.answers))
    state = await _state(engine, attempt.user_id)
    assert state["daily"] is None and state["receipts"] is None and state["user"]["streak_count"] == 0
    assert state["progress"][0]["attempts"] == 1


async def test_auth_loaded_stale_activity_snapshot_is_refreshed_without_losing_xp(engine, monkeypatch):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_submission, NOW)
    async with async_sessionmaker(engine, expire_on_commit=False)() as stale:
        user = await stale.get(User, attempt.user_id)
        async with engine.begin() as connection:
            await connection.execute(
                text(
                    """UPDATE users SET experience_points=77,streak_count=5,longest_streak=9,
                           last_study_date=(CAST(:now AS timestamptz) AT TIME ZONE 'UTC') WHERE id=:uid"""
                ),
                {"uid": user.id, "now": NOW},
            )
        await submit_lesson_once(stale, user, lesson_id=attempt.lesson_id, request=attempt.request)
    state = await _state(engine, attempt.user_id)
    assert state["user"]["experience_points"] == 77
    assert (state["user"]["streak_count"], state["user"]["longest_streak"]) == (5, 9)


async def test_concurrent_same_and_different_keyed_lessons_recognize_one_day(engine, monkeypatch):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_submission, NOW)
    requests = [attempt.request] * 10 + [attempt.request.model_copy(update={"submission_id": uuid4()}) for _ in range(3)]
    await asyncio.gather(*[_submit(engine, attempt, request) for request in requests])
    state = await _state(engine, attempt.user_id)
    assert len(state["daily"]) == 1 and state["user"]["streak_count"] == 1
    assert len(state["receipts"]) == 4 and state["progress"][0]["attempts"] == 4


async def _seed_activity(engine, attempt, activity):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        if activity in {"quiz", "kana-quiz"}:
            domain_id = uuid4()
            db.add(
                QuizSession(
                    id=domain_id,
                    user_id=attempt.user_id,
                    quiz_type=QuizType.VOCABULARY,
                    jlpt_level=JlptLevel.N5,
                    total_questions=1,
                    correct_count=1,
                    questions_data=[{"id": str(attempt.vocabulary_id)}],
                    started_at=NOW,
                )
            )
            await db.flush()
            db.add(
                QuizAnswer(
                    session_id=domain_id,
                    question_id=attempt.vocabulary_id,
                    question_type=QuizType.VOCABULARY,
                    selected_option_id="a",
                    is_correct=True,
                    answered_at=NOW,
                )
            )
        elif activity == "kana-stage":
            domain_id = uuid4()
            max_number = (
                await db.scalar(select(KanaLearningStage.stage_number).order_by(KanaLearningStage.stage_number.desc()).limit(1)) or 0
            )
            db.add(
                KanaLearningStage(
                    id=domain_id,
                    kana_type=KanaType.HIRAGANA,
                    stage_number=max_number + 1,
                    title="동시 학습",
                    description="격리 검사",
                    characters=[],
                )
            )
        else:
            domain_id = uuid4()
            db.add(Conversation(id=domain_id, user_id=attempt.user_id, type=ConversationType.TEXT, messages=[], ended_at=NOW))
        await db.commit()
    return domain_id


async def _complete_activity(engine, attempt, activity, domain_id):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        # Deliberately load auth state before contention, just like real requests.
        user = await db.get(User, attempt.user_id)
        if activity == "quiz":
            await quiz_complete.complete_quiz_session(db, user, QuizCompleteRequest(session_id=domain_id))
        elif activity == "kana-quiz":
            await kana_quiz_complete.complete_kana_quiz_session(db, user, KanaQuizCompleteRequest(session_id=domain_id))
        elif activity == "kana-stage":
            await kana_stage_complete.complete_kana_stage(db, user, KanaStageCompleteRequest(stage_id=domain_id))
        else:
            await conversation_rewards.grant_conversation_completion_rewards(db, user, now=NOW, duration_seconds=60, usage_type="chat")
            await db.commit()


@pytest.mark.parametrize("lesson_first", [True, False], ids=["lesson-first", "other-first"])
@pytest.mark.parametrize(
    "activity,expected_xp",
    [("quiz", 10), ("kana-quiz", 20), ("kana-stage", 30), ("conversation", 20)],
    ids=["quiz", "kana-quiz", "kana-stage", "conversation"],
)
async def test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects(
    engine, monkeypatch, activity, expected_xp, lesson_first
):
    attempt = await _seed(engine)
    domain_id = await _seed_activity(engine, attempt, activity)
    for module in [lesson_submission, quiz_complete, kana_quiz_complete, kana_stage_complete]:
        _freeze(monkeypatch, module, NOW)
    # Hold the first real mutex until the second writer reaches it, exercising
    # both write orders rather than depending on task scheduling luck.
    other_module = {
        "quiz": quiz_complete,
        "kana-quiz": kana_quiz_complete,
        "kana-stage": kana_stage_complete,
        "conversation": conversation_rewards,
    }[activity]
    first_module = lesson_submission if lesson_first else other_module
    second_module = other_module if lesson_first else lesson_submission
    entered, waiting, release = asyncio.Event(), asyncio.Event(), asyncio.Event()

    async def first_lock(db, user):
        await lock_study_user(db, user)
        entered.set()
        await release.wait()

    async def second_lock(db, user):
        waiting.set()
        await lock_study_user(db, user)

    monkeypatch.setattr(first_module, "lock_study_user", first_lock)
    monkeypatch.setattr(second_module, "lock_study_user", second_lock)
    first = asyncio.create_task(_submit(engine, attempt) if lesson_first else _complete_activity(engine, attempt, activity, domain_id))
    await asyncio.wait_for(entered.wait(), timeout=10)
    second = asyncio.create_task(_complete_activity(engine, attempt, activity, domain_id) if lesson_first else _submit(engine, attempt))
    try:
        await asyncio.wait_for(waiting.wait(), timeout=10)
    finally:
        release.set()
    # No AI calls are made; actual reward/daily SQL executes in the local DB.
    await asyncio.wait_for(asyncio.gather(first, second), timeout=15)
    state = await _state(engine, attempt.user_id)
    assert state["user"]["streak_count"] == state["user"]["longest_streak"] == 1
    assert len(state["daily"]) == 1 and state["daily"][0]["lesson_completed"] is True
    assert state["user"]["experience_points"] == state["daily"][0]["xp_earned"] == expected_xp
    assert state["progress"][0]["attempts"] == 1 and len(state["receipts"]) == 1


@pytest.mark.parametrize("auto_first", [True, False], ids=["auto-first", "conversation-first"])
async def test_auto_completion_and_conversation_preserve_both_xp_rewards(engine, monkeypatch, auto_first):
    attempt = await _seed(engine)
    quiz_id = await _seed_activity(engine, attempt, "quiz")
    await _seed_activity(engine, attempt, "conversation")
    entered, waiting, release = asyncio.Event(), asyncio.Event(), asyncio.Event()

    async def first_lock(db, user):
        await lock_study_user(db, user)
        entered.set()
        await release.wait()

    async def second_lock(db, user):
        waiting.set()
        await lock_study_user(db, user)

    first_module = quiz_session if auto_first else conversation_rewards
    second_module = conversation_rewards if auto_first else quiz_session
    monkeypatch.setattr(first_module, "lock_study_user", first_lock)
    monkeypatch.setattr(second_module, "lock_study_user", second_lock)

    async def complete_auto():
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            user = await db.get(User, attempt.user_id)
            assert await quiz_session.auto_complete_sessions(db, user) == 10
            await db.commit()

    async def complete_conversation():
        await _complete_activity(engine, attempt, "conversation", None)

    first = asyncio.create_task(complete_auto() if auto_first else complete_conversation())
    await asyncio.wait_for(entered.wait(), timeout=10)
    second = asyncio.create_task(complete_conversation() if auto_first else complete_auto())
    try:
        await asyncio.wait_for(waiting.wait(), timeout=10)
    finally:
        release.set()
    await asyncio.wait_for(asyncio.gather(first, second), timeout=15)
    state = await _state(engine, attempt.user_id)
    assert state["user"]["experience_points"] == 30
    assert state["user"]["streak_count"] == 1
    assert state["daily"][0]["xp_earned"] == 20
    assert state["daily"][0]["conversation_count"] == 1
    assert state["daily"][0]["lesson_completed"] is False
    async with async_sessionmaker(engine)() as db:
        assert (await db.get(QuizSession, quiz_id)).completed_at is not None


async def test_web_lock_protocol_and_api_lesson_share_user_mutex(engine, monkeypatch):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_submission, NOW)

    async def web_reward():
        async with engine.begin() as connection:
            # Exact lock/snapshot fields used by web lockStudyActivityUser.
            row = (
                (
                    await connection.execute(
                        text("""SELECT id,experience_points AS "experiencePoints",level,
              last_study_date AS "lastStudyDate",streak_count AS "streakCount",longest_streak AS "longestStreak"
              FROM public.users WHERE id=:uid FOR NO KEY UPDATE"""),
                        {"uid": attempt.user_id},
                    )
                )
                .mappings()
                .one()
            )
            streak = update_streak(row["lastStudyDate"], row["streakCount"], row["longestStreak"], study_date_kst(NOW))
            await connection.execute(
                text("""INSERT INTO daily_progress
                  (id,user_id,date,words_studied,quizzes_completed,correct_answers,total_answers,
                   conversation_count,study_time_seconds,xp_earned,kana_learned,grammar_studied,sentences_studied,study_minutes)
              VALUES(:id,:uid,:day,0,0,0,0,0,0,7,0,0,0,0)
              ON CONFLICT(user_id,date) DO UPDATE SET xp_earned=daily_progress.xp_earned+7"""),
                {"id": uuid4(), "uid": attempt.user_id, "day": study_date_kst(NOW)},
            )
            await connection.execute(
                text("""UPDATE users SET experience_points=experience_points+7,
              streak_count=:current,longest_streak=:longest,
                  last_study_date=(CAST(:now AS timestamptz) AT TIME ZONE 'UTC') WHERE id=:uid"""),
                {"uid": attempt.user_id, "current": streak["streak_count"], "longest": streak["longest_streak"], "now": NOW},
            )

    await asyncio.gather(_submit(engine, attempt), web_reward())
    state = await _state(engine, attempt.user_id)
    assert state["user"]["streak_count"] == 1 and state["user"]["experience_points"] == 7
    assert state["daily"][0]["lesson_completed"] is True and state["daily"][0]["xp_earned"] == 7


async def test_marker_upsert_preserves_other_daily_aggregates(engine, monkeypatch):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_submission, NOW)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        db.add(
            DailyProgress(
                user_id=attempt.user_id, date=study_date_kst(NOW), words_studied=7, quizzes_completed=2, xp_earned=90, grammar_studied=3
            )
        )
        await db.commit()
    before = (await _daily_rows(engine, attempt.user_id, old_columns=True))[0]
    await _submit(engine, attempt)
    assert (await _daily_rows(engine, attempt.user_id, old_columns=True))[0] == before


async def test_populated_study_marker_prevents_destructive_downgrade(engine, study_day_database):
    attempt = await _seed(engine)
    await _submit(engine, attempt)
    before = await _state(engine, attempt.user_id)
    result = _alembic(study_day_database[0], "downgrade", "-1")
    assert result.returncode != 0 and "Recognized lesson study days exist" in result.stderr
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == REVISION
    assert await _state(engine, attempt.user_id) == before


async def test_waiting_for_user_lock_across_midnight_uses_after_lock_processing_day(engine, monkeypatch):
    attempt = await _seed(engine)
    entered = asyncio.Event()
    instant = datetime(2026, 11, 1, 14, 59, 59, tzinfo=UTC)

    class AdvancingDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return instant.astimezone(tz) if tz else instant.replace(tzinfo=None)

    monkeypatch.setattr(lesson_submission, "datetime", AdvancingDatetime)

    async def observed_lock(db, user):
        entered.set()
        await lock_study_user(db, user)

    monkeypatch.setattr(lesson_submission, "lock_study_user", observed_lock)
    async with async_sessionmaker(engine, expire_on_commit=False)() as holder:
        user = await holder.get(User, attempt.user_id)
        await lock_study_user(holder, user)
        pending = asyncio.create_task(_submit(engine, attempt))
        await asyncio.wait_for(entered.wait(), timeout=10)
        instant = datetime(2026, 11, 1, 15, tzinfo=UTC)
        await holder.rollback()
    receipt = await pending
    state = await _state(engine, attempt.user_id)
    assert receipt.processed_at == instant
    assert state["daily"][0]["date"] == "2026-11-02" and state["user"]["streak_count"] == 1


async def test_stage_timestamp_upserts_work_on_unchanged_not_null_schema(engine):
    from app.models.kana import UserKanaStage

    attempt = await _seed(engine)
    first = await _seed_activity(engine, attempt, "kana-stage")
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        stage = await db.get(KanaLearningStage, first)
        next_stage = KanaLearningStage(
            kana_type=stage.kana_type, stage_number=stage.stage_number + 1, title="다음 단계", description="격리 검사", characters=[]
        )
        db.add(next_stage)
        await db.commit()
        second = next_stage.id
    # This would fail with the pre-existing missing updated_at Core INSERT.
    await _complete_activity(engine, attempt, "kana-stage", first)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        rows = (await db.scalars(select(UserKanaStage).where(UserKanaStage.user_id == attempt.user_id))).all()
        assert {row.stage_id for row in rows} == {first, second}
        created = {row.stage_id: row.created_at for row in rows}
        assert all(row.updated_at is not None for row in rows)
        current = next(row for row in rows if row.stage_id == first)
        unlocked = next(row for row in rows if row.stage_id == second)
        assert current.is_completed and unlocked.is_unlocked and not unlocked.is_completed
    await _complete_activity(engine, attempt, "kana-stage", first)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        rows = (await db.scalars(select(UserKanaStage).where(UserKanaStage.user_id == attempt.user_id))).all()
        assert {row.stage_id: row.created_at for row in rows} == created
        assert all(row.updated_at is not None for row in rows)
        assert len(rows) == 2
    assert (
        await _scalar(
            engine,
            """SELECT column_default FROM information_schema.columns
                WHERE table_schema='public' AND table_name='user_kana_stages' AND column_name='updated_at'""",
        )
        is None
    )


async def test_start_and_incomplete_answers_do_not_recognize_a_study_day(engine):
    attempt = await _seed(engine)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        started = await start_lesson_progress(db, user, lesson_id=attempt.lesson_id)
        assert started.status == "IN_PROGRESS" and started.attempts == 0
    before = await _state(engine, attempt.user_id)
    partial = attempt.request.model_copy(update={"answers": attempt.request.answers[:1]})
    with pytest.raises(LessonServiceError) as failure:
        await _submit(engine, attempt, partial)
    assert failure.value.status_code == 400
    assert await _state(engine, attempt.user_id) == before
    assert before["daily"] is None and before["receipts"] is None
    assert before["user"]["streak_count"] == 0
