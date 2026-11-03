"""Integrated q7 ORM/receipts/credit override with STOP on disposable PostgreSQL.

The original o5-only proof remains on codex/legacy-study-write-stop. These are
new feature-schema proofs, not a re-labeled version assertion of that evidence.
"""

import asyncio
from copy import deepcopy
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker

from app import dependencies
from app.db.session import get_db
from app.main import app
from app.middleware import study_write_stop as stop
from app.middleware.rate_limit import RateLimitResult
from app.models import DailyMission, QuizSession
from app.models.enums import JlptLevel, QuizType
from app.models.lesson import Lesson
from app.models.tts import TtsAudio
from app.models.user import User
from app.routers import auth, lessons
from app.services import lesson_study_activity, lesson_submission, study_day_recording
from app.services.lesson_submission import submit_lesson_once
from app.utils.date import get_today_kst
from tests.test_lesson_study_day_postgres import RUNTIME_REVISION, _record, _request, _seed
from tests.test_lesson_study_day_postgres import engine as engine
from tests.test_lesson_study_day_postgres import study_day_database as study_day_database
from tests.test_lesson_submissions_postgres import _legacy_hash, _metadata, _seed_legacy_history
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url
from tests.test_study_write_stop import sample_path


async def _snapshot(engine, attempt):
    tables = (
        "quiz_sessions",
        "user_lesson_progress",
        "user_vocab_progress",
        "user_grammar_progress",
        "user_kana_progress",
        "review_events",
        "daily_progress",
        "daily_missions",
        "lesson_submissions",
        "study_activity_receipts",
        "user_achievements",
    )
    async with engine.connect() as connection:
        result = {
            name: await connection.scalar(
                text(f"SELECT jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text) FROM public.{name} t WHERE user_id=:uid"),
                {"uid": attempt.user_id},
            )
            for name in tables
        }
        result["user"] = await connection.scalar(text("SELECT to_jsonb(u) FROM public.users u WHERE id=:uid"), {"uid": attempt.user_id})
        result["auth"] = await connection.scalar(text("SELECT to_jsonb(u) FROM auth.users u WHERE id=:uid"), {"uid": attempt.user_id})
        result["audio"] = await connection.scalar(text("SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM tts_audio t"))
        result["answers"] = await connection.scalar(
            text("""SELECT jsonb_agg(to_jsonb(a) ORDER BY a.id) FROM quiz_answers a
                    JOIN quiz_sessions q ON a.session_id=q.id WHERE q.user_id=:uid"""),
            {"uid": attempt.user_id},
        )
        return result


async def _security(engine):
    # Includes new activity receipt owner/ACL/RLS and marker column permissions,
    # as well as preserved Data API authenticator role config and default ACLs.
    value = await _metadata(engine)
    async with engine.connect() as connection:
        value["columns"] = await connection.scalar(
            text("""SELECT jsonb_agg(jsonb_build_array(a.attrelid,a.attname,a.attacl) ORDER BY a.attrelid,a.attnum)
                    FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
                    JOIN pg_namespace n ON n.oid=c.relnamespace
                    WHERE n.nspname IN ('public','auth') AND a.attnum>0 AND NOT a.attisdropped""")
        )
        value["receipt_security"] = await connection.scalar(
            text("""SELECT jsonb_agg(jsonb_build_array(c.oid,c.relname,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity)
                    ORDER BY c.oid) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                    WHERE n.nspname='public' AND (c.relname LIKE '%lesson_submissions%' OR c.relname LIKE '%study_activity%')""")
        )
        value["policies"] = await connection.scalar(text("SELECT jsonb_agg(to_jsonb(p) ORDER BY oid) FROM pg_policy p"))
        assert "pgrst.db_schemas=pgrst_no_exposed_schemas" in value["authenticator"]
        assert await connection.scalar(text("SELECT version_num FROM alembic_version")) == RUNTIME_REVISION
    return value


def _local_claims(monkeypatch, attempt):
    # Synthetic claims replace only external signature IO. Existing bearer and
    # account lookup dependencies run against disposable PG, never Supabase.
    claims = {"sub": str(attempt.user_id), "email": f"{attempt.user_id}@example.test"}
    monkeypatch.setattr(auth, "decode_supabase_token", lambda token: claims)
    monkeypatch.setattr(dependencies, "_decode_token", lambda token: claims)


def _database_override(engine):
    async def real_db():
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            yield db

    return real_db


