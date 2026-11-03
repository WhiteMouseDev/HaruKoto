"""Atomic receipt/concurrency/security regressions on disposable PostgreSQL only."""

import asyncio
import hashlib
import importlib.util
import json
from copy import deepcopy
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import pytest
import pytest_asyncio
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import event, func, select, text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models.content import Grammar, Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech
from app.models.lesson import Chapter, Lesson, LessonItemLink, LessonSubmission, UserLessonProgress
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.models.tts import TtsAudio
from app.models.user import User
from app.schemas.lesson import AnswerSubmission, LessonSubmissionRequest
from app.services import lesson_command, lesson_submission
from app.services.lesson_command import LessonServiceError, start_lesson_progress, submit_lesson_attempt
from app.services.lesson_submission import get_lesson_submission, submit_lesson_once
from tests.test_public_access_hardening_postgres import _alembic, _denied, _scalar, _sql
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url

REVISION = "o5p6q7r8s9t0"
MIGRATION = Path(__file__).resolve().parents[1] / f"alembic/versions/{REVISION}_add_lesson_submission_receipts.py"


async def _metadata(engine):
    return await _scalar(
        engine,
        """SELECT jsonb_build_object(
        'objects',(SELECT jsonb_agg(jsonb_build_array(c.oid,c.relname,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity)
                                  ORDER BY c.oid) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                   WHERE n.nspname IN ('public','auth') AND c.relname NOT LIKE '%lesson_submissions%'),
        'defaults',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.oid) FROM pg_default_acl d),
        'guard',(SELECT jsonb_agg(to_jsonb(e) ORDER BY e.oid) FROM pg_event_trigger e),
        'authenticator',(SELECT rolconfig FROM pg_roles WHERE rolname='authenticator'))""",
    )


@pytest_asyncio.fixture(scope="module")
async def migrated_url(isolated_postgres_url):
    # URL comes solely from the existing initdb/pg_ctl fixture, never .env.
    assert isolated_postgres_url.startswith("postgresql+asyncpg://postgres@/postgres?host=/tmp/hk-quiz-")
    engine = create_async_engine(isolated_postgres_url)
    try:
        # A fresh baseline uses timestamp literals; explicitly establish UTC
        # before new migration connections, independent of the developer's TZ.
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
        prior = _alembic(isolated_postgres_url, "upgrade", "n4o5p6q7r8s9")
        assert prior.returncode == 0, prior.stderr
        # Only the disposable fixture freezes its event insertion timestamp.
        # Receipt atomicity must not depend on these historical partitions still
        # containing the wall-clock month when CI runs in a future year.
        await _sql(
            engine,
            "ALTER TABLE public.review_events ALTER COLUMN created_at SET DEFAULT '2026-11-02T01:00:00Z'::timestamptz",
        )
        legacy = await _seed(engine)
        cache_id = await _seed_legacy_history(engine, legacy)
        legacy_hash = await _legacy_hash(engine, legacy, cache_id)
        before = await _metadata(engine)
        upgrade = _alembic(isolated_postgres_url, "upgrade", REVISION)
        assert upgrade.returncode == 0, upgrade.stderr
        assert await _metadata(engine) == before
        assert await _legacy_hash(engine, legacy, cache_id) == legacy_hash
        # Empty-only rollback is safe and must restore all earlier metadata.
        downgrade = _alembic(isolated_postgres_url, "downgrade", "-1")
        assert downgrade.returncode == 0, downgrade.stderr
        assert await _metadata(engine) == before
        assert await _legacy_hash(engine, legacy, cache_id) == legacy_hash
        upgrade = _alembic(isolated_postgres_url, "upgrade", REVISION)
        assert upgrade.returncode == 0, upgrade.stderr
        assert await _metadata(engine) == before
        assert await _legacy_hash(engine, legacy, cache_id) == legacy_hash
        # Receipt migration's historical boundary above remains pinned even as
        # later additive migrations are tested by their own preservation suite.
        current = _alembic(isolated_postgres_url, "upgrade", "head")
        assert current.returncode == 0, current.stderr
    finally:
        await engine.dispose()
    yield isolated_postgres_url


@pytest_asyncio.fixture
async def engine(migrated_url):
    value = create_async_engine(migrated_url, pool_size=20, max_overflow=5)
    try:
        yield value
    finally:
        await value.dispose()


