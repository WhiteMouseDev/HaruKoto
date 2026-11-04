"""Card progress receipts on a disposable full Alembic PostgreSQL schema."""

import asyncio
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import event, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models import KanaCharacter, StudyActivityReceipt
from app.models.enums import KanaType
from app.models.user import User
from app.schemas.kana import KanaProgressActivityRequest, KanaProgressRecord
from app.services import kana_progress
from app.services import kana_progress_activity as service
from app.services.lesson_command import LessonServiceError
from app.services.lesson_study_activity import get_lesson_activity
from app.services.vocabulary_goal import get_vocabulary_goal
from tests.test_lesson_study_day_postgres import NOW, _freeze, _kana_answer, _metadata, _new_kana, _record, _seed, _state
from tests.test_lesson_study_day_postgres import study_day_database as study_day_database
from tests.test_public_access_hardening_postgres import _alembic, _denied, _scalar
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url

REVISION = "r8s9t0u1v2w3"
PREVIOUS = "q7r8s9t0u1v2"


async def _private_metadata(engine):
    async with engine.connect() as connection:
        return await connection.scalar(
            text("""SELECT jsonb_build_object(
              'owner',c.relowner,'acl',c.relacl::text,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,
              'columns',(SELECT jsonb_agg(to_jsonb(a) ORDER BY a.attnum) FROM pg_attribute a
                WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped),
              'indexes',(SELECT jsonb_agg(pg_get_indexdef(i.indexrelid) ORDER BY i.indexrelid) FROM pg_index i WHERE i.indrelid=c.oid),
              'policies',(SELECT jsonb_agg(to_jsonb(p)) FROM pg_policy p WHERE p.polrelid=c.oid),
              'authenticator',(SELECT rolconfig FROM pg_roles WHERE rolname='authenticator'),
              'exposedSchema',(SELECT count(*) FROM pg_namespace WHERE nspname='pgrst_no_exposed_schemas')
            ) FROM pg_class c WHERE c.oid='public.study_activity_receipts'::regclass""")
        )


@pytest_asyncio.fixture(scope="module")
async def card_database(study_day_database):
    url, historical = study_day_database
    engine = create_async_engine(url)
    try:
        existing = await _seed(engine)
        await _record(engine, existing)
        answer = await _new_kana(engine, existing)
        await _kana_answer(engine, existing, answer)
        before_history = await _state(engine, historical.user_id)
        before_receipts = await _state(engine, existing.user_id)
        before_security = await _metadata(engine)
        private = await _private_metadata(engine)
        # Round trip with actual old receipt kinds populated: no backfill,
        # replacement of accepted evidence, ACL/RLS changes, or new schema items.
        for action in [("upgrade", REVISION), ("downgrade", PREVIOUS), ("upgrade", REVISION)]:
            result = _alembic(url, *action)
            assert result.returncode == 0, result.stderr
            assert await _state(engine, historical.user_id) == before_history
            assert await _state(engine, existing.user_id) == before_receipts
            assert await _metadata(engine) == before_security
            assert await _private_metadata(engine) == private
        yield url
    finally:
        await engine.dispose()


@pytest_asyncio.fixture
async def engine(card_database):
    value = create_async_engine(card_database, pool_size=12)
    try:
        yield value
    finally:
        await value.dispose()


@pytest.fixture(autouse=True)
def freeze_time(monkeypatch):
    _freeze(monkeypatch, service, NOW)


async def _new_activity(engine):
    attempt = await _seed(engine)
    kana_id = uuid4()
    async with async_sessionmaker(engine)() as db:
        db.add(
            KanaCharacter(
                id=kana_id,
                kana_type=KanaType.HIRAGANA,
                character=str(kana_id),
                romaji="a",
                pronunciation="a",
                row="a",
                column="a",
                stroke_count=1,
            )
        )
        await db.commit()
    return attempt, KanaProgressActivityRequest(activity_id=uuid4(), expected_user_id=attempt.user_id, kana_id=kana_id)