@pytest.mark.parametrize("recognition", [False, True], ids=["feature-off", "feature-on"])
async def test_p6_stop_preserves_existing_markers_receipts_history_and_security(engine, monkeypatch, recognition):
    attempt = await _seed(engine)
    cache_id = await _seed_legacy_history(engine, attempt)
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", True)
    await _record(engine, attempt)
    async with async_sessionmaker(engine)() as db:
        db.add(
            QuizSession(
                id=uuid4(),
                user_id=attempt.user_id,
                quiz_type=QuizType.VOCABULARY,
                jlpt_level=JlptLevel.N5,
                total_questions=1,
                started_at=datetime.now(UTC) - timedelta(days=3),
                questions_data=[],
            )
        )
        db.add(DailyMission(user_id=attempt.user_id, date=get_today_kst(), mission_type="vocab_5", target_count=1))
        await db.commit()
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", recognition)
    before, metadata, legacy = await _snapshot(engine, attempt), await _security(engine), await _legacy_hash(engine, attempt, cache_id)
    assert len(before["study_activity_receipts"]) == 1 and before["daily_progress"][0]["activity_recorded"] is True
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    opened = []

    async def forbidden_db():
        opened.append(True)
        raise AssertionError("Paused request reached a database dependency")

    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = forbidden_db
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            for method, path in stop.BLOCKED_ROUTES:
                response = await client.request(method, sample_path(path), content=b"not-even-json")
                assert response.status_code == 503 and response.json() == {"detail": stop.STOP_MESSAGE}
            for path in ("/api/v1/missions/today", "/api/v1/quiz/incomplete"):
                assert (await client.head(path)).status_code == 503
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)
    assert not opened
    assert await _snapshot(engine, attempt) == before
    assert await _security(engine) == metadata
    assert await _legacy_hash(engine, attempt, cache_id) == legacy


@pytest.mark.parametrize("recognition", [False, True], ids=["feature-off", "feature-on"])
async def test_p6_stop_allows_login_audio_receipt_get_and_reopens_same_activity_and_submission_ids(engine, monkeypatch, recognition):
    attempt = await _seed(engine)
    cache_id = await _seed_legacy_history(engine, attempt)
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", True)
    activity = await _request(engine, attempt)
    original_activity = await _record(engine, attempt, activity)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        original_submission = await submit_lesson_once(db, user, lesson_id=attempt.lesson_id, request=attempt.request)
        lesson = await db.get(Lesson, attempt.lesson_id)
        content = deepcopy(lesson.content_jsonb)
        content["reading"]["script"] = [{"speaker": "田中", "voice_id": "male_1", "text": "本を読みます。"}]
        lesson.content_jsonb = content
        audio = await db.get(TtsAudio, cache_id)
        audio.target_id = f"{attempt.lesson_id}:script:0"
        audio.field = "script_line"
        await db.commit()
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", recognition)
    before, metadata = await _snapshot(engine, attempt), await _security(engine)
    _local_claims(monkeypatch, attempt)

    async def allowed_rate_limit(*args, **kwargs):
        return RateLimitResult(success=True, remaining=1, reset=0)

    async def forbidden_external(*args, **kwargs):
        raise AssertionError("An existing cached audio must not regenerate or upload")

    monkeypatch.setattr(lessons, "rate_limit", allowed_rate_limit)
    monkeypatch.setattr(lessons, "generate_tts", forbidden_external)
    monkeypatch.setattr(lessons, "upload_tts_to_gcs", forbidden_external)
    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = _database_override(engine)
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    submission_path = f"/api/v1/lessons/{attempt.lesson_id}/submissions"
    activity_path = f"/api/v1/lessons/{attempt.lesson_id}/study-activities"
    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test", headers={"Authorization": "Bearer isolated-test-token"}
        ) as client:
            login = await client.post("/api/v1/auth/ensure-user")
            assert login.status_code == 200 and login.json()["user"]["id"] == str(attempt.user_id)
            for path in ("/api/v1/user/profile", "/api/v1/stats/dashboard", "/api/v1/stats/history"):
                assert (await client.get(path)).status_code == 200
            for path, key, original, request in (
                (submission_path, attempt.request.submission_id, original_submission, attempt.request),
                (activity_path, activity.activity_id, original_activity, activity),
            ):
                receipt = await client.get(f"{path}/{key}", params={"expectedUserId": str(attempt.user_id)})
                assert receipt.status_code == 200 and receipt.json() == original.model_dump(mode="json", by_alias=True)
                assert receipt.headers["cache-control"] == "private, no-store"
                denied = await client.get(f"{path}/{key}", params={"expectedUserId": str(uuid4())})
                assert denied.status_code == 403
                assert (await client.post(path, json=request.model_dump(mode="json", by_alias=True))).status_code == 503
            audio = await client.post(f"/api/v1/lessons/{attempt.lesson_id}/script-lines/0/tts")
            assert audio.status_code == 200 and audio.json()["audioUrl"] == "https://example.invalid/existing-lesson.mp3"
            assert await _snapshot(engine, attempt) == before
            monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", False)
            for path, original, request in (
                (submission_path, original_submission, attempt.request),
                (activity_path, original_activity, activity),
            ):
                replay = await client.post(path, json=request.model_dump(mode="json", by_alias=True))
                assert replay.status_code == 200 and replay.json() == original.model_dump(mode="json", by_alias=True)
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)
    assert await _snapshot(engine, attempt) == before
    assert await _security(engine) == metadata


