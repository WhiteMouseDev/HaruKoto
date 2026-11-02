"""Real disposable PostgreSQL: study-day receipts, migration, races and rollback."""

import asyncio
import importlib.util
from copy import deepcopy
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
import pytest_asyncio
from alembic.migration import MigrationContext
from alembic.operations import Operations
from pydantic import TypeAdapter
from sqlalchemy import event, select, text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models import (
    Conversation,
    DailyProgress,
    KanaCharacter,
    KanaLearningStage,
    LessonItemLink,
    QuizAnswer,
    QuizSession,
    StudyActivityReceipt,
    Vocabulary,
)
from app.models.enums import ConversationType, JlptLevel, KanaType, QuizType
from app.models.lesson import Lesson, LessonSubmission
from app.models.user import User
from app.schemas.kana import KanaQuizAnswerRequest, KanaQuizCompleteRequest, KanaStageCompleteRequest
from app.schemas.lesson import LessonSubmissionResponse
from app.schemas.quiz import QuizAnswerRequest, QuizCompleteRequest
from app.schemas.study_activity import LessonStudyActivityRequest
from app.services import (
    conversation_rewards,
    kana_quiz_answer,
    kana_quiz_complete,
    kana_quiz_start,
    kana_stage_complete,
    lesson_study_activity,
    quiz_answer,
    quiz_complete,
    quiz_session,
    stats_dashboard,
    study_day_recording,
)
from app.services.gamification import update_streak
from app.services.lesson_command import LessonServiceError, start_lesson_progress
from app.services.lesson_submission import submission_fingerprint
from app.services.stats_dashboard import get_dashboard_data
from app.services.stats_history import get_history_data
from app.services.study_day_recording import canonical_study_instant, lock_study_user
from app.services.vocabulary_goal import get_vocabulary_goal
from app.utils.date import study_date_kst
from tests.test_lesson_submissions_postgres import _get, _legacy_hash, _seed_legacy_history
from tests.test_lesson_submissions_postgres import _metadata as _original_metadata
from tests.test_lesson_submissions_postgres import _seed as _seed_old
from tests.test_lesson_submissions_postgres import _submit as _submit_final
from tests.test_public_access_hardening_postgres import _alembic, _denied, _scalar, _sql
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url

REVISION = "p6q7r8s9t0u1"
MIGRATION = Path(__file__).resolve().parents[1] / f"alembic/versions/{REVISION}_add_lesson_study_day_marker.py"
NOW = datetime(2026, 11, 2, 1, tzinfo=UTC)


@pytest.fixture(autouse=True)
def enable_recognition_for_feature_regressions(monkeypatch):
    # Both compatibility and activation commits execute every feature regression.
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", True)


def _freeze(monkeypatch, module, instant):
    class FrozenDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return instant.astimezone(tz) if tz is not None else instant.replace(tzinfo=None)

    monkeypatch.setattr(module, "datetime", FrozenDatetime)


async def _daily_rows(engine, user_id, *, old_columns=False):
    projection = "to_jsonb(d)-'activity_recorded'" if old_columns else "to_jsonb(d)"
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
                'activities',(SELECT jsonb_agg(to_jsonb(a) ORDER BY activity_id) FROM study_activity_receipts a WHERE user_id=:uid),
                'quizAnswers',(SELECT jsonb_agg(to_jsonb(a) ORDER BY a.id)
                  FROM quiz_answers a JOIN quiz_sessions q ON q.id=a.session_id WHERE q.user_id=:uid),
                'kana',(SELECT jsonb_agg(to_jsonb(k) ORDER BY k.id) FROM user_kana_progress k WHERE user_id=:uid),
                'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM review_events e WHERE user_id=:uid))"""),
            {"uid": user_id},
        )


async def _metadata(engine):
    value = await _original_metadata(engine)
    value["objects"] = [row for row in value["objects"] if "study_activity" not in row[1]]
    return value


async def _seed(engine):
    attempt = await _seed_old(engine)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        lesson = await db.get(Lesson, attempt.lesson_id)
        content = deepcopy(lesson.content_jsonb)
        for q in content["questions"]:
            q["prompt"] = "확인"
            if q["type"] == "SENTENCE_REORDER":
                q["tokens"] = ["本", "です"]
            else:
                q["options"] = [{"id": "a", "text": "정답"}, {"id": "b", "text": "오답"}]
        lesson.content_jsonb = content
        word = await db.get(Vocabulary, attempt.vocabulary_id)
        word.word = "本"
        word.reading = str(attempt.vocabulary_id)
        water = await db.get(Vocabulary, attempt.historical_id)
        water.word = "水"
        water.reading = str(attempt.historical_id)
        db.add(LessonItemLink(lesson_id=attempt.lesson_id, item_type="WORD", vocabulary_id=attempt.historical_id, item_order=2))
        await db.commit()
    return attempt


async def _request(engine, attempt, kind="RECOGNITION", wrong=False):
    async with async_sessionmaker(engine)() as db:
        _, _, version = await lesson_study_activity._activity_source(db, attempt.lesson_id)
    answer = {"questionOrder": 1, "selectedAnswer": "b" if wrong else "a"}
    if kind == "SENTENCE_REORDER":
        answer = {"questionOrder": 3, "submittedOrder": ["水" if wrong else "本", "です"]}
    if kind == "MATCHING":
        answer = {
            "leftVocabularyId": str(attempt.vocabulary_id),
            "rightVocabularyId": str(attempt.historical_id if wrong else attempt.vocabulary_id),
        }
    return TypeAdapter(LessonStudyActivityRequest).validate_python(
        {
            "expectedUserId": str(attempt.user_id),
            "activityId": str(uuid4()),
            "attemptId": str(uuid4()),
            "contentVersion": version,
            "kind": kind,
            "answer": answer,
        }
    )


async def _record(engine, attempt, request=None):
    request = request or await _request(engine, attempt)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        return await lesson_study_activity.record_lesson_activity(db, user, lesson_id=attempt.lesson_id, request=request)


