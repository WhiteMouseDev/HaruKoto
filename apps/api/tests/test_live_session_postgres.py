"""Use only a disposable local database; never read a configured DATABASE_URL."""

import asyncio
import shutil
import subprocess
import tempfile
import time
import uuid
from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.base import Base
from app.models import AiCharacter, Conversation, ConversationScenario, DailyAiUsage, DailyProgress, User, WordbookEntry
from app.models.enums import Difficulty, ScenarioCategory, WordbookSource
from app.routers.chat_data import get_character_stats
from app.routers.wordbook import create_wordbook_entry
from app.schemas.chat import ChatMessageRequest, ChatStartRequest, LiveFeedbackRequest, LiveSessionRequest
from app.schemas.wordbook import WordbookCreateRequest
from app.services.chat_live_session import create_live_session
from app.services.chat_session import send_chat_message, start_chat_session
from app.services.chat_voice import submit_live_conversation_feedback
from app.services.chat_voice_errors import ChatVoiceServiceError
from app.services.conversation_rewards import _count_completed_conversations
from app.services.daily_progress_upsert import build_daily_progress_insert_values
from app.services.study_day_recording import lock_study_user
from app.utils.constants import REWARDS
from app.utils.date import get_today_kst


@pytest.fixture(scope="module")
def live_postgres_url(request) -> Iterator[str]:
    if request.config.getoption("--live-postgres-docker"):
        yield from _docker_postgres_url(request.config.getoption("--live-postgres-docker-locale"))
        return
    initdb, pg_ctl = shutil.which("initdb"), shutil.which("pg_ctl")
    if not initdb or not pg_ctl:
        pytest.skip("Local PostgreSQL binaries are required for live-session concurrency checks")
    with tempfile.TemporaryDirectory(prefix="hk-live-", dir="/tmp") as directory:
        root = Path(directory)
        data, sockets = root / "data", root / "socket"
        sockets.mkdir()
        subprocess.run(
            [initdb, "-D", str(data), "-U", "postgres", "--auth=trust", "--no-locale", "--encoding=UTF8"], check=True, capture_output=True
        )
        subprocess.run(
            [pg_ctl, "-D", str(data), "-l", str(root / "postgres.log"), "-o", f"-F -h '' -k '{sockets}' -p 55440", "-w", "start"],
            check=True,
            capture_output=True,
        )
        try:
            yield f"postgresql+asyncpg://postgres@/postgres?host={sockets}&port=55440"
        finally:
            subprocess.run([pg_ctl, "-D", str(data), "-m", "fast", "-w", "stop"], check=True, capture_output=True)


