"""Quiz submission regression tests using a disposable local database only."""

import asyncio
import shutil
import subprocess
import tempfile
import uuid
from collections.abc import AsyncIterator, Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Annotated

import pytest
from fastapi import Depends, FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.base import Base
from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import QuizAnswer, QuizSession, Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech, QuizType
from app.models.user import User
from app.routers.quiz import router as quiz_router
from app.schemas.quiz import QuizAnswerRequest, QuizCompleteRequest, QuizStartRequest, SmartStartRequest
from app.services.quiz_answer import QuizAnswerServiceError, submit_quiz_answer
from app.services.quiz_complete import QuizCompleteServiceError, complete_quiz_session
from app.services.quiz_session_query import get_incomplete_quiz_session
from app.services.quiz_start import start_quiz_session, start_smart_quiz_session


@pytest.fixture(scope="module")
def isolated_postgres_url() -> Iterator[str]:
    initdb = shutil.which("initdb")
    pg_ctl = shutil.which("pg_ctl")
    if initdb is None or pg_ctl is None:
        pytest.skip("Local PostgreSQL binaries are required for quiz persistence integration tests")

    with tempfile.TemporaryDirectory(prefix="hk-quiz-", dir="/tmp") as directory:
        root = Path(directory)
        data = root / "data"
        sockets = root / "socket"
        sockets.mkdir()
        subprocess.run(
            [initdb, "-D", str(data), "-U", "postgres", "--auth=trust", "--no-locale", "--encoding=UTF8"], check=True, capture_output=True
        )
        subprocess.run(
            [pg_ctl, "-D", str(data), "-l", str(root / "postgres.log"), "-o", f"-F -h '' -k '{sockets}' -p 55439", "-w", "start"],
            check=True,
            capture_output=True,
        )
        try:
            yield f"postgresql+asyncpg://postgres@/postgres?host={sockets}&port=55439"
        finally:
            subprocess.run([pg_ctl, "-D", str(data), "-m", "fast", "-w", "stop"], check=True, capture_output=True)