async def _read(engine, attempt, request):
    async with async_sessionmaker(engine)() as db:
        user = await db.get(User, attempt.user_id)
        return await lesson_study_activity.get_lesson_activity(
            db, user, lesson_id=attempt.lesson_id, activity_id=request.activity_id, expected_user_id=attempt.user_id
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
        historical = await _seed_old(engine)
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
        assert not any(row["activity_recorded"] for row in await _daily_rows(engine, historical.user_id))
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
            engine, f"SELECT has_column_privilege('{role}','daily_progress','activity_recorded','SELECT,INSERT,UPDATE,REFERENCES')"
        )
        await _denied(engine, role, "SELECT activity_recorded FROM daily_progress LIMIT 0")
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
    assert not await _scalar(engine, "SELECT has_column_privilege('service_role','daily_progress','activity_recorded','REFERENCES')")
    assert await _scalar(
        engine,
        "SELECT has_column_privilege('service_role','daily_progress','activity_recorded','SELECT,INSERT,UPDATE')",
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
                text("SELECT activity_recorded FROM daily_progress WHERE user_id=:uid AND date='2026-10-30'"),
                {"uid": historical.user_id},
            )
            is False
        )
    for role in ["anon", "authenticated"]:
        assert not await _scalar(engine, f"SELECT has_any_column_privilege('{role}','daily_progress','SELECT,INSERT,UPDATE,REFERENCES')")
        await _denied(engine, role, "SELECT activity_recorded FROM daily_progress LIMIT 0")


async def test_preexisting_receipt_replay_never_backfills_a_study_day(engine, study_day_database):
    historical = study_day_database[1]
    before = await _state(engine, historical.user_id)
    result = await _get(engine, historical)
    assert (await _submit_final(engine, historical)).model_dump(mode="json") == result.model_dump(mode="json")
    assert await _state(engine, historical.user_id) == before
    assert len(before["daily"]) == 1 and before["daily"][0]["activity_recorded"] is False


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
    assert state["daily"][0]["activity_recorded"] is False
    async with async_sessionmaker(engine)() as db:
        assert (await db.get(QuizSession, quiz_id)).completed_at is not None


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


@pytest.mark.parametrize("kind", ["RECOGNITION", "SENTENCE_REORDER", "MATCHING"])
@pytest.mark.parametrize("wrong", [False, True], ids=["correct", "valid-wrong"])
async def test_first_lesson_answer_records_day_without_grading_srs_xp_or_goal(engine, monkeypatch, kind, wrong):
    _freeze(monkeypatch, lesson_study_activity, NOW)
    monkeypatch.setattr(stats_dashboard, "get_today_kst", lambda: study_date_kst(NOW))
    attempt = await _seed(engine)
    before = await _state(engine, attempt.user_id)
    request = await _request(engine, attempt, kind, wrong)
    receipt = await _record(engine, attempt, request)
    after = await _state(engine, attempt.user_id)
    assert receipt.processed_at == NOW and receipt.study_date == study_date_kst(NOW)
    assert after["user"]["streak_count"] == after["user"]["longest_streak"] == 1
    assert after["user"]["experience_points"] == 0
    for field in ["progress", "words", "grammar", "receipts", "events", "quizAnswers", "kana"]:
        assert after[field] == before[field]
    row = after["daily"][0]
    assert row["activity_recorded"] is True
    assert all(value == 0 for key, value in row.items() if key not in {"id", "user_id", "date", "activity_recorded"})
    async with async_sessionmaker(engine)() as db:
        user = await db.get(User, attempt.user_id)
        dashboard = await get_dashboard_data(db, user)
        history = await get_history_data(db, user_id=user.id, year=2026, month=11)
        goal = await get_vocabulary_goal(db, user_id=user.id, day=study_date_kst(NOW))
    assert dashboard.today.has_studied and dashboard.streak.current == 1
    assert history.records[0].has_studied and goal.answered_count == 0


async def test_activity_replays_next_day_even_after_source_deleted_without_new_day(engine, monkeypatch):
    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    _freeze(monkeypatch, lesson_study_activity, NOW)
    receipt = await _record(engine, attempt, request)
    await _sql(engine, f"DELETE FROM lessons WHERE id='{attempt.lesson_id}'")
    before = await _state(engine, attempt.user_id)
    _freeze(monkeypatch, lesson_study_activity, NOW + timedelta(days=1))
    assert await _read(engine, attempt, request) == receipt
    assert await _record(engine, attempt, request) == receipt
    assert await _state(engine, attempt.user_id) == before


async def test_same_id_changed_payload_and_wrong_account_or_lesson_are_rejected(engine):
    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    await _record(engine, attempt, request)
    before = await _state(engine, attempt.user_id)
    raw = request.model_dump(mode="json", by_alias=True)
    raw["answer"]["selectedAnswer"] = "b"
    changed = TypeAdapter(LessonStudyActivityRequest).validate_python(raw)
    with pytest.raises(LessonServiceError) as exc:
        await _record(engine, attempt, changed)
    assert exc.value.status_code == 409
    async with async_sessionmaker(engine)() as db:
        user = await db.get(User, attempt.user_id)
        with pytest.raises(LessonServiceError) as exc:
            await lesson_study_activity.get_lesson_activity(
                db, user, lesson_id=uuid4(), activity_id=request.activity_id, expected_user_id=user.id
            )
        assert exc.value.status_code == 404
        with pytest.raises(LessonServiceError) as exc:
            await lesson_study_activity.get_lesson_activity(
                db, user, lesson_id=attempt.lesson_id, activity_id=request.activity_id, expected_user_id=uuid4()
            )
        assert exc.value.status_code == 403
    assert await _state(engine, attempt.user_id) == before