async def test_p6_stop_rejects_before_mutex_then_reopens_concurrent_activity_and_submission_retries_once(engine, monkeypatch):
    attempt = await _seed(engine)
    activity = await _request(engine, attempt)
    before, security = await _snapshot(engine, attempt), await _security(engine)
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", True)
    _local_claims(monkeypatch, attempt)
    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = _database_override(engine)
    paths = (
        (f"/api/v1/lessons/{attempt.lesson_id}/study-activities", activity),
        (f"/api/v1/lessons/{attempt.lesson_id}/submissions", attempt.request),
    )
    entered = asyncio.Event()
    lock_calls = []

    # Activity calls the shared module directly; retain a stable original to
    # observe its mutex too without recursively wrapping the implementation.
    original_lock = study_day_recording.lock_study_user

    async def shared_observed_lock(db, user):
        lock_calls.append(user.id)
        if len(lock_calls) == 4:
            entered.set()
        await original_lock(db, user)

    monkeypatch.setattr(lesson_study_activity.study_day_recording, "lock_study_user", shared_observed_lock)
    # Submission must call the stable implementation, not the patched shared
    # function, otherwise one real lock attempt would count twice.
    monkeypatch.setattr(lesson_submission, "lock_study_user", shared_observed_lock)
    pending = []
    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test", headers={"Authorization": "Bearer isolated-test-token"}
        ) as client:
            async with async_sessionmaker(engine, expire_on_commit=False)() as holder:
                user = await holder.get(User, attempt.user_id)
                await original_lock(holder, user)
                monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
                for path, body in paths:
                    response = await asyncio.wait_for(client.post(path, json=body.model_dump(mode="json", by_alias=True)), timeout=1)
                    assert response.status_code == 503 and response.json() == {"detail": stop.STOP_MESSAGE}
                assert not lock_calls and await _snapshot(engine, attempt) == before
                monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", False)
                pending = [
                    asyncio.create_task(client.post(path, json=body.model_dump(mode="json", by_alias=True)))
                    for path, body in paths
                    for _ in range(2)
                ]
                await asyncio.wait_for(entered.wait(), timeout=1)
                assert not any(task.done() for task in pending)
                assert await _snapshot(engine, attempt) == before
                await holder.rollback()
            responses = await asyncio.wait_for(asyncio.gather(*pending), timeout=10)
            assert all(response.status_code == 200 for response in responses)
            assert responses[0].json() == responses[1].json() and responses[2].json() == responses[3].json()
            once = await _snapshot(engine, attempt)
            assert len(once["study_activity_receipts"]) == 1 and len(once["lesson_submissions"]) == 1
            assert len(once["user_lesson_progress"]) == 1 and once["user_lesson_progress"][0]["attempts"] == 1
            assert len(once["daily_progress"]) == 1 and once["daily_progress"][0]["activity_recorded"] is True
            assert once["user"]["streak_count"] == 1 and once["user"]["experience_points"] == 0
            # Lesson activity does not inflate the daily vocabulary-answer goal.
            assert once["answers"] is None and once["daily_progress"][0]["words_studied"] == 0
            for path, body in paths:
                assert (await client.post(path, json=body.model_dump(mode="json", by_alias=True))).status_code == 200
            assert await _snapshot(engine, attempt) == once
    finally:
        for task in pending:
            if not task.done():
                task.cancel()
        if pending:
            await asyncio.gather(*pending, return_exceptions=True)
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)
    assert await _security(engine) == security