async def _call(engine, request, *, owner=None):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, owner or request.expected_user_id)
        return await service.record_kana_progress_activity(db, user, request)


async def test_card_migration_preserves_private_boundary_and_existing_sources(engine):
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == REVISION
    definition = await _scalar(engine, "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='ck_study_activity_source_kind'")
    assert all(kind in definition for kind in ["LESSON_ANSWER", "KANA_QUIZ_ANSWER", "KANA_CARD_PROGRESS"])
    for role in ["anon", "authenticated", "service_role"]:
        await _denied(engine, role, "SELECT * FROM study_activity_receipts LIMIT 0")
        assert not await _scalar(engine, f"SELECT has_table_privilege('{role}','study_activity_receipts','SELECT,INSERT,UPDATE,DELETE')")
    assert await _scalar(engine, "SELECT count(*) FROM pg_policy WHERE polrelid='study_activity_receipts'::regclass") == 0


async def test_first_card_activity_preserves_existing_policy_goal_srs_and_user_streak(engine):
    attempt, request = await _new_activity(engine)
    before = await _state(engine, attempt.user_id)
    security = await _private_metadata(engine)
    async with async_sessionmaker(engine)() as db:
        goal = await get_vocabulary_goal(db, user_id=attempt.user_id, day=NOW.date())
    response = await _call(engine, request)
    after = await _state(engine, attempt.user_id)
    assert response.ok is True and response.processed_at == NOW and response.activity_id == request.activity_id
    assert len(after["activities"]) == 1 and after["activities"][0]["source_kind"] == "KANA_CARD_PROGRESS"
    assert after["kana"][0]["correct_count"] == 1 and after["kana"][0]["streak"] == 1
    assert after["daily"][0]["kana_learned"] == 1 and after["daily"][0]["study_day_credited"] is True
    assert after["daily"][0]["activity_recorded"] is False and after["daily"][0]["xp_earned"] == 0
    for key in ["user", "progress", "words", "grammar", "receipts", "quizAnswers", "events"]:
        assert after[key] == before[key]
    async with async_sessionmaker(engine)() as db:
        assert await get_vocabulary_goal(db, user_id=attempt.user_id, day=NOW.date()) == goal
    assert await _private_metadata(engine) == security


async def test_eight_concurrent_identical_card_activities_apply_once(engine):
    attempt, request = await _new_activity(engine)
    responses = await asyncio.gather(*[_call(engine, request) for _ in range(8)])
    assert all(result == responses[0] for result in responses)
    state = await _state(engine, attempt.user_id)
    assert len(state["activities"]) == 1 and state["kana"][0]["correct_count"] == 1
    assert state["daily"][0]["kana_learned"] == 1


@pytest.mark.parametrize("days", [1, 31], ids=["next-kst-day", "next-month"])
async def test_card_replay_does_not_create_later_day_or_change_first_timestamp(engine, monkeypatch, days):
    attempt, request = await _new_activity(engine)
    first = datetime(2026, 11, 30, 14, 59, 59, 999999, tzinfo=UTC)
    _freeze(monkeypatch, service, first)
    response = await _call(engine, request)
    before = await _state(engine, attempt.user_id)
    assert response.processed_at.microsecond == 999000
    assert before["daily"][0]["date"] == "2026-11-30"
    _freeze(monkeypatch, service, first + timedelta(days=days, seconds=1))
    assert await _call(engine, request) == response
    assert await _state(engine, attempt.user_id) == before


async def test_same_character_distinct_intentional_activity_ids_keep_legacy_increment(engine):
    attempt, request = await _new_activity(engine)
    await _call(engine, request)
    await _call(engine, request.model_copy(update={"activity_id": uuid4()}))
    state = await _state(engine, attempt.user_id)
    assert len(state["activities"]) == 2 and state["kana"][0]["correct_count"] == 2
    assert state["daily"][0]["kana_learned"] == 2