async def test_content_version_changes_reject_new_event_but_not_old_receipt(engine):
    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    receipt = await _record(engine, attempt, request)
    async with async_sessionmaker(engine)() as db:
        lesson = await db.get(Lesson, attempt.lesson_id)
        content = deepcopy(lesson.content_jsonb)
        content["questions"][0]["prompt"] = "변경한 원문"
        lesson.content_jsonb = content
        await db.commit()
    raw = request.model_dump(mode="json", by_alias=True)
    raw["activityId"] = str(uuid4())
    with pytest.raises(LessonServiceError) as exc:
        await _record(engine, attempt, TypeAdapter(LessonStudyActivityRequest).validate_python(raw))
    assert exc.value.status_code == 409
    assert await _record(engine, attempt, request) == receipt


@pytest.mark.parametrize(
    "kind,answer",
    [
        ("RECOGNITION", {"questionOrder": 1, "selectedAnswer": "invented"}),
        ("RECOGNITION", {"questionOrder": 99, "selectedAnswer": "a"}),
        ("SENTENCE_REORDER", {"questionOrder": 3, "submittedOrder": ["本"]}),
        ("SENTENCE_REORDER", {"questionOrder": 3, "submittedOrder": ["捏造", "です"]}),
        ("SENTENCE_REORDER", {"questionOrder": 3, "submittedOrder": ["水", "水"]}),
        ("MATCHING", {"leftVocabularyId": str(uuid4()), "rightVocabularyId": str(uuid4())}),
    ],
    ids=["unknown-option", "unknown-question", "unfinished-reorder", "invented-token", "excess-distractor-copy", "foreign-vocab"],
)
async def test_invalid_activity_creates_no_marker_receipt_or_learning_effect(engine, kind, answer):
    attempt = await _seed(engine)
    request = await _request(engine, attempt, kind)
    raw = request.model_dump(mode="json", by_alias=True)
    raw["answer"] = answer
    request = TypeAdapter(LessonStudyActivityRequest).validate_python(raw)
    before = await _state(engine, attempt.user_id)
    with pytest.raises(LessonServiceError) as exc:
        await _record(engine, attempt, request)
    assert exc.value.status_code == 400
    assert await _state(engine, attempt.user_id) == before


@pytest.mark.parametrize("failure", ["marker-before", "marker-after", "receipt-flush", "commit-before"])
async def test_activity_receipt_marker_and_streak_rollback_together(engine, monkeypatch, failure):
    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    before = await _state(engine, attempt.user_id)
    original = study_day_recording.record_answered_study_day

    async def failed_marker(db, user, *, processed_at):
        if failure == "marker-after":
            await original(db, user, processed_at=processed_at)
        raise RuntimeError("synthetic marker failure")

    if failure.startswith("marker"):
        monkeypatch.setattr(study_day_recording, "record_answered_study_day", failed_marker)

    def failed_insert(conn, cursor, statement, params, context, many):
        if failure == "receipt-flush" and statement.startswith("INSERT INTO study_activity_receipts"):
            raise RuntimeError("synthetic receipt failure")

    event.listen(engine.sync_engine, "before_cursor_execute", failed_insert)
    try:
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            user = await db.get(User, attempt.user_id)
            if failure == "commit-before":
                monkeypatch.setattr(db, "commit", AsyncMock(side_effect=RuntimeError("synthetic commit failure")))
            with pytest.raises(LessonServiceError) as exc:
                await lesson_study_activity.record_lesson_activity(db, user, lesson_id=attempt.lesson_id, request=request)
            assert exc.value.status_code == 503
    finally:
        event.remove(engine.sync_engine, "before_cursor_execute", failed_insert)
    assert await _state(engine, attempt.user_id) == before


async def test_activity_commit_response_loss_is_recovered_without_posting_new_event(engine, monkeypatch):
    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        original = db.commit

        async def lost_response():
            await original()
            raise RuntimeError("committed response lost")

        monkeypatch.setattr(db, "commit", lost_response)
        with pytest.raises(LessonServiceError):
            await lesson_study_activity.record_lesson_activity(db, user, lesson_id=attempt.lesson_id, request=request)
    before = await _state(engine, attempt.user_id)
    result = await _read(engine, attempt, request)
    assert result.activity_id == request.activity_id
    assert await _record(engine, attempt, request) == result
    assert await _state(engine, attempt.user_id) == before


@pytest.mark.parametrize(
    "instant",
    [
        datetime(2026, 11, 1, 14, 59, 59, 999999, tzinfo=UTC),
        datetime(2026, 11, 1, 15, tzinfo=UTC),
        datetime(2026, 11, 30, 14, 59, 59, 999999, tzinfo=UTC),
        datetime(2026, 11, 30, 15, tzinfo=UTC),
        datetime(2026, 12, 31, 14, 59, 59, 999999, tzinfo=UTC),
        datetime(2026, 12, 31, 15, tzinfo=UTC),
    ],
    ids=["before-midnight", "after-midnight", "before-month", "after-month", "before-year", "after-year"],
)
async def test_activity_receipt_user_and_daily_share_processing_instant(engine, monkeypatch, instant):
    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    _freeze(monkeypatch, lesson_study_activity, instant)
    receipt = await _record(engine, attempt, request)
    state = await _state(engine, attempt.user_id)
    assert receipt.processed_at == canonical_study_instant(instant)
    assert state["daily"][0]["date"] == str(study_date_kst(instant)) == str(receipt.study_date)
    stored = datetime.fromisoformat(state["user"]["last_study_date"]).replace(tzinfo=UTC)
    assert stored == receipt.processed_at


async def test_first_offline_delivery_uses_delivery_day_and_replays_keep_that_day(engine, monkeypatch):
    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    # Building/storing the request has no server side learning effect.
    assert (await _state(engine, attempt.user_id))["daily"] is None
    _freeze(monkeypatch, lesson_study_activity, NOW + timedelta(days=1))
    receipt = await _record(engine, attempt, request)
    _freeze(monkeypatch, lesson_study_activity, NOW + timedelta(days=2))
    assert await _record(engine, attempt, request) == receipt
    assert receipt.study_date == study_date_kst(NOW + timedelta(days=1))
    assert len((await _state(engine, attempt.user_id))["daily"]) == 1