def _docker_postgres_url(locale: str | None = None) -> Iterator[str]:
    docker = shutil.which("docker")
    if docker is None:
        pytest.fail("--live-postgres-docker requires local Docker")
    # Explicit local socket only; do not inherit a potentially remote Docker context.
    socket = Path.home() / ".docker" / "run" / "docker.sock"
    if not socket.is_socket():
        pytest.fail("The local Docker Desktop socket is unavailable")
    command = [docker, "--host", f"unix://{socket}"]
    locale_args = ["-e", f"POSTGRES_INITDB_ARGS=--locale={locale} --encoding=UTF8"] if locale else []
    container_id = subprocess.run(
        command
        + ["run", "--rm", "--pull=never", "-d", "-p", "127.0.0.1::5432", "-e", "POSTGRES_HOST_AUTH_METHOD=trust"]
        + locale_args
        + ["postgres:16-alpine"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    try:
        for _ in range(40):
            ready = subprocess.run(command + ["exec", container_id, "pg_isready", "-h", "127.0.0.1", "-U", "postgres"], capture_output=True)
            if ready.returncode == 0:
                break
            time.sleep(0.25)
        else:
            pytest.fail("Disposable PostgreSQL did not become ready")
        address = subprocess.run(command + ["port", container_id, "5432/tcp"], check=True, capture_output=True, text=True).stdout.strip()
        assert address.startswith("127.0.0.1:") and "\n" not in address
        yield f"postgresql+asyncpg://postgres@{address}/postgres"
    finally:
        subprocess.run(command + ["rm", "-f", container_id], check=True, capture_output=True)


@pytest_asyncio.fixture
async def live_db(live_postgres_url):
    engine = create_async_engine(live_postgres_url)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id = uuid.uuid4()
    async with sessions() as db:
        db.add(User(id=user_id, email=f"{user_id}@example.test", nickname="통화 테스트"))
        await db.commit()
    try:
        yield sessions, user_id
    finally:
        await engine.dispose()


async def start_session(sessions, user_id, conversation_id):
    async with sessions() as db:
        user = await db.get(User, user_id)
        with (
            patch("app.services.chat_live_session.rate_limit", return_value=MagicMock(success=True)),
            patch("app.services.chat_live_session.check_ai_limit", return_value={"allowed": True}),
        ):
            return await create_live_session(db, user, LiveSessionRequest(conversationId=conversation_id))


@pytest.mark.asyncio
async def test_parallel_start_and_lost_response_retry_share_one_persisted_session(live_db):
    sessions, user_id = live_db
    conversation_id = uuid.uuid4()
    first, second = await asyncio.wait_for(
        asyncio.gather(start_session(sessions, user_id, conversation_id), start_session(sessions, user_id, conversation_id)), timeout=10
    )
    replay = await start_session(sessions, user_id, conversation_id)
    assert first.conversation_id == second.conversation_id == replay.conversation_id == conversation_id
    async with sessions() as db:
        assert await db.scalar(select(func.count()).select_from(Conversation).where(Conversation.id == conversation_id)) == 1
        conversation = await db.get(Conversation, conversation_id)
        assert conversation.ended_at is None
        assert conversation.messages == []
        assert await db.scalar(select(func.count()).select_from(DailyAiUsage).where(DailyAiUsage.user_id == user_id)) == 0


@pytest.mark.asyncio
async def test_finish_concurrency_and_response_loss_award_and_count_once(live_db):
    sessions, user_id = live_db
    conversation_id = uuid.uuid4()
    await start_session(sessions, user_id, conversation_id)
    body = LiveFeedbackRequest(
        conversationId=conversation_id,
        durationSeconds=30,
        analysisEnabled=False,
        transcript=[{"role": "assistant", "text": "こんにちは"}, {"role": "user", "text": "予約しました"}],
    )

    async def finish():
        async with sessions() as db:
            user = await db.get(User, user_id)
            return await submit_live_conversation_feedback(db, user, body)

    with patch("app.services.conversation_rewards.check_and_grant_achievements", return_value=[]):
        first, second = await asyncio.wait_for(asyncio.gather(finish(), finish()), timeout=10)
        retry = await finish()
    assert sorted([first["xpEarned"], second["xpEarned"]]) == [0, REWARDS.CONVERSATION_COMPLETE_XP]
    assert retry["xpEarned"] == 0
    async with sessions() as db:
        user = await db.get(User, user_id)
        usage = await db.scalar(select(DailyAiUsage).where(DailyAiUsage.user_id == user_id))
        conversation = await db.get(Conversation, conversation_id)
        assert user.experience_points == REWARDS.CONVERSATION_COMPLETE_XP
        assert usage.call_count == 1 and usage.call_seconds == 30
        assert conversation.message_count == 2
        assert conversation.messages[1]["content"] == "予約しました"
        assert conversation.ended_at is not None


@pytest.mark.asyncio
async def test_record_is_visible_and_unlocked_while_feedback_is_still_running(live_db):
    sessions, user_id = live_db
    conversation_id = uuid.uuid4()
    await start_session(sessions, user_id, conversation_id)
    generating, release = asyncio.Event(), asyncio.Event()

    async def delayed_feedback(*args, **kwargs):
        generating.set()
        await release.wait()
        return {"overallScore": 80}

    async def finish(analyze):
        async with sessions() as db:
            user = await db.get(User, user_id)
            return await submit_live_conversation_feedback(
                db,
                user,
                LiveFeedbackRequest(
                    conversationId=conversation_id,
                    durationSeconds=30,
                    analysisEnabled=analyze,
                    transcript=[{"role": "user", "text": "予約しました"}],
                ),
            )

    with (
        patch("app.services.chat_voice.generate_live_feedback", side_effect=delayed_feedback),
        patch("app.services.conversation_rewards.check_and_grant_achievements", return_value=[]),
    ):
        task = asyncio.create_task(finish(True))
        try:
            await asyncio.wait_for(generating.wait(), timeout=5)
            retry = await asyncio.wait_for(finish(False), timeout=2)
            assert retry["xpEarned"] == 0
            assert retry["feedbackSummary"] is None
            async with sessions() as db:
                saved = await db.get(Conversation, conversation_id)
                assert saved.ended_at is not None
                assert saved.message_count == 1
        finally:
            release.set()
            result = await asyncio.wait_for(task, timeout=5)
    assert result["feedbackSummary"] == {"overallScore": 80}


@pytest.mark.asyncio
async def test_completion_failure_rolls_back_without_false_saved_success(live_db):
    sessions, user_id = live_db
    conversation_id = uuid.uuid4()
    await start_session(sessions, user_id, conversation_id)
    async with sessions() as db:
        user = await db.get(User, user_id)
        with (
            patch("app.services.chat_voice.grant_conversation_completion_rewards", side_effect=RuntimeError("write failed")),
            pytest.raises(ChatVoiceServiceError) as error,
        ):
            await submit_live_conversation_feedback(
                db,
                user,
                LiveFeedbackRequest(
                    conversationId=conversation_id, durationSeconds=30, transcript=[{"role": "user", "text": "予約しました"}]
                ),
            )
        assert error.value.status_code == 500
    async with sessions() as db:
        saved = await db.get(Conversation, conversation_id)
        assert saved.ended_at is None
        assert saved.messages == []
        assert await db.scalar(select(func.count()).select_from(DailyAiUsage).where(DailyAiUsage.user_id == user_id)) == 0


@pytest.mark.asyncio
@pytest.mark.parametrize("duration,utterance", [(0, ""), (10, "こんにちは"), (30, "")])
async def test_ineligible_calls_are_saved_without_xp_and_only_connected_time_counts(live_db, duration, utterance):
    sessions, user_id = live_db
    conversation_id = uuid.uuid4()
    await start_session(sessions, user_id, conversation_id)
    async with sessions() as db:
        user = await db.get(User, user_id)
        with patch("app.services.chat_voice.grant_conversation_completion_rewards", new_callable=AsyncMock) as rewards:
            result = await submit_live_conversation_feedback(
                db,
                user,
                LiveFeedbackRequest(
                    conversationId=conversation_id,
                    durationSeconds=duration,
                    analysisEnabled=False,
                    transcript=[{"role": "user", "text": utterance}],
                ),
            )
        rewards.assert_not_awaited()
        assert result["xpEarned"] == 0
    async with sessions() as db:
        saved = await db.get(Conversation, conversation_id)
        user = await db.get(User, user_id)
        usage = await db.scalar(select(DailyAiUsage).where(DailyAiUsage.user_id == user_id))
        assert saved.ended_at is not None
        assert user.experience_points == 0
        if duration == 0:
            assert usage is None
            assert await _count_completed_conversations(db, user_id=user_id) == 0
        else:
            assert usage.call_count == 1 and usage.call_seconds == duration


@pytest.mark.asyncio
async def test_parallel_expression_saves_preserve_personal_note_and_translation(live_db):
    sessions, user_id = live_db
    async with sessions() as db:
        db.add(
            WordbookEntry(
                user_id=user_id,
                word="朝食は何時からですか。",
                reading="ちょうしょくはなんじからですか",
                meaning_ko="내가 정리한 조식 질문",
                note="개인 메모",
                source=WordbookSource.MANUAL,
            )
        )
        await db.commit()

    async def save():
        async with sessions() as db:
            user = await db.get(User, user_id)
            return await create_wordbook_entry(
                WordbookCreateRequest(
                    word="朝食は何時からですか。", reading="", meaningKo="AI 번역", source="CONVERSATION", preserveExisting=True
                ),
                user,
                db,
            )

    first, second = await asyncio.wait_for(asyncio.gather(save(), save()), timeout=5)
    assert first.id == second.id
    assert first.note == second.note == "개인 메모"
    assert first.meaning_ko == second.meaning_ko == "내가 정리한 조식 질문"
    assert first.source == second.source == WordbookSource.MANUAL


@pytest.mark.asyncio
async def test_text_hotel_practice_persists_between_requests_and_keeps_roles(live_db):
    sessions, user_id = live_db
    scenario_id = uuid.uuid4()
    async with sessions() as db:
        db.add(
            ConversationScenario(
                id=scenario_id,
                title=f"체크인 {scenario_id}",
                title_ja="ホテル",
                description="예약 이름을 말해요",
                category=ScenarioCategory.TRAVEL,
                difficulty=Difficulty.BEGINNER,
                estimated_minutes=3,
                situation="호텔 체크인",
                your_role="투숙객",
                ai_role="호텔 직원",
                system_prompt="予約を確認してください。",
            )
        )
        await db.commit()
        user = await db.get(User, user_id)
        with (
            patch("app.services.chat_session.check_ai_limit", return_value={"allowed": True}),
            patch("app.services.chat_session.rate_limit", return_value=MagicMock(success=True)),
            patch(
                "app.services.chat_session.generate_chat_response", return_value={"messageJa": "お名前は？", "messageKo": "성함은요?"}
            ) as generate,
        ):
            started = await start_chat_session(db, user, ChatStartRequest(scenarioId=scenario_id))
        instruction = generate.await_args.args[0]
        assert "투숙객" in instruction and "호텔 직원" in instruction
        assert "予約を確認してください。" in instruction
        assert "JSON" in instruction and "【N5レベル対応】" in instruction
    async with sessions() as db:
        user = await db.get(User, user_id)
        with patch(
            "app.services.chat_session.generate_chat_response",
            return_value={"messageJa": "ありがとうございます", "messageKo": "감사합니다"},
        ):
            await send_chat_message(db, user, ChatMessageRequest(conversationId=started.conversation_id, message="キムです。"))
    async with sessions() as db:
        saved = await db.get(Conversation, started.conversation_id)
        assert saved is not None
        assert saved.messages[-2:] == [
            {"role": "user", "content": "キムです。"},
            {"role": "assistant", "content": "ありがとうございます"},
        ]


@pytest.mark.asyncio
async def test_live_completion_preserves_user_first_lock_order_and_existing_study_day(live_db):
    sessions, user_id = live_db
    conversation_id = uuid.uuid4()
    await start_session(sessions, user_id, conversation_id)
    async with sessions() as db:
        db.add(DailyProgress(**build_daily_progress_insert_values(user_id=user_id, today=get_today_kst(), activity_recorded=True)))
        await db.commit()
    attempting_user_lock = asyncio.Event()

    async def observed_user_lock(db, user):
        attempting_user_lock.set()
        await lock_study_user(db, user)

    async def finish():
        async with sessions() as db:
            user = await db.get(User, user_id)
            return await submit_live_conversation_feedback(
                db,
                user,
                LiveFeedbackRequest(
                    conversationId=conversation_id,
                    durationSeconds=30,
                    analysisEnabled=False,
                    transcript=[{"role": "user", "text": "予約しました"}],
                ),
            )

    async with sessions() as existing_writer:
        user = await existing_writer.get(User, user_id)
        await lock_study_user(existing_writer, user)
        with (
            patch("app.services.chat_voice.lock_study_user", side_effect=observed_user_lock),
            patch("app.services.conversation_rewards.check_and_grant_achievements", return_value=[]),
        ):
            task = asyncio.create_task(finish())
            try:
                await asyncio.wait_for(attempting_user_lock.wait(), timeout=3)
                # A reversed conversation -> user order would hold this row and
                # fail NOWAIT while waiting on our already-held user mutex.
                row = await existing_writer.scalar(
                    select(Conversation).where(Conversation.id == conversation_id).with_for_update(nowait=True)
                )
                assert row.ended_at is None
            finally:
                await existing_writer.commit()
                result = await asyncio.wait_for(task, timeout=5)
    assert result["xpEarned"] == REWARDS.CONVERSATION_COMPLETE_XP
    async with sessions() as db:
        daily = await db.scalar(select(DailyProgress).where(DailyProgress.user_id == user_id))
        assert daily.activity_recorded is True
        assert daily.conversation_count == 1
        assert daily.xp_earned == REWARDS.CONVERSATION_COMPLETE_XP


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "messages,expected",
    [
        (None, 0),
        ({"role": "user", "content": "予約しました"}, 0),
        ([], 0),
        ([{"role": "assistant", "content": "こんにちは"}], 0),
        # Derive expected whitespace from Python, independently of the SQL set;
        # retain the original ASCII/U+3000 regression and cover every strip char.
        ([{"role": "user", "content": "".join(chr(codepoint) for codepoint in range(0x110000) if not chr(codepoint).strip())}], 0),
        ([{"role": "user"}], 0),
        ([{"role": "user", "content": None}], 0),
        ([{"role": "user", "content": 12}], 0),
        ([{"role": ["user"], "content": "予約しました"}], 0),
        ([[{"role": "user", "content": "予約しました"}]], 0),
        ([None, 12, "invalid", {"role": "system", "content": "user: hello"}], 0),
        ([{"role": "user", "content": "\u3000予約しました\u00a0"}], 1),
        ([{"role": "assistant", "content": "こんにちは"}, {"role": "user", "content": "안녕하세요"}], 1),
    ],
    ids=[
        "json-null",
        "legacy-object",
        "empty",
        "assistant-only",
        "whitespace",
        "missing-text",
        "null-text",
        "numeric-text",
        "array-role",
        "nested-array",
        "invalid-items",
        "user-japanese",
        "user-korean",
    ],
)
async def test_completed_count_and_character_stats_require_actual_user_speech(live_db, messages, expected):
    sessions, user_id = live_db
    character_id = uuid.uuid4()
    async with sessions() as db:
        db.add(
            AiCharacter(
                id=character_id,
                name="시험",
                name_ja="はる",
                name_romaji=str(character_id),
                gender="female",
                age_description="21",
                description="시험",
                relationship="친구",
                background_story="가상",
                personality="친절",
                voice_name="Kore",
                speech_style="casual",
                target_level="N5",
                avatar_emoji="🦊",
            )
        )
        await db.flush()
        db.add(
            Conversation(
                user_id=user_id,
                character_id=character_id,
                type="VOICE",
                messages=messages,
                # Stale legacy counters must not override evidence from actual speech.
                message_count=0 if expected else 3,
                ended_at=datetime.now(UTC),
            )
        )
        await db.commit()
        user = await db.get(User, user_id)
        assert await _count_completed_conversations(db, user_id=user_id) == expected
        stats = await get_character_stats(user, db)
        assert stats["characterStats"].get(str(character_id), 0) == expected