async def test_changed_card_payload_is_409_without_other_writes(engine):
    attempt, request = await _new_activity(engine)
    await _call(engine, request)
    before = await _state(engine, attempt.user_id)
    with pytest.raises(service.KanaProgressActivityError) as error:
        await _call(engine, request.model_copy(update={"kana_id": uuid4()}))
    assert error.value.status_code == 409 and await _state(engine, attempt.user_id) == before


@pytest.mark.parametrize("kind", ["LESSON_ANSWER", "KANA_QUIZ_ANSWER"])
async def test_existing_other_receipt_kind_is_409_and_preserved(engine, kind):
    attempt, request = await _new_activity(engine)
    if kind == "LESSON_ANSWER":
        existing = await _record(engine, attempt)
        activity_id = existing.activity_id
    else:
        answer = await _new_kana(engine, attempt)
        await _kana_answer(engine, attempt, answer)
        async with async_sessionmaker(engine)() as db:
            activity_id = await db.scalar(
                select(StudyActivityReceipt.activity_id).where(
                    StudyActivityReceipt.user_id == attempt.user_id, StudyActivityReceipt.source_kind == kind
                )
            )
    before = await _state(engine, attempt.user_id)
    with pytest.raises(service.KanaProgressActivityError) as error:
        await _call(engine, request.model_copy(update={"activity_id": activity_id}))
    assert error.value.status_code == 409 and await _state(engine, attempt.user_id) == before


async def test_other_authenticated_owner_is_403_before_any_effect(engine):
    attempt, request = await _new_activity(engine)
    other = await _seed(engine)
    before = await _state(engine, attempt.user_id), await _state(engine, other.user_id)
    with pytest.raises(service.KanaProgressActivityError) as error:
        await _call(engine, request, owner=other.user_id)
    assert error.value.status_code == 403
    assert (await _state(engine, attempt.user_id), await _state(engine, other.user_id)) == before


async def test_missing_new_character_is_404_with_no_receipt_or_learning_write(engine):
    attempt, request = await _new_activity(engine)
    before = await _state(engine, attempt.user_id)
    with pytest.raises(service.KanaProgressActivityError) as error:
        await _call(engine, request.model_copy(update={"kana_id": uuid4()}))
    assert error.value.status_code == 404 and await _state(engine, attempt.user_id) == before


async def test_accepted_card_receipt_replays_after_character_is_deleted(engine):
    attempt, request = await _new_activity(engine)
    response = await _call(engine, request)
    async with engine.begin() as connection:
        await connection.execute(text("DELETE FROM kana_characters WHERE id=:id"), {"id": request.kana_id})
    before = await _state(engine, attempt.user_id)
    assert await _call(engine, request) == response
    assert await _state(engine, attempt.user_id) == before


@pytest.mark.parametrize("failure", ["daily-before", "daily-after", "receipt-insert", "commit-before"])
async def test_card_transaction_failure_rolls_back_then_same_id_retries_once(engine, monkeypatch, failure):
    attempt, request = await _new_activity(engine)
    before = await _state(engine, attempt.user_id)
    original_daily = service.apply_daily_progress_increment

    async def failed_daily(*args, **kwargs):
        if failure == "daily-after":
            await original_daily(*args, **kwargs)
        raise RuntimeError("synthetic daily write failure")

    def failed_receipt(conn, cursor, statement, params, ctx, many):
        if statement.startswith("INSERT INTO study_activity_receipts"):
            raise RuntimeError("synthetic receipt write failure")

    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        with monkeypatch.context() as patch:
            if failure.startswith("daily"):
                patch.setattr(service, "apply_daily_progress_increment", failed_daily)
            if failure == "commit-before":

                async def failed_commit():
                    await db.flush()
                    raise RuntimeError("synthetic pre-commit failure")

                patch.setattr(db, "commit", failed_commit)
            if failure == "receipt-insert":
                event.listen(engine.sync_engine, "before_cursor_execute", failed_receipt)
            try:
                with pytest.raises(service.KanaProgressActivityError) as error:
                    await service.record_kana_progress_activity(db, user, request)
                assert error.value.status_code == 503 and not db.in_transaction()
            finally:
                if failure == "receipt-insert":
                    event.remove(engine.sync_engine, "before_cursor_execute", failed_receipt)
    assert await _state(engine, attempt.user_id) == before
    await _call(engine, request)
    committed = await _state(engine, attempt.user_id)
    await _call(engine, request)
    assert await _state(engine, attempt.user_id) == committed
    assert committed["daily"][0]["kana_learned"] == 1