async def test_concurrent_same_and_new_lesson_answer_events_count_day_once(engine, monkeypatch):
    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    _freeze(monkeypatch, lesson_study_activity, NOW)
    requests = [request] * 12 + [request.model_copy(update={"activity_id": uuid4()}) for _ in range(3)]
    await asyncio.gather(*[_record(engine, attempt, r) for r in requests])
    state = await _state(engine, attempt.user_id)
    assert len(state["activities"]) == 4 and len(state["daily"]) == 1
    assert state["user"]["streak_count"] == 1 and state["progress"] is None


async def test_completion_and_start_never_replace_answer_activity_receipt(engine):
    attempt = await _seed(engine)
    before = await _state(engine, attempt.user_id)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        started = await start_lesson_progress(db, user, lesson_id=attempt.lesson_id)
        assert started.status == "IN_PROGRESS" and started.attempts == 0
    started_state = await _state(engine, attempt.user_id)
    assert started_state["daily"] is None and started_state["activities"] is None
    partial = attempt.request.model_copy(update={"answers": attempt.request.answers[:1]})
    with pytest.raises(LessonServiceError) as exc:
        await _submit_final(engine, attempt, partial)
    assert exc.value.status_code == 400
    assert await _state(engine, attempt.user_id) == started_state
    await _submit_final(engine, attempt)
    state = await _state(engine, attempt.user_id)
    assert state["daily"] is None and state["activities"] is None and state["user"]["streak_count"] == 0
    assert len(state["receipts"]) == 1 and state["progress"][0]["attempts"] == 1
    assert len(state["words"]) > len(before["words"])


async def test_off_gate_does_not_backfill_saved_quiz_answer_after_activation(engine, monkeypatch):
    attempt = await _seed(engine)
    session_id, body = await _new_quiz(engine, attempt)
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", False)
    await _answer(engine, attempt, body)
    before = await _state(engine, attempt.user_id)
    assert before["daily"] is None
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", True)
    await _answer(engine, attempt, body)
    assert await _state(engine, attempt.user_id) == before


async def _new_quiz(engine, attempt, mode="normal", wrong=False):
    qid = attempt.vocabulary_id
    correct = "a"
    selected = "b" if wrong else "a"
    question = {
        "id": str(qid),
        "type": "VOCABULARY",
        "question": "本",
        "options": [{"id": "a", "text": "책"}, {"id": "b", "text": "물"}],
        "correctOptionId": correct,
    }
    quiz_type = QuizType.VOCABULARY
    if mode == "matching":
        question.update(options=[], correctOptionId=str(qid), word="本", meaningKo="책")
        selected = str(attempt.historical_id if wrong else qid)
    if mode == "arrange":
        quiz_type = QuizType.SENTENCE_ARRANGE
        question.update(type="SENTENCE_ARRANGE", options=[], correctOptionId="", tokens=["本", "です"], japaneseSentence="本です")
        selected = "wrong" if wrong else ""
    session_id = uuid4()
    async with async_sessionmaker(engine)() as db:
        db.add(
            QuizSession(
                id=session_id,
                user_id=attempt.user_id,
                quiz_type=quiz_type,
                jlpt_level=JlptLevel.N5,
                total_questions=1,
                questions_data={"mode": mode, "questions": [question]},
                started_at=NOW,
            )
        )
        await db.commit()
    return session_id, QuizAnswerRequest(session_id=session_id, question_id=qid, selected_option_id=selected, question_type=quiz_type)


async def _answer(engine, attempt, body):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        return await quiz_answer.submit_quiz_answer(db, user, body)


@pytest.mark.parametrize("mode", ["normal", "matching", "arrange"])
@pytest.mark.parametrize("wrong", [False, True], ids=["correct", "wrong"])
async def test_one_saved_formal_quiz_answer_counts_day_and_only_vocabulary_goal(engine, monkeypatch, mode, wrong):
    attempt = await _seed(engine)
    _freeze(monkeypatch, quiz_answer, NOW)
    _, body = await _new_quiz(engine, attempt, mode, wrong)
    await _answer(engine, attempt, body)
    state = await _state(engine, attempt.user_id)
    assert len(state["quizAnswers"]) == 1 and state["daily"][0]["activity_recorded"]
    assert state["user"]["streak_count"] == 1 and state["user"]["experience_points"] == 0
    assert state["daily"][0]["quizzes_completed"] == state["daily"][0]["xp_earned"] == 0
    async with async_sessionmaker(engine)() as db:
        goal = await get_vocabulary_goal(db, user_id=attempt.user_id, day=study_date_kst(NOW))
    assert goal.answered_count == (0 if mode == "arrange" else 1)
    async with async_sessionmaker(engine)() as db:
        weekly = await stats_dashboard._get_weekly_stats(db, user_id=attempt.user_id, today=study_date_kst(NOW))
    assert weekly[-1].vocabulary_answered_count == goal.answered_count
    assert weekly[-1].has_studied is True
    _freeze(monkeypatch, quiz_answer, NOW + timedelta(days=1))
    await _answer(engine, attempt, body)
    assert await _state(engine, attempt.user_id) == state


