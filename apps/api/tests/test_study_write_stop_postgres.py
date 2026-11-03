"""STOP admission on the actual legacy o5 schema, using disposable PG only."""

from copy import deepcopy
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker

from app import dependencies
from app.db.session import get_db
from app.main import app
from app.middleware import study_write_stop as stop
from app.middleware.rate_limit import RateLimitResult
from app.models import DailyMission, DailyProgress, QuizSession
from app.models.enums import JlptLevel, QuizType
from app.models.lesson import Lesson
from app.models.tts import TtsAudio
from app.routers import auth, lessons
from app.services.lesson_submission import submit_lesson_once
from app.utils.date import get_today_kst
from tests.test_lesson_submissions_postgres import _legacy_hash, _metadata, _seed, _seed_legacy_history
from tests.test_lesson_submissions_postgres import engine as engine
from tests.test_lesson_submissions_postgres import migrated_url as migrated_url
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url
from tests.test_study_write_stop import sample_path


async def _snapshot(engine, attempt):
    tables = (
        "quiz_sessions",
        "user_lesson_progress",
        "user_vocab_progress",
        "user_grammar_progress",
        "review_events",
        "daily_progress",
        "daily_missions",
        "lesson_submissions",
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


async def test_stop_pauses_hidden_get_and_mutating_writers_without_changing_legacy_data_or_security(engine, monkeypatch):
    attempt = await _seed(engine)
    cache_id = await _seed_legacy_history(engine, attempt)
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
        db.add(DailyProgress(user_id=attempt.user_id, date=get_today_kst(), words_studied=1))
        db.add(DailyMission(user_id=attempt.user_id, date=get_today_kst(), mission_type="vocab_5", target_count=1))
        await db.commit()
    async with engine.connect() as connection:
        assert await connection.scalar(text("SELECT version_num FROM alembic_version")) == "o5p6q7r8s9t0"
        assert await connection.scalar(text("SELECT to_regclass('public.study_activity_receipts')")) is None
        assert (
            await connection.scalar(
                text("""SELECT count(*) FROM pg_attribute
            WHERE attrelid='daily_progress'::regclass AND attname='activity_recorded' AND NOT attisdropped""")
            )
            == 0
        )
    before, metadata, legacy = await _snapshot(engine, attempt), await _metadata(engine), await _legacy_hash(engine, attempt, cache_id)
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    opened = []

    async def forbidden_db():
        opened.append(True)
        raise AssertionError("Paused request reached a database dependency")

    original_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = forbidden_db
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            for method, path in stop.BLOCKED_ROUTES:
                response = await client.request(method, sample_path(path), content=b"not-even-json")
                assert response.status_code == 503
            for path in ("/api/v1/missions/today", "/api/v1/quiz/incomplete"):
                assert (await client.head(path)).status_code == 503
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(original_overrides)
    assert not opened
    assert await _snapshot(engine, attempt) == before
    assert await _metadata(engine) == metadata
    assert await _legacy_hash(engine, attempt, cache_id) == legacy


async def test_stop_keeps_existing_login_reads_audio_receipts_and_same_submission_retry_after_reopen(engine, monkeypatch):
    from app.models.user import User

    attempt = await _seed(engine)
    cache_id = await _seed_legacy_history(engine, attempt)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        original_receipt = await submit_lesson_once(db, user, lesson_id=attempt.lesson_id, request=attempt.request)
        lesson = await db.get(Lesson, attempt.lesson_id)
        content = deepcopy(lesson.content_jsonb)
        content["reading"]["script"] = [{"speaker": "田中", "voice_id": "male_1", "text": "本を読みます。"}]
        lesson.content_jsonb = content
        audio = await db.get(TtsAudio, cache_id)
        audio.target_id = f"{attempt.lesson_id}:script:0"
        audio.field = "script_line"
        await db.commit()
    before, metadata = await _snapshot(engine, attempt), await _metadata(engine)
    claims = {"sub": str(attempt.user_id), "email": f"{attempt.user_id}@example.test"}
    # Authentication IO is local and synthetic; the existing bearer/dependency
    # and get-or-create-user flow still executes against real legacy PostgreSQL.
    monkeypatch.setattr(auth, "decode_supabase_token", lambda token: claims)
    monkeypatch.setattr(dependencies, "_decode_token", lambda token: claims)

    async def allowed_rate_limit(*args, **kwargs):
        return RateLimitResult(success=True, remaining=1, reset=0)

    async def forbidden_external(*args, **kwargs):
        raise AssertionError("An existing cached audio must not regenerate or upload")

    monkeypatch.setattr(lessons, "rate_limit", allowed_rate_limit)
    monkeypatch.setattr(lessons, "generate_tts", forbidden_external)
    monkeypatch.setattr(lessons, "upload_tts_to_gcs", forbidden_external)

    async def real_db():
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            yield db

    original_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = real_db
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    path = f"/api/v1/lessons/{attempt.lesson_id}/submissions"
    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test", headers={"Authorization": "Bearer isolated-test-token"}
        ) as client:
            login = await client.post("/api/v1/auth/ensure-user")
            assert login.status_code == 200 and login.json()["user"]["id"] == str(attempt.user_id)
            for route in ("/api/v1/user/profile", "/api/v1/stats/dashboard", "/api/v1/stats/history"):
                assert (await client.get(route)).status_code == 200
            receipt = await client.get(f"{path}/{attempt.request.submission_id}", params={"expectedUserId": str(attempt.user_id)})
            assert receipt.status_code == 200 and receipt.json() == original_receipt.model_dump(mode="json", by_alias=True)
            audio = await client.post(f"/api/v1/lessons/{attempt.lesson_id}/script-lines/0/tts")
            assert audio.status_code == 200 and audio.json()["audioUrl"] == "https://example.invalid/existing-lesson.mp3"
            assert (await client.post(path, json=attempt.request.model_dump(mode="json", by_alias=True))).status_code == 503
            assert await _snapshot(engine, attempt) == before
            monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", False)
            replay = await client.post(path, json=attempt.request.model_dump(mode="json", by_alias=True))
            assert replay.status_code == 200 and replay.json() == receipt.json()
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(original_overrides)
    assert await _snapshot(engine, attempt) == before
    assert await _metadata(engine) == metadata