async def test_committed_response_loss_replays_original_receipt_without_second_effect(engine, monkeypatch):
    attempt, request = await _new_activity(engine)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        commit = db.commit

        async def lost_ack():
            await commit()
            raise RuntimeError("synthetic response loss after commit")

        with monkeypatch.context() as patch:
            patch.setattr(db, "commit", lost_ack)
            with pytest.raises(service.KanaProgressActivityError) as error:
                await service.record_kana_progress_activity(db, user, request)
            assert error.value.status_code == 503
    before = await _state(engine, attempt.user_id)
    _freeze(monkeypatch, service, NOW + timedelta(days=1))
    recovered = await _call(engine, request)
    assert recovered.processed_at == NOW and recovered.activity_id == request.activity_id
    assert await _state(engine, attempt.user_id) == before


@pytest.mark.parametrize("corruption", ["body", "version", "timestamp", "fingerprint"])
async def test_corrupt_card_receipt_fails_503_without_repair_or_new_progress(engine, corruption):
    attempt, request = await _new_activity(engine)
    await _call(engine, request)
    async with async_sessionmaker(engine)() as db:
        receipt = await db.get(StudyActivityReceipt, (attempt.user_id, request.activity_id))
        if corruption == "body":
            receipt.response_body = {"ok": False}
        elif corruption == "version":
            receipt.response_schema_version = 2
        elif corruption == "fingerprint":
            receipt.request_fingerprint = "0" * 64
        else:
            receipt.processed_at = NOW + timedelta(seconds=1)
        await db.commit()
    before = await _state(engine, attempt.user_id)
    with pytest.raises(service.KanaProgressActivityError) as error:
        await _call(engine, request)
    assert error.value.status_code == 503 and await _state(engine, attempt.user_id) == before


async def test_new_card_receipts_are_not_lesson_answers_and_block_destructive_downgrade(engine, card_database):
    attempt, request = await _new_activity(engine)
    await _call(engine, request)
    before = await _state(engine, attempt.user_id)
    async with async_sessionmaker(engine)() as db:
        user = await db.get(User, attempt.user_id)
        with pytest.raises(LessonServiceError) as error:
            await get_lesson_activity(
                db, user, lesson_id=attempt.lesson_id, activity_id=request.activity_id, expected_user_id=attempt.user_id
            )
        assert error.value.status_code == 404
    migration = _alembic(card_database, "downgrade", PREVIOUS)
    assert migration.returncode != 0 and "Accepted kana card receipts exist" in migration.stderr
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == REVISION
    assert await _state(engine, attempt.user_id) == before


async def test_legacy_card_endpoint_keeps_original_repeat_semantics_without_receipts(engine, monkeypatch):
    attempt, request = await _new_activity(engine)
    monkeypatch.setattr(kana_progress, "get_today_kst", lambda: NOW.date())
    for _ in range(2):
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            user = await db.get(User, attempt.user_id)
            await kana_progress.record_kana_learning_progress(db, user, KanaProgressRecord(kana_id=request.kana_id))
    state = await _state(engine, attempt.user_id)
    assert state["activities"] is None and state["kana"][0]["correct_count"] == 2
    assert state["daily"][0]["kana_learned"] == 2