async def test_auth_loaded_stale_activity_snapshot_is_refreshed_without_losing_xp(engine, monkeypatch):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_study_activity, NOW)
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
        request = await _request(engine, attempt)
        await lesson_study_activity.record_lesson_activity(stale, user, lesson_id=attempt.lesson_id, request=request)
    state = await _state(engine, attempt.user_id)
    assert state["user"]["experience_points"] == 77
    assert (state["user"]["streak_count"], state["user"]["longest_streak"]) == (5, 9)


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
    for module in [lesson_study_activity, quiz_complete, kana_quiz_complete, kana_stage_complete]:
        _freeze(monkeypatch, module, NOW)
    # Hold the first real mutex until the second writer reaches it, exercising
    # both write orders rather than depending on task scheduling luck.
    other_module = {
        "quiz": quiz_complete,
        "kana-quiz": kana_quiz_complete,
        "kana-stage": kana_stage_complete,
        "conversation": conversation_rewards,
    }[activity]
    first_module = study_day_recording if lesson_first else other_module
    second_module = other_module if lesson_first else study_day_recording
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
    first = asyncio.create_task(_record(engine, attempt) if lesson_first else _complete_activity(engine, attempt, activity, domain_id))
    await asyncio.wait_for(entered.wait(), timeout=10)
    second = asyncio.create_task(_complete_activity(engine, attempt, activity, domain_id) if lesson_first else _record(engine, attempt))
    try:
        await asyncio.wait_for(waiting.wait(), timeout=10)
    finally:
        release.set()
    # No AI calls are made; actual reward/daily SQL executes in the local DB.
    await asyncio.wait_for(asyncio.gather(first, second), timeout=15)
    state = await _state(engine, attempt.user_id)
    assert state["user"]["streak_count"] == state["user"]["longest_streak"] == 1
    assert len(state["daily"]) == 1 and state["daily"][0]["activity_recorded"] is True
    assert state["user"]["experience_points"] == state["daily"][0]["xp_earned"] == expected_xp
    assert state["progress"] is None and len(state["activities"]) == 1


async def test_marker_upsert_preserves_other_daily_aggregates(engine, monkeypatch):
    attempt = await _seed(engine)
    _freeze(monkeypatch, lesson_study_activity, NOW)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        db.add(
            DailyProgress(
                user_id=attempt.user_id, date=study_date_kst(NOW), words_studied=7, quizzes_completed=2, xp_earned=90, grammar_studied=3
            )
        )
        await db.commit()
    before = (await _daily_rows(engine, attempt.user_id, old_columns=True))[0]
    await _record(engine, attempt)
    assert (await _daily_rows(engine, attempt.user_id, old_columns=True))[0] == before


async def test_waiting_for_user_lock_across_midnight_uses_after_lock_processing_day(engine, monkeypatch):
    attempt = await _seed(engine)
    entered = asyncio.Event()
    instant = datetime(2026, 11, 1, 14, 59, 59, tzinfo=UTC)

    class AdvancingDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return instant.astimezone(tz) if tz else instant.replace(tzinfo=None)

    monkeypatch.setattr(lesson_study_activity, "datetime", AdvancingDatetime)

    async def observed_lock(db, user):
        entered.set()
        await lock_study_user(db, user)

    monkeypatch.setattr(study_day_recording, "lock_study_user", observed_lock)
    async with async_sessionmaker(engine, expire_on_commit=False)() as holder:
        user = await holder.get(User, attempt.user_id)
        await lock_study_user(holder, user)
        pending = asyncio.create_task(_record(engine, attempt))
        await asyncio.wait_for(entered.wait(), timeout=10)
        instant = datetime(2026, 11, 1, 15, tzinfo=UTC)
        await holder.rollback()
    receipt = await pending
    state = await _state(engine, attempt.user_id)
    assert receipt.processed_at == instant
    assert state["daily"][0]["date"] == "2026-11-02" and state["user"]["streak_count"] == 1


async def _new_kana(engine, attempt, tagged=True, wrong=False):
    kid = uuid4()
    sid = uuid4()
    question = {"id": str(kid), "question": "あ", "options": [{"id": "a", "text": "a"}, {"id": "b", "text": "i"}], "correctOptionId": "a"}
    if tagged:
        question["_answerActivityVersion"] = 1
    async with async_sessionmaker(engine)() as db:
        db.add(
            KanaCharacter(
                id=kid, kana_type=KanaType.HIRAGANA, character=str(kid), romaji="a", pronunciation="a", row="a", column="a", stroke_count=1
            )
        )
        db.add(
            QuizSession(
                id=sid,
                user_id=attempt.user_id,
                quiz_type=QuizType.KANA,
                jlpt_level=JlptLevel.N5,
                total_questions=1,
                questions_data=[question],
            )
        )
        await db.commit()
    return KanaQuizAnswerRequest(session_id=sid, question_id=kid, selected_option_id="b" if wrong else "a")


async def _kana_answer(engine, attempt, body):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        return await kana_quiz_answer.submit_kana_quiz_answer(db, user, body)


@pytest.mark.parametrize("wrong", [False, True], ids=["correct", "wrong"])
async def test_tagged_kana_answer_atomic_receipt_and_next_day_replay_keep_progress_once(engine, monkeypatch, wrong):
    attempt = await _seed(engine)
    body = await _new_kana(engine, attempt, wrong=wrong)
    _freeze(monkeypatch, kana_quiz_answer, NOW)
    response = await _kana_answer(engine, attempt, body)
    assert response.is_correct is (not wrong)
    state = await _state(engine, attempt.user_id)
    assert len(state["activities"]) == 1 and state["activities"][0]["source_kind"] == "KANA_QUIZ_ANSWER"
    assert state["quizAnswers"] is None and state["daily"][0]["activity_recorded"]
    assert state["user"]["streak_count"] == 1 and state["user"]["experience_points"] == 0
    assert state["kana"][0]["correct_count"] == (0 if wrong else 1)
    assert state["kana"][0]["incorrect_count"] == (1 if wrong else 0)
    _freeze(monkeypatch, kana_quiz_answer, NOW + timedelta(days=1))
    duplicate = await _kana_answer(engine, attempt, body)
    assert duplicate == response and await _state(engine, attempt.user_id) == state
    changed = body.model_copy(update={"selected_option_id": "a" if wrong else "b"})
    with pytest.raises(kana_quiz_answer.KanaQuizAnswerServiceError) as exc:
        await _kana_answer(engine, attempt, changed)
    assert exc.value.status_code == 409 and await _state(engine, attempt.user_id) == state