@pytest.mark.asyncio
@pytest.mark.parametrize("start_mode", ["normal", "smart"])
async def test_missing_october_review_partition_does_not_erase_ten_correct_answers(
    isolated_postgres_url: str, caplog: pytest.LogCaptureFixture, start_mode: str
) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
            # Match the existing migration's partition coverage, with a frozen
            # October insertion timestamp so the regression remains deterministic.
            await connection.execute(
                text("""
                CREATE TABLE IF NOT EXISTS review_events (
                    id UUID NOT NULL DEFAULT gen_random_uuid(),
                    user_id UUID NOT NULL, item_type TEXT NOT NULL,
                    vocabulary_id UUID, grammar_id UUID, session_id UUID, lesson_id UUID,
                    direction TEXT NOT NULL, is_correct BOOLEAN NOT NULL,
                    response_ms INTEGER NOT NULL, rating SMALLINT NOT NULL,
                    state_before TEXT NOT NULL, state_after TEXT NOT NULL,
                    distractor_difficulty TEXT,
                    is_provisional_phase BOOLEAN NOT NULL DEFAULT FALSE,
                    is_new_card BOOLEAN NOT NULL DEFAULT FALSE,
                    reviewed_on DATE NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT '2026-10-07T12:00:00Z',
                    PRIMARY KEY (id, created_at)
                ) PARTITION BY RANGE (created_at)
                """)
            )
            await connection.execute(
                text("""
                CREATE TABLE IF NOT EXISTS review_events_2026_march_june PARTITION OF review_events
                FOR VALUES FROM ('2026-03-01') TO ('2026-07-01')
                """)
            )
        user_id = uuid.uuid4()
        question_ids = [uuid.uuid4() for _ in range(10)]
        async with sessions() as db:
            db.add(User(id=user_id, email=f"{user_id}@example.test", nickname="정답 저장 테스트"))
            for index, question_id in enumerate(question_ids):
                db.add(
                    Vocabulary(
                        id=question_id,
                        jlpt_level=JlptLevel.N5,
                        word=f"単語{question_id}",
                        reading="たんご",
                        meaning_ko=f"단어{user_id}-{index}",
                        part_of_speech=PartOfSpeech.NOUN,
                    )
                )
            await db.commit()
            user = await db.get(User, user_id)
            assert user is not None
            if start_mode == "smart":
                started = await start_smart_quiz_session(
                    db, user, SmartStartRequest(category="VOCABULARY", jlpt_level=JlptLevel.N5, count=10)
                )
                assert started.session.questions_data == {"mode": "smart", "questions": started.questions}
            else:
                started = await start_quiz_session(
                    db, user, QuizStartRequest(quiz_type=QuizType.VOCABULARY, jlpt_level=JlptLevel.N5, count=10)
                )
                assert started.session.questions_data == started.questions
            session_id = started.session.id
            correct_options = {uuid.UUID(question["id"]): question["correctOptionId"] for question in started.questions}
            assert len(correct_options) == 10
            question_ids = list(correct_options)
        async with sessions() as db:
            user = await db.get(User, user_id)
            assert user is not None
            assert await get_incomplete_quiz_session(db, user) is None
            active = await db.get(QuizSession, session_id)
            assert active is not None and active.completed_at is None

        for question_id in question_ids:
            async with sessions() as db:
                user = await db.get(User, user_id)
                assert user is not None
                result = await submit_quiz_answer(
                    db,
                    user,
                    QuizAnswerRequest(
                        session_id=session_id,
                        question_id=question_id,
                        question_type=QuizType.VOCABULARY,
                        selected_option_id=correct_options[question_id],
                    ),
                )
                assert result.success is True

        async with sessions() as db:
            saved = await db.get(QuizSession, session_id)
            assert saved is not None
            assert saved.correct_count == 10
            assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == session_id)) == 10
            user = await db.get(User, user_id)
            assert user is not None
            # A lost HTTP response may cause the client to send the first answer
            # again; it must not inflate the score or the SRS progress.
            replay = await submit_quiz_answer(
                db,
                user,
                QuizAnswerRequest(
                    session_id=session_id,
                    question_id=question_ids[0],
                    question_type=QuizType.VOCABULARY,
                    selected_option_id=correct_options[question_ids[0]],
                ),
            )
            assert replay.success is True
            completed = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=session_id))
            assert completed.correct_count == 10
            assert completed.total_questions == 10
            assert completed.accuracy == 100.0
            assert completed.xp_earned == 100
        assert any(record.exc_info and "no partition of relation" in str(record.exc_info[1]) for record in caplog.records)
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_unfinished_legacy_duplicates_use_first_answers_and_preserve_completed_results(isolated_postgres_url: str) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id, session_id, completed_session_id = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    question_ids = [uuid.uuid4(), uuid.uuid4()]
    now = datetime.now(UTC)
    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with sessions() as db:
            db.add(User(id=user_id, email=f"{user_id}@example.test", nickname="기존 중복 답안 테스트"))
            await db.flush()
            questions = [{"id": str(question_id), "correctOptionId": "correct"} for question_id in question_ids]
            db.add_all(
                [
                    QuizSession(
                        id=session_id,
                        user_id=user_id,
                        quiz_type=QuizType.CLOZE,
                        jlpt_level=JlptLevel.N5,
                        total_questions=2,
                        correct_count=4,
                        questions_data=questions,
                    ),
                    QuizSession(
                        id=completed_session_id,
                        user_id=user_id,
                        quiz_type=QuizType.CLOZE,
                        jlpt_level=JlptLevel.N5,
                        total_questions=2,
                        correct_count=2,
                        completed_at=now,
                        questions_data=questions,
                    ),
                ]
            )
            await db.flush()
            for index, (question_id, is_correct) in enumerate(
                [(question_ids[0], False), (question_ids[0], True), (question_ids[1], True), (question_ids[1], False)]
            ):
                db.add(
                    QuizAnswer(
                        session_id=session_id,
                        question_id=question_id,
                        question_type=QuizType.CLOZE,
                        selected_option_id="correct" if is_correct else "wrong",
                        is_correct=is_correct,
                        answered_at=now + timedelta(seconds=index),
                    )
                )
            await db.commit()
            user = await db.get(User, user_id)
            assert user is not None
            result = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=session_id))
            assert (result.correct_count, result.total_questions, result.accuracy, result.xp_earned) == (1, 2, 50.0, 10)
            assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == session_id)) == 4

            # Previously completed sessions retain their historical result even
            # when their legacy answer history cannot be reconstructed.
            historical = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=completed_session_id))
            assert (historical.correct_count, historical.accuracy, historical.xp_earned) == (2, 100.0, 0)
            assert user.experience_points == 10
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_parallel_answers_and_retries_are_counted_once_and_completion_waits(isolated_postgres_url: str) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id, session_id = uuid.uuid4(), uuid.uuid4()
    question_ids = [uuid.uuid4() for _ in range(10)]
    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with sessions() as db:
            db.add(User(id=user_id, email=f"{user_id}@example.test", nickname="답안 재전송 테스트"))
            await db.flush()
            db.add(
                QuizSession(
                    id=session_id,
                    user_id=user_id,
                    quiz_type=QuizType.CLOZE,
                    jlpt_level=JlptLevel.N5,
                    total_questions=10,
                    correct_count=0,
                    questions_data=[{"id": str(question_id), "correctOptionId": "correct"} for question_id in question_ids],
                )
            )
            await db.commit()

        async with sessions() as db:
            user = await db.get(User, user_id)
            assert user is not None
            with pytest.raises(QuizCompleteServiceError) as incomplete:
                await complete_quiz_session(db, user, QuizCompleteRequest(session_id=session_id))
            assert incomplete.value.status_code == 409
            saved = await db.get(QuizSession, session_id)
            assert saved is not None and saved.completed_at is None

        async def answer(question_id: uuid.UUID) -> None:
            async with sessions() as db:
                user = await db.get(User, user_id)
                assert user is not None
                await submit_quiz_answer(
                    db,
                    user,
                    QuizAnswerRequest(
                        session_id=session_id,
                        question_id=question_id,
                        question_type=QuizType.CLOZE,
                        selected_option_id="correct",
                    ),
                )

        await asyncio.wait_for(asyncio.gather(*(answer(question_id) for question_id in [*question_ids, *question_ids])), timeout=10)
        async with sessions() as db:
            user = await db.get(User, user_id)
            assert user is not None
            with pytest.raises(QuizAnswerServiceError) as changed_answer:
                await submit_quiz_answer(
                    db,
                    user,
                    QuizAnswerRequest(
                        session_id=session_id,
                        question_id=question_ids[0],
                        question_type=QuizType.CLOZE,
                        selected_option_id="wrong",
                    ),
                )
            assert changed_answer.value.status_code == 409
            result = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=session_id))
            assert result.correct_count == 10
            assert result.accuracy == 100.0
            assert result.xp_earned == 100
            assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == session_id)) == 10
            repeated = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=session_id))
            assert repeated.correct_count == 10
            assert repeated.xp_earned == 0
            assert user.experience_points == 100
    finally:
        await engine.dispose()