@dataclass
class Attempt:
    user_id: UUID
    lesson_id: UUID
    vocabulary_id: UUID
    grammar_id: UUID
    historical_id: UUID
    request: LessonSubmissionRequest


async def _seed_legacy_history(engine, attempt):
    """Create old auth/learning/due/cache rows while receipt table is absent."""
    cache_id = uuid4()
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        db.add(
            UserLessonProgress(
                user_id=attempt.user_id,
                lesson_id=attempt.lesson_id,
                status="COMPLETED",
                attempts=4,
                score_correct=2,
                score_total=3,
                completed_at=datetime(2026, 10, 30, tzinfo=UTC),
            )
        )
        db.add(
            UserGrammarProgress(
                user_id=attempt.user_id,
                grammar_id=attempt.grammar_id,
                state="REVIEW",
                correct_count=7,
                next_review_at=datetime(2027, 1, 20, tzinfo=UTC),
                updated_at=datetime(2026, 10, 30, tzinfo=UTC),
            )
        )
        db.add(
            TtsAudio(
                id=cache_id,
                target_type="lesson_script_line",
                target_id=f"{attempt.lesson_id}:0",
                text="本を読みます。",
                speed=1,
                provider="elevenlabs",
                model="preserved-model",
                audio_url="https://example.invalid/existing-lesson.mp3",
                field="text",
            )
        )
        await db.execute(
            text("""INSERT INTO review_events
                (user_id,item_type,vocabulary_id,lesson_id,direction,is_correct,response_ms,rating,
                 state_before,state_after,reviewed_on,created_at)
                VALUES(:user,'WORD',:word,:lesson,'JP_KR',true,1300,3,'LEARNING','REVIEW',
                       '2026-10-30','2026-10-30T12:00:00Z')"""),
            {"user": attempt.user_id, "word": attempt.historical_id, "lesson": attempt.lesson_id},
        )
        await db.commit()
    # Existing auth trigger must preserve, rather than overwrite, that public user.
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL ROLE supabase_auth_admin"))
        await connection.execute(
            text('INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES(:id,:email,\'{"name":"기존 로그인"}\')'),
            {"id": attempt.user_id, "email": f"{attempt.user_id}@example.test"},
        )
    return cache_id