async def test_private_kana_receipt_cannot_be_read_as_lesson_activity(engine):
    attempt = await _seed(engine)
    body = await _new_kana(engine, attempt)
    await _kana_answer(engine, attempt, body)
    async with async_sessionmaker(engine)() as db:
        user = await db.get(User, attempt.user_id)
        receipt = await db.scalar(select(StudyActivityReceipt).where(StudyActivityReceipt.user_id == user.id))
        with pytest.raises(LessonServiceError) as exc:
            await lesson_study_activity.get_lesson_activity(
                db, user, lesson_id=body.session_id, activity_id=receipt.activity_id, expected_user_id=user.id
            )
        assert exc.value.status_code == 404


async def test_tagged_kana_receipt_failure_rolls_back_progress_count_and_streak(engine):
    attempt = await _seed(engine)
    body = await _new_kana(engine, attempt)
    before = await _state(engine, attempt.user_id)

    def fail_receipt(conn, cursor, statement, params, ctx, many):
        if statement.startswith("INSERT INTO study_activity_receipts"):
            raise RuntimeError("synthetic kana receipt failure")

    event.listen(engine.sync_engine, "before_cursor_execute", fail_receipt)
    try:
        with pytest.raises(RuntimeError, match="synthetic"):
            await _kana_answer(engine, attempt, body)
    finally:
        event.remove(engine.sync_engine, "before_cursor_execute", fail_receipt)
    assert await _state(engine, attempt.user_id) == before
    async with async_sessionmaker(engine)() as db:
        assert (await db.get(QuizSession, body.session_id)).correct_count == 0


async def test_private_receipt_table_remains_owner_only_even_with_trusted_defaults(engine):
    assert await _scalar(
        engine, "SELECT relrowsecurity AND NOT relforcerowsecurity FROM pg_class WHERE oid='study_activity_receipts'::regclass"
    )
    assert await _scalar(engine, "SELECT count(*) FROM pg_policy WHERE polrelid='study_activity_receipts'::regclass") == 0
    for role in ["anon", "authenticated", "service_role"]:
        assert not await _scalar(
            engine,
            f"SELECT has_table_privilege('{role}','study_activity_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')",
        )
        assert not await _scalar(
            engine, f"SELECT has_any_column_privilege('{role}','study_activity_receipts','SELECT,INSERT,UPDATE,REFERENCES')"
        )
        await _denied(engine, role, "SELECT * FROM study_activity_receipts LIMIT 0")


async def test_populated_activity_receipts_and_markers_block_destructive_downgrade(engine, study_day_database):
    attempt = await _seed(engine)
    await _record(engine, attempt)
    before = await _state(engine, attempt.user_id)
    result = _alembic(study_day_database[0], "downgrade", "-1")
    assert result.returncode != 0 and "Accepted activity receipts exist" in result.stderr
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == REVISION
    assert await _state(engine, attempt.user_id) == before


async def test_legacy_untagged_kana_preserves_original_repeat_effects_without_new_attendance(engine):
    attempt = await _seed(engine)
    body = await _new_kana(engine, attempt, tagged=False)
    await _kana_answer(engine, attempt, body)
    await _kana_answer(engine, attempt, body)
    state = await _state(engine, attempt.user_id)
    assert state["activities"] is None and state["daily"] is None and state["user"]["streak_count"] == 0
    assert state["kana"][0]["correct_count"] == 2 and state["kana"][0]["updated_at"] is not None
    async with async_sessionmaker(engine)() as db:
        assert (await db.get(QuizSession, body.session_id)).correct_count == 2
    assert (
        await _scalar(
            engine,
            "SELECT column_default FROM information_schema.columns WHERE table_name='user_kana_progress' AND column_name='updated_at'",
        )
        is None
    )


async def test_tagged_kana_off_receipt_never_backfills_after_activation(engine, monkeypatch):
    attempt = await _seed(engine)
    body = await _new_kana(engine, attempt)
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", False)
    await _kana_answer(engine, attempt, body)
    before = await _state(engine, attempt.user_id)
    assert before["daily"] is None and len(before["activities"]) == 1
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", True)
    await _kana_answer(engine, attempt, body)
    assert await _state(engine, attempt.user_id) == before


async def test_formal_answer_marker_failure_rolls_back_answer_and_srs(engine, monkeypatch):
    attempt = await _seed(engine)
    _, body = await _new_quiz(engine, attempt)
    before = await _state(engine, attempt.user_id)
    monkeypatch.setattr(quiz_answer, "record_answered_study_day", AsyncMock(side_effect=RuntimeError("synthetic activity failure")))
    with pytest.raises(RuntimeError, match="synthetic"):
        await _answer(engine, attempt, body)
    assert await _state(engine, attempt.user_id) == before


@pytest.mark.parametrize("answer_first", [False, True], ids=["completion-first", "answer-first"])
async def test_answer_and_completion_share_lock_order_and_award_xp_once(engine, monkeypatch, answer_first):
    attempt = await _seed(engine)
    sid, body = await _new_quiz(engine, attempt)
    _freeze(monkeypatch, quiz_answer, NOW)
    _freeze(monkeypatch, quiz_complete, NOW)
    # Completion first while no answer exists must return 409, then normal retry succeeds.
    if not answer_first:
        with pytest.raises(quiz_complete.QuizCompleteServiceError) as exc:
            await _complete_activity(engine, attempt, "quiz", sid)
        assert exc.value.status_code == 409
    await _answer(engine, attempt, body)
    await asyncio.gather(_complete_activity(engine, attempt, "quiz", sid), _answer(engine, attempt, body))
    await _complete_activity(engine, attempt, "quiz", sid)
    state = await _state(engine, attempt.user_id)
    assert state["user"]["streak_count"] == 1 and state["user"]["experience_points"] == 10
    assert state["daily"][0]["quizzes_completed"] == 1 and state["daily"][0]["xp_earned"] == 10
    assert len(state["quizAnswers"]) == 1