@pytest.mark.asyncio
@pytest.mark.parametrize("questions_shape", ["list", "smart"])
async def test_legacy_naive_timestamp_session_can_be_found_resumed_and_completed(isolated_postgres_url: str, questions_shape: str) -> None:
    admin_engine = create_async_engine(isolated_postgres_url)
    schema = f"legacy_quiz_{uuid.uuid4().hex}"
    engine = create_async_engine(isolated_postgres_url, connect_args={"server_settings": {"search_path": schema, "timezone": "UTC"}})
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id, other_user_id, session_id = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    authenticated_user_id = user_id
    question_ids = [uuid.uuid4(), uuid.uuid4()]
    questions = [
        {
            "id": str(question_id),
            "question": f"質問{index}",
            "options": [{"id": "correct", "text": "정답"}, {"id": "wrong", "text": "오답"}],
            "correctOptionId": "correct",
        }
        for index, question_id in enumerate(question_ids)
    ]
    app = FastAPI()
    app.include_router(quiz_router)

    async def get_test_db() -> AsyncIterator[AsyncSession]:
        async with sessions() as db:
            yield db

    async def get_test_user(db: Annotated[AsyncSession, Depends(get_db)]) -> User:
        user = await db.get(User, authenticated_user_id)
        assert user is not None
        return user

    app.dependency_overrides[get_db] = get_test_db
    app.dependency_overrides[get_current_user] = get_test_user
    try:
        async with admin_engine.begin() as connection:
            await connection.execute(text(f'CREATE SCHEMA "{schema}"'))
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
            # The original migration used TIMESTAMP(3), unlike ORM metadata's
            # timezone-aware declaration. Exercise asyncpg's real naive result.
            await connection.execute(
                text(
                    "ALTER TABLE quiz_sessions "
                    "ALTER COLUMN started_at TYPE TIMESTAMP(3) WITHOUT TIME ZONE USING started_at AT TIME ZONE 'UTC', "
                    "ALTER COLUMN completed_at TYPE TIMESTAMP(3) WITHOUT TIME ZONE USING completed_at AT TIME ZONE 'UTC'"
                )
            )
        async with sessions() as db:
            db.add_all(
                [
                    User(id=user_id, email=f"{user_id}@example.test", nickname="이어 풀기 테스트"),
                    User(id=other_user_id, email=f"{other_user_id}@example.test", nickname="다른 사용자"),
                ]
            )
            await db.flush()
            db.add(
                QuizSession(
                    id=session_id,
                    user_id=user_id,
                    quiz_type=QuizType.CLOZE,
                    jlpt_level=JlptLevel.N5,
                    total_questions=2,
                    correct_count=0,
                    questions_data={"mode": "smart", "questions": questions} if questions_shape == "smart" else questions,
                )
            )
            await db.commit()
        async with sessions() as db:
            stored = await db.get(QuizSession, session_id)
            assert stored is not None and stored.started_at.tzinfo is None
            original_started_at = stored.started_at.isoformat()

        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            # A just-started quiz stays active while the home banner hides it.
            empty = await client.get("/api/v1/quiz/incomplete")
            assert empty.status_code == 200
            assert empty.json() == {"session": None}
            first = await client.post(
                "/api/v1/quiz/answer",
                json={
                    "sessionId": str(session_id),
                    "questionId": str(question_ids[0]),
                    "questionType": "CLOZE",
                    "selectedOptionId": "correct",
                },
            )
            assert first.status_code == 200
            assert first.json() == {"success": True}
            banner = await client.get("/api/v1/quiz/incomplete")
            assert banner.status_code == 200
            assert banner.json() == {
                "session": {
                    "id": str(session_id),
                    "quizType": "CLOZE",
                    "jlptLevel": "N5",
                    "totalQuestions": 2,
                    "answeredCount": 1,
                    "correctCount": 1,
                    "startedAt": original_started_at,
                    "mode": "smart" if questions_shape == "smart" else "cloze",
                    "resumeStatus": "available",
                }
            }
            authenticated_user_id = other_user_id
            other_banner = await client.get("/api/v1/quiz/incomplete")
            assert other_banner.status_code == 200
            assert other_banner.json() == {"session": None}
            forbidden = await client.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})
            assert forbidden.status_code == 404
            authenticated_user_id = user_id
            resumed = await client.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})
            assert resumed.status_code == 200
            payload = resumed.json()
            assert payload["sessionId"] == str(session_id)
            assert payload["answeredQuestionIds"] == [str(question_ids[0])]
            assert payload["correctCount"] == 1
            assert payload["totalQuestions"] == 2
            assert payload["quizType"] == "CLOZE"
            assert [question["questionId"] for question in payload["questions"]] == [str(question_id) for question_id in question_ids]
            assert [question["options"] for question in payload["questions"]] == [question["options"] for question in questions]
            assert [question["correctOptionId"] for question in payload["questions"]] == ["correct", "correct"]
            second = await client.post(
                "/api/v1/quiz/answer",
                json={
                    "sessionId": str(session_id),
                    "questionId": str(question_ids[1]),
                    "questionType": "CLOZE",
                    "selectedOptionId": "correct",
                },
            )
            assert second.status_code == 200
            completed = await client.post("/api/v1/quiz/complete", json={"sessionId": str(session_id)})
            assert completed.status_code == 200
            assert completed.json()["correctCount"] == 2
            assert completed.json()["totalQuestions"] == 2
            assert completed.json()["accuracy"] == 100.0
            assert completed.json()["xpEarned"] == 20
            finished_banner = await client.get("/api/v1/quiz/incomplete")
            assert finished_banner.status_code == 200
            assert finished_banner.json() == {"session": None}
            finished_resume = await client.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})
            assert finished_resume.status_code == 400
        async with sessions() as db:
            saved = await db.get(QuizSession, session_id)
            assert saved is not None and saved.completed_at is not None
            assert saved.started_at.tzinfo is None
            assert saved.started_at.isoformat() == original_started_at
            assert saved.correct_count == 2
            assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == session_id)) == 2
    finally:
        await engine.dispose()
        async with admin_engine.begin() as connection:
            await connection.execute(text(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE'))
        await admin_engine.dispose()