async def _legacy_hash(engine, attempt, cache_id):
    async with engine.connect() as connection:
        rows = await connection.scalar(
            text("""SELECT jsonb_build_object(
                'auth',(SELECT to_jsonb(u) FROM auth.users u WHERE id=:user),
                'user',(SELECT to_jsonb(u) FROM public.users u WHERE id=:user),
                'lesson',(SELECT to_jsonb(l) FROM lessons l WHERE id=:lesson),
                'progress',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_lesson_progress p WHERE user_id=:user),
                'words',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_vocab_progress p WHERE user_id=:user),
                'grammar',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_grammar_progress p WHERE user_id=:user),
                'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM review_events e WHERE user_id=:user),
                'audio',(SELECT to_jsonb(t) FROM tts_audio t WHERE id=:audio))"""),
            {"user": attempt.user_id, "lesson": attempt.lesson_id, "audio": cache_id},
        )
    return hashlib.sha256(json.dumps(rows, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


async def _seed(engine) -> Attempt:
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    async with sessions() as db:
        user_id, vocabulary_id, grammar_id, historical_id, lesson_id = (uuid4() for _ in range(5))
        chapter_no = (await db.scalar(select(func.max(Chapter.chapter_no)))) or 0
        lesson_no = (await db.scalar(select(func.max(Lesson.lesson_no)))) or 0
        chapter = Chapter(jlpt_level=JlptLevel.N5, part_no=1, chapter_no=chapter_no + 1, title="제출 검수", is_published=True)
        db.add(User(id=user_id, email=f"{user_id}@example.test", nickname="영수증 검수", updated_at=datetime.now(UTC)))
        db.add(chapter)
        db.add_all(
            [
                Vocabulary(
                    id=item_id,
                    jlpt_level=JlptLevel.N5,
                    word=f"語{item_id}",
                    reading="ご",
                    meaning_ko="말",
                    part_of_speech=PartOfSpeech.NOUN,
                )
                for item_id in (vocabulary_id, historical_id)
            ]
        )
        db.add(Grammar(id=grammar_id, jlpt_level=JlptLevel.N5, pattern=f"です{grammar_id}", meaning_ko="입니다", explanation="설명"))
        await db.flush()
        questions = [
            {"order": 1, "type": "VOCAB_MCQ", "correct_answer": "a", "vocabulary_id": str(vocabulary_id), "explanation": "원래 해설"},
            {"order": 2, "type": "CONTEXT_CLOZE", "correct_answer": "a", "grammar_id": str(grammar_id)},
            {"order": 3, "type": "SENTENCE_REORDER", "correct_order": ["本", "です"], "grammar_id": str(grammar_id)},
        ]
        db.add(
            Lesson(
                id=lesson_id,
                chapter_id=chapter.id,
                jlpt_level=JlptLevel.N5,
                lesson_no=lesson_no + 1,
                chapter_lesson_no=1,
                title="처음 결과 그대로",
                topic="자기소개",
                content_jsonb={"reading": {"script": []}, "questions": questions},
                is_published=True,
            )
        )
        await db.flush()
        db.add_all(
            [
                LessonItemLink(lesson_id=lesson_id, item_type="WORD", vocabulary_id=vocabulary_id, item_order=1),
                LessonItemLink(lesson_id=lesson_id, item_type="GRAMMAR", grammar_id=grammar_id, item_order=1),
                UserVocabProgress(
                    user_id=user_id,
                    vocabulary_id=historical_id,
                    correct_count=11,
                    incorrect_count=2,
                    state="REVIEW",
                    next_review_at=datetime.now(UTC) + timedelta(days=37),
                    introduced_by="QUIZ",
                    updated_at=datetime.now(UTC),
                ),
            ]
        )
        await db.commit()
    request = LessonSubmissionRequest.model_validate(
        {
            "submissionId": str(uuid4()),
            "expectedUserId": str(user_id),
            "answers": [
                {"order": 1, "selectedAnswer": "a", "responseMs": 1200},
                {"order": 2, "selectedAnswer": "a", "responseMs": 1800},
                {"order": 3, "submittedOrder": ["本", "です"], "responseMs": 2200},
            ],
        }
    )
    return Attempt(user_id, lesson_id, vocabulary_id, grammar_id, historical_id, request)


async def _submit(engine, attempt, request=None):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        assert user is not None
        return await submit_lesson_once(db, user, lesson_id=attempt.lesson_id, request=request or attempt.request)


async def _get(engine, attempt):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        assert user is not None
        return await get_lesson_submission(
            db, user, lesson_id=attempt.lesson_id, submission_id=attempt.request.submission_id, expected_user_id=attempt.user_id
        )


async def _state(engine, attempt):
    async with engine.connect() as connection:
        return await connection.scalar(
            text("""SELECT jsonb_build_object(
                'user',(SELECT to_jsonb(u) FROM users u WHERE id=:user),
                'daily',(SELECT jsonb_agg(to_jsonb(d) ORDER BY date) FROM daily_progress d WHERE user_id=:user),
                'progress',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_lesson_progress p WHERE user_id=:user),
                'words',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_vocab_progress p WHERE user_id=:user),
                'grammar',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM user_grammar_progress p WHERE user_id=:user),
                'receipts',(SELECT jsonb_agg(to_jsonb(p) ORDER BY submission_id) FROM lesson_submissions p WHERE user_id=:user),
                'events',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM review_events p WHERE user_id=:user))"""),
            {"user": attempt.user_id},
        )


async def test_receipt_migration_is_private_preserves_auth_and_fails_on_existing_object(engine):
    assert await _scalar(engine, "SELECT relrowsecurity FROM pg_class WHERE oid='lesson_submissions'::regclass") is True
    assert await _scalar(engine, "SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='lesson_submissions'::regclass") == "postgres"
    assert await _scalar(engine, "SELECT count(*) FROM pg_policy WHERE polrelid='lesson_submissions'::regclass") == 0
    assert await _scalar(engine, "SELECT count(*) FROM pg_constraint WHERE conrelid='lesson_submissions'::regclass AND contype='f'") == 1
    for role in ("anon", "authenticated", "service_role"):
        assert not await _scalar(engine, f"SELECT has_table_privilege('{role}','lesson_submissions','SELECT,INSERT,UPDATE,DELETE')")
        assert not await _scalar(
            engine, f"SELECT has_any_column_privilege('{role}','lesson_submissions','SELECT,INSERT,UPDATE,REFERENCES')"
        )
        await _denied(engine, role, "SELECT response_body FROM lesson_submissions LIMIT 0")
    spec = importlib.util.spec_from_file_location("lesson_receipts_migration", MIGRATION)
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    def apply(connection):
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

    before = await _metadata(engine)
    with pytest.raises(DBAPIError, match="already exists; refusing to overwrite"):
        async with engine.begin() as connection:
            await connection.run_sync(apply)
    assert await _metadata(engine) == before
    # Existing managed auth trigger still creates the server-owned user.
    user_id = uuid4()
    async with engine.begin() as connection:
        await connection.execute(text("SET LOCAL ROLE supabase_auth_admin"))
        await connection.execute(
            text("INSERT INTO auth.users(id,email) VALUES(:id,:email)"), {"id": user_id, "email": f"{user_id}@test.invalid"}
        )
    assert await _scalar(engine, f"SELECT count(*) FROM public.users WHERE id='{user_id}'") == 1


async def test_same_key_after_lost_response_and_separate_connections_never_reapplies(engine):
    attempt = await _seed(engine)
    before = await _state(engine, attempt)
    first = await _submit(engine, attempt)
    after = await _state(engine, attempt)
    for _ in range(3):
        assert (await _get(engine, attempt)).model_dump(mode="json") == first.model_dump(mode="json")
        assert (await _submit(engine, attempt)).model_dump(mode="json") == first.model_dump(mode="json")
    assert await _state(engine, attempt) == after
    historical_before = next(p for p in before["words"] if p["vocabulary_id"] == str(attempt.historical_id))
    assert next(p for p in after["words"] if p["vocabulary_id"] == str(attempt.historical_id)) == historical_before
    assert len(after["receipts"]) == 1 and len(after["events"]) == 3
    assert after["progress"][0]["attempts"] == 1
    assert after["grammar"][0]["correct_count"] == 2  # Preserve repeated per-question grammar policy.
    assert (first.result.score_correct, first.result.score_total, first.result.srs_items_registered) == (3, 3, 2)


async def test_twenty_concurrent_first_submissions_commit_one_attempt(engine):
    attempt = await _seed(engine)
    results = await asyncio.gather(*[_submit(engine, attempt) for _ in range(20)])
    assert all(r.model_dump(mode="json") == results[0].model_dump(mode="json") for r in results)
    state = await _state(engine, attempt)
    assert len(state["receipts"]) == 1 and len(state["events"]) == 3
    assert state["progress"][0]["attempts"] == 1


@pytest.mark.parametrize("mutation", ["answer", "order", "time", "lesson"])
async def test_same_key_conflict_changes_no_learning_rows(engine, mutation):
    attempt = await _seed(engine)
    await _submit(engine, attempt)
    before = await _state(engine, attempt)
    raw = attempt.request.model_dump(mode="json", by_alias=True)
    lesson_id = attempt.lesson_id
    if mutation == "answer":
        raw["answers"][0]["selectedAnswer"] = "b"
    elif mutation == "order":
        raw["answers"].reverse()
    elif mutation == "time":
        raw["answers"][0]["responseMs"] += 1
    else:
        lesson_id = uuid4()
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        with pytest.raises(LessonServiceError) as error:
            await submit_lesson_once(db, user, lesson_id=lesson_id, request=LessonSubmissionRequest.model_validate(raw))
        assert error.value.status_code == 409
    assert await _state(engine, attempt) == before


async def test_different_id_is_real_relearning_and_legacy_still_uses_same_policy(engine):
    attempt = await _seed(engine)
    await _submit(engine, attempt)
    raw = attempt.request.model_dump(mode="json", by_alias=True)
    raw["submissionId"] = str(uuid4())
    await _submit(engine, attempt, LessonSubmissionRequest.model_validate(raw))
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        await submit_lesson_attempt(
            db, user, lesson_id=attempt.lesson_id, answers=[AnswerSubmission.model_validate(a) for a in raw["answers"]]
        )
    state = await _state(engine, attempt)
    assert state["progress"][0]["attempts"] == 3
    assert len(state["receipts"]) == 2 and len(state["events"]) == 9


async def test_get_race_does_not_treat_uncommitted_absence_as_a_new_attempt(engine, monkeypatch):
    attempt = await _seed(engine)
    applying, release = asyncio.Event(), asyncio.Event()
    original = lesson_submission.apply_lesson_attempt

    async def paused(*args, **kwargs):
        applying.set()
        await release.wait()
        return await original(*args, **kwargs)

    monkeypatch.setattr(lesson_submission, "apply_lesson_attempt", paused)
    first = asyncio.create_task(_submit(engine, attempt))
    await asyncio.wait_for(applying.wait(), timeout=5)
    try:
        with pytest.raises(LessonServiceError) as error:
            await _get(engine, attempt)
        assert error.value.status_code == 404
        second = asyncio.create_task(_submit(engine, attempt))
    finally:
        release.set()
    result, replay = await asyncio.gather(first, second)
    assert result.model_dump(mode="json") == replay.model_dump(mode="json")
    assert (await _state(engine, attempt))["progress"][0]["attempts"] == 1


@pytest.mark.parametrize("failure", ["registration", "second_answer", "after_apply", "receipt_flush", "precommit"])
async def test_failed_processing_rolls_back_receipt_progress_srs_and_events(engine, monkeypatch, failure):
    attempt = await _seed(engine)
    before = await _state(engine, attempt)
    original_apply = lesson_submission.apply_lesson_attempt
    original_register = lesson_command.register_items_from_lesson
    original_answer = lesson_command.process_answer
    calls = 0

    async def fail_registration(*args, **kwargs):
        await original_register(*args, **kwargs)
        raise RuntimeError("injected registration failure")

    async def fail_second(*args, **kwargs):
        nonlocal calls
        calls += 1
        value = await original_answer(*args, **kwargs)
        if calls == 2:
            raise RuntimeError("injected answer/event failure")
        return value

    async def fail_after(*args, **kwargs):
        await original_apply(*args, **kwargs)
        raise RuntimeError("injected after progress failure")

    if failure == "registration":
        monkeypatch.setattr(lesson_command, "register_items_from_lesson", fail_registration)
    elif failure == "second_answer":
        monkeypatch.setattr(lesson_command, "process_answer", fail_second)
    elif failure == "after_apply":
        monkeypatch.setattr(lesson_submission, "apply_lesson_attempt", fail_after)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        if failure == "precommit":
            monkeypatch.setattr(db, "commit", AsyncMock(side_effect=RuntimeError("injected precommit failure")))
        if failure == "receipt_flush":

            def fail_receipt(session, _flush_context, _instances):
                if any(isinstance(item, LessonSubmission) for item in session.new):
                    raise RuntimeError("injected receipt flush failure")

            event.listen(db.sync_session, "before_flush", fail_receipt)
        with pytest.raises(LessonServiceError) as error:
            await submit_lesson_once(db, user, lesson_id=attempt.lesson_id, request=attempt.request)
        assert error.value.status_code in (500, 503)
    assert await _state(engine, attempt) == before


async def test_successful_commit_with_lost_ack_recovers_original_result(engine, monkeypatch):
    attempt = await _seed(engine)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        original_commit = db.commit

        async def commit_but_lose_ack():
            await original_commit()
            raise RuntimeError("injected lost commit acknowledgement")

        monkeypatch.setattr(db, "commit", commit_but_lose_ack)
        with pytest.raises(LessonServiceError) as error:
            await submit_lesson_once(db, user, lesson_id=attempt.lesson_id, request=attempt.request)
        assert error.value.status_code == 503
    before = await _state(engine, attempt)
    result = await _get(engine, attempt)
    assert (await _submit(engine, attempt)).model_dump(mode="json") == result.model_dump(mode="json")
    assert await _state(engine, attempt) == before


async def test_replay_survives_edit_unpublish_and_content_deletion(engine):
    attempt = await _seed(engine)
    first = await _submit(engine, attempt)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        lesson = await db.get(Lesson, attempt.lesson_id)
        lesson.title = "새 콘텐츠와 음원"
        lesson.is_published = False
        content = deepcopy(lesson.content_jsonb)
        content["reading"]["audio_url"] = "https://example.invalid/new.mp3"
        content["questions"][0]["correct_answer"] = "b"
        content["questions"][0]["explanation"] = "새 해설"
        lesson.content_jsonb = content
        await db.commit()
    assert (await _get(engine, attempt)).model_dump(mode="json") == first.model_dump(mode="json")
    assert (await _submit(engine, attempt)).model_dump(mode="json") == first.model_dump(mode="json")
    async with engine.begin() as connection:
        await connection.execute(text("DELETE FROM lessons WHERE id=:id"), {"id": attempt.lesson_id})
    assert (await _get(engine, attempt)).model_dump(mode="json") == first.model_dump(mode="json")
    assert (await _submit(engine, attempt)).model_dump(mode="json") == first.model_dump(mode="json")


async def test_new_and_legacy_start_share_user_mutex_for_first_progress(engine):
    attempt = await _seed(engine)

    async def start():
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            user = await db.get(User, attempt.user_id)
            return await start_lesson_progress(db, user, lesson_id=attempt.lesson_id)

    await asyncio.gather(start(), _submit(engine, attempt))
    state = await _state(engine, attempt)
    assert len(state["progress"]) == 1 and state["progress"][0]["attempts"] == 1


async def test_user_mutex_timeout_keeps_id_unprocessed_and_all_learning_unchanged(engine):
    attempt = await _seed(engine)
    before = await _state(engine, attempt)
    async with async_sessionmaker(engine, expire_on_commit=False)() as holder:
        await holder.scalar(select(User.id).where(User.id == attempt.user_id).with_for_update(key_share=True))
        with pytest.raises(LessonServiceError) as error:
            await _submit(engine, attempt)
        assert error.value.status_code == 503
        assert await _state(engine, attempt) == before
        await holder.rollback()
    # The same original ID is valid once the competing transaction releases.
    await _submit(engine, attempt)
    assert (await _state(engine, attempt))["progress"][0]["attempts"] == 1


async def test_other_users_continue_while_one_users_submission_is_in_flight(engine, monkeypatch):
    first, second = await _seed(engine), await _seed(engine)
    entered, release = asyncio.Event(), asyncio.Event()
    original = lesson_submission.apply_lesson_attempt

    async def pause_first(db, user, **kwargs):
        if user.id == first.user_id:
            entered.set()
            await release.wait()
        return await original(db, user, **kwargs)

    monkeypatch.setattr(lesson_submission, "apply_lesson_attempt", pause_first)
    task = asyncio.create_task(_submit(engine, first))
    await asyncio.wait_for(entered.wait(), timeout=5)
    try:
        second_result = await asyncio.wait_for(_submit(engine, second), timeout=1.5)
        assert second_result.result.score_correct == 3
        assert not task.done()
    finally:
        release.set()
        await task


async def test_other_users_cannot_read_receipts_and_owner_assertion_writes_nothing(engine):
    first, second = await _seed(engine), await _seed(engine)
    await _submit(engine, first)
    before = await _state(engine, second)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, second.user_id)
        with pytest.raises(LessonServiceError) as error:
            await get_lesson_submission(
                db, user, lesson_id=first.lesson_id, submission_id=first.request.submission_id, expected_user_id=second.user_id
            )
        assert error.value.status_code == 404
        with pytest.raises(LessonServiceError) as error:
            await submit_lesson_once(db, user, lesson_id=first.lesson_id, request=first.request)
        assert error.value.status_code == 403
    assert await _state(engine, second) == before


async def test_populated_receipts_block_destructive_downgrade(engine, migrated_url):
    attempt = await _seed(engine)
    await _submit(engine, attempt)
    before = await _state(engine, attempt)
    spec = importlib.util.spec_from_file_location("receipt_downgrade_guard", MIGRATION)
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    head_before = await _scalar(engine, "SELECT version_num FROM alembic_version")

    def downgrade(connection):
        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()

    with pytest.raises(DBAPIError, match="Completed lesson receipts exist"):
        async with engine.begin() as connection:
            await connection.run_sync(downgrade)
    assert await _state(engine, attempt) == before
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == head_before