async def test_exact_web_answer_sql_and_api_activity_share_user_session_mutex(engine, monkeypatch):
    attempt = await _seed(engine)
    sid, body = await _new_quiz(engine, attempt, wrong=True)
    _freeze(monkeypatch, lesson_study_activity, NOW)

    async def web_answer():
        async with engine.begin() as connection:
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
            await connection.execute(text("SELECT id FROM public.quiz_sessions WHERE id=:sid FOR UPDATE"), {"sid": sid})
            prior = await connection.scalar(
                text("SELECT id FROM quiz_answers WHERE session_id=:sid AND question_id=:qid ORDER BY answered_at,id LIMIT 1"),
                {"sid": sid, "qid": body.question_id},
            )
            assert prior is None
            await connection.execute(
                text(
                    """INSERT INTO quiz_answers(id,session_id,question_id,question_type,selected_option_id,is_correct,answered_at)
                    VALUES(:id,:sid,:qid,'VOCABULARY','b',false,:now)"""
                ),
                {"id": uuid4(), "sid": sid, "qid": body.question_id, "now": NOW.replace(tzinfo=None)},
            )
            streak = update_streak(row["lastStudyDate"], row["streakCount"], row["longestStreak"], study_date_kst(NOW))
            await connection.execute(
                text("""INSERT INTO daily_progress
                (id,user_id,date,words_studied,quizzes_completed,correct_answers,total_answers,conversation_count,
                 study_time_seconds,xp_earned,kana_learned,grammar_studied,sentences_studied,study_minutes,activity_recorded)
                VALUES(:id,:uid,:day,0,0,0,0,0,0,0,0,0,0,0,true)
                ON CONFLICT(user_id,date) DO UPDATE SET activity_recorded=true"""),
                {"id": uuid4(), "uid": attempt.user_id, "day": study_date_kst(NOW)},
            )
            await connection.execute(
                text("UPDATE users SET streak_count=:streak,longest_streak=:longest,last_study_date=:now WHERE id=:uid"),
                {
                    "uid": attempt.user_id,
                    "streak": streak["streak_count"],
                    "longest": streak["longest_streak"],
                    "now": NOW.replace(tzinfo=None),
                },
            )

    await asyncio.gather(web_answer(), _record(engine, attempt))
    state = await _state(engine, attempt.user_id)
    assert state["user"]["streak_count"] == 1 and state["user"]["experience_points"] == 0
    assert len(state["daily"]) == 1 and len(state["activities"]) == 1 and len(state["quizAnswers"]) == 1


async def test_activity_http_contract_no_store_validation_auth_and_get_recovery(engine):
    from fastapi import Depends, FastAPI
    from httpx import ASGITransport, AsyncClient

    from app.db.session import get_db
    from app.dependencies import get_current_user
    from app.routers.lessons import router

    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    app = FastAPI()
    app.include_router(router)
    sessions = async_sessionmaker(engine, expire_on_commit=False)

    async def test_db():
        async with sessions() as db:
            yield db

    async def current_user(db=Depends(get_db)):
        return await db.get(User, attempt.user_id)

    app.dependency_overrides[get_db] = test_db
    app.dependency_overrides[get_current_user] = current_user
    path = f"/api/v1/lessons/{attempt.lesson_id}/study-activities"
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post(path, json=request.model_dump(mode="json", by_alias=True))
        assert response.status_code == 200 and response.headers["cache-control"] == "private, no-store"
        assert set(response.json()) == {"activityId", "processedAt", "studyDate"}
        read = await client.get(f"{path}/{request.activity_id}", params={"expectedUserId": str(attempt.user_id)})
        assert read.status_code == 200 and read.json() == response.json()
        malformed = await client.post(path, json={**request.model_dump(mode="json", by_alias=True), "correct": True})
        assert malformed.status_code == 422 and malformed.headers["cache-control"] == "private, no-store"
        wrong_owner = await client.get(f"{path}/{request.activity_id}", params={"expectedUserId": str(uuid4())})
        assert wrong_owner.status_code == 403 and wrong_owner.headers["cache-control"] == "private, no-store"
        detail = await client.get(f"/api/v1/lessons/{attempt.lesson_id}")
        assert detail.status_code == 200 and detail.json()["activityContentVersion"] == request.content_version


async def test_off_gate_hides_capability_rejects_new_activity_but_keeps_old_receipt(engine, monkeypatch):
    from app.services.lesson_detail_query import get_lesson_detail_data

    attempt = await _seed(engine)
    request = await _request(engine, attempt)
    first = await _record(engine, attempt, request)
    before = await _state(engine, attempt.user_id)
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", False)
    assert await _record(engine, attempt, request) == first
    assert await _read(engine, attempt, request) == first
    new = request.model_copy(update={"activity_id": uuid4()})
    with pytest.raises(LessonServiceError) as exc:
        await _record(engine, attempt, new)
    assert exc.value.status_code == 503
    async with async_sessionmaker(engine)() as db:
        user = await db.get(User, attempt.user_id)
        detail = await get_lesson_detail_data(db, user, lesson_id=attempt.lesson_id)
        assert detail.activity_content_version is None
    assert await _state(engine, attempt.user_id) == before


async def test_quiz_answer_waits_for_user_before_capturing_kst_day_and_goal_time(engine, monkeypatch):
    attempt = await _seed(engine)
    _, body = await _new_quiz(engine, attempt)
    instant = datetime(2026, 11, 1, 14, 59, 59, 999999, tzinfo=UTC)
    entered = asyncio.Event()

    class AdvancingDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return instant.astimezone(tz) if tz else instant.replace(tzinfo=None)

    monkeypatch.setattr(quiz_answer, "datetime", AdvancingDatetime)

    async def waiting(db, user):
        entered.set()
        await lock_study_user(db, user)

    monkeypatch.setattr(quiz_answer, "lock_study_user", waiting)
    async with async_sessionmaker(engine)() as holder:
        user = await holder.get(User, attempt.user_id)
        await lock_study_user(holder, user)
        task = asyncio.create_task(_answer(engine, attempt, body))
        await asyncio.wait_for(entered.wait(), timeout=5)
        instant = datetime(2026, 11, 1, 15, tzinfo=UTC)
        await holder.rollback()
    await task
    state = await _state(engine, attempt.user_id)
    assert state["daily"][0]["date"] == "2026-11-02"
    stored = datetime.fromisoformat(state["quizAnswers"][0]["answered_at"]).replace(tzinfo=UTC)
    assert stored == instant
    async with async_sessionmaker(engine)() as db:
        goal = await get_vocabulary_goal(db, user_id=attempt.user_id, day=date(2026, 11, 2))
    assert goal.answered_count == 1


async def test_kana_session_cutover_tags_only_new_active_snapshots_and_never_response(engine, monkeypatch):
    from app.services.kana_quiz_questions import strip_kana_quiz_answers

    attempt = await _seed(engine)
    body = await _new_kana(engine, attempt, tagged=False)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        old = await db.get(QuizSession, body.session_id)
        questions = deepcopy(old.questions_data)
        monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", False)
        compatible = await kana_quiz_start.create_kana_quiz_session(db, user=user, questions=questions)
        assert "_answerActivityVersion" not in compatible.questions_data[0]
        monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", True)
        active = await kana_quiz_start.create_kana_quiz_session(db, user=user, questions=questions)
        assert active.questions_data[0]["_answerActivityVersion"] == 1
        assert "_answerActivityVersion" not in strip_kana_quiz_answers(active.questions_data)[0]
        assert "_answerActivityVersion" not in questions[0] and "_answerActivityVersion" not in old.questions_data[0]


@pytest.mark.parametrize("source", ["quiz", "kana"])
async def test_answer_commit_response_loss_retry_does_not_repeat_day_or_learning_effects(engine, monkeypatch, source):
    attempt = await _seed(engine)
    if source == "quiz":
        _, body = await _new_quiz(engine, attempt)
    else:
        body = await _new_kana(engine, attempt)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        original = db.commit

        async def lost_response():
            await original()
            raise RuntimeError("committed answer response lost")

        monkeypatch.setattr(db, "commit", lost_response)
        with pytest.raises(RuntimeError, match="committed"):
            if source == "quiz":
                await quiz_answer.submit_quiz_answer(db, user, body)
            else:
                await kana_quiz_answer.submit_kana_quiz_answer(db, user, body)
    before = await _state(engine, attempt.user_id)
    _freeze(monkeypatch, quiz_answer, NOW + timedelta(days=2))
    _freeze(monkeypatch, kana_quiz_answer, NOW + timedelta(days=2))
    if source == "quiz":
        await _answer(engine, attempt, body)
    else:
        await _kana_answer(engine, attempt, body)
    assert await _state(engine, attempt.user_id) == before


async def test_kana_receipt_replays_before_edited_or_deleted_source_without_regrading(engine, monkeypatch):
    attempt = await _seed(engine)
    body = await _new_kana(engine, attempt)
    original = await _kana_answer(engine, attempt, body)
    async with async_sessionmaker(engine)() as db:
        session = await db.get(QuizSession, body.session_id)
        session.questions_data = []
        await db.commit()
    before = await _state(engine, attempt.user_id)
    _freeze(monkeypatch, kana_quiz_answer, NOW + timedelta(days=1))
    assert await _kana_answer(engine, attempt, body) == original
    assert await _state(engine, attempt.user_id) == before
    await _sql(engine, f"DELETE FROM quiz_sessions WHERE id='{body.session_id}'")
    before = await _state(engine, attempt.user_id)
    assert await _kana_answer(engine, attempt, body) == original
    assert await _state(engine, attempt.user_id) == before


@pytest.mark.parametrize(
    "mutation,status",
    [
        ({"options": []}, 400),
        ({"options": [{"id": "a"}, {"id": "a"}]}, 400),
        ({"options": [{"id": ""}, {"id": "a"}]}, 400),
        ({"options": [{"id": 7}, {"id": "a"}]}, 400),
        ({"correctOptionId": ""}, 400),
        ({"correctOptionId": "not-an-option"}, 400),
        ({"options": "invalid"}, 400),
        ({"_answerActivityVersion": 2}, 409),
        ({"_answerActivityVersion": True}, 409),
    ],
    ids=[
        "empty-options",
        "duplicate-id",
        "empty-id",
        "numeric-id",
        "missing-key",
        "foreign-key",
        "invalid-options",
        "unknown-version",
        "boolean-version",
    ],
)
async def test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write(engine, mutation, status):
    attempt = await _seed(engine)
    body = await _new_kana(engine, attempt)
    async with async_sessionmaker(engine)() as db:
        session = await db.get(QuizSession, body.session_id)
        snapshot = deepcopy(session.questions_data)
        snapshot[0].update(mutation)
        session.questions_data = snapshot
        # Python considers True == 1; persist the distinct JSON boolean explicitly.
        from sqlalchemy.orm.attributes import flag_modified

        flag_modified(session, "questions_data")
        await db.commit()
    before = await _state(engine, attempt.user_id)
    before_session = await _scalar(engine, f"SELECT to_jsonb(q) FROM quiz_sessions q WHERE id='{body.session_id}'")
    with pytest.raises(kana_quiz_answer.KanaQuizAnswerServiceError) as exc:
        await _kana_answer(engine, attempt, body)
    assert exc.value.status_code == status
    assert await _state(engine, attempt.user_id) == before
    assert await _scalar(engine, f"SELECT to_jsonb(q) FROM quiz_sessions q WHERE id='{body.session_id}'") == before_session
