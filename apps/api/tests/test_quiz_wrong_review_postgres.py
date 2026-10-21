"""Session-scoped wrong review regressions against disposable local PostgreSQL."""

from __future__ import annotations

import asyncio
import shutil
import subprocess
import tempfile
import uuid
from collections.abc import AsyncIterator, Iterator
from copy import deepcopy
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
import pytest_asyncio
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.base import Base
from app.models import Grammar, QuizAnswer, QuizSession, UserGrammarProgress, UserStudyStageProgress, UserVocabProgress, Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech, QuizType
from app.models.user import User
from app.schemas.quiz import QuizAnswerRequest, QuizCompleteRequest, QuizStartRequest, QuizWrongReviewRequest
from app.services.quiz_answer import submit_quiz_answer
from app.services.quiz_complete import complete_quiz_session
from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_session_query import get_incomplete_quiz_session
from app.services.quiz_start import start_quiz_session
from app.services.quiz_wrong_answers_query import get_wrong_answers_data
from app.services.quiz_wrong_review import start_wrong_answer_review


@pytest.fixture(scope="module")
def wrong_review_postgres_url() -> Iterator[str]:
    initdb, pg_ctl = shutil.which("initdb"), shutil.which("pg_ctl")
    if initdb is None or pg_ctl is None:
        pytest.skip("Local PostgreSQL binaries are required for wrong review integration tests")
    with tempfile.TemporaryDirectory(prefix="hk-wrong-review-", dir="/tmp") as directory:
        root = Path(directory)
        sockets = root / "socket"
        sockets.mkdir()
        subprocess.run(
            [initdb, "-D", str(root / "data"), "-U", "postgres", "--auth=trust", "--no-locale", "--encoding=UTF8"],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            [pg_ctl, "-D", str(root / "data"), "-l", str(root / "postgres.log"), "-o", f"-F -h '' -k '{sockets}' -p 55448", "-w", "start"],
            check=True,
            capture_output=True,
        )
        try:
            yield f"postgresql+asyncpg://postgres@/postgres?host={sockets}&port=55448"
        finally:
            subprocess.run([pg_ctl, "-D", str(root / "data"), "-m", "fast", "-w", "stop"], check=True, capture_output=True)


@pytest_asyncio.fixture
async def wrong_review_sessions(wrong_review_postgres_url: str) -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    schema = f"wrong_review_{uuid.uuid4().hex}"
    admin = create_async_engine(wrong_review_postgres_url)
    engine = create_async_engine(wrong_review_postgres_url, connect_args={"server_settings": {"search_path": schema}})
    try:
        async with admin.begin() as connection:
            await connection.execute(text(f'CREATE SCHEMA "{schema}"'))
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
            await connection.execute(
                text("""
                CREATE TABLE review_events (
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
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                    PRIMARY KEY (id, created_at)
                )
                """)
            )
        yield async_sessionmaker(engine, expire_on_commit=False)
    finally:
        await engine.dispose()
        async with admin.begin() as connection:
            await connection.execute(text(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE'))
        await admin.dispose()


@dataclass(frozen=True)
class SeededSource:
    user_id: uuid.UUID
    source_id: uuid.UUID
    other_id: uuid.UUID
    questions: list[dict[str, Any]]


async def _seed_source(
    sessions: async_sessionmaker[AsyncSession], *, quiz_type: QuizType = QuizType.VOCABULARY, smart: bool = False
) -> SeededSource:
    user_id, source_id, other_id = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    question_ids = [uuid.uuid4() for _ in range(3)]
    now = datetime.now(UTC)
    questions = [
        {
            "id": str(question_id),
            "type": quiz_type.value,
            "question": f"問題{index}",
            "options": [{"id": f"correct-{index}", "text": f"정답{index}"}, {"id": f"wrong-{index}", "text": f"오답{index}"}],
            "correctOptionId": f"correct-{index}",
            "meaningKo": f"정답{index}",
            **({"pattern": f"問題{index}"} if quiz_type == QuizType.GRAMMAR else {"word": f"問題{index}", "reading": "もんだい"}),
        }
        for index, question_id in enumerate(question_ids)
    ]
    async with sessions() as db:
        db.add(User(id=user_id, email=f"{user_id}@example.test", nickname="이번 오답 복습", experience_points=123))
        for index, question_id in enumerate(question_ids):
            if quiz_type == QuizType.GRAMMAR:
                db.add(
                    Grammar(
                        id=question_id,
                        jlpt_level=JlptLevel.N5,
                        pattern=f"問題{question_id}",
                        meaning_ko=f"정답{index}",
                        explanation="문법 설명",
                    )
                )
            else:
                db.add(
                    Vocabulary(
                        id=question_id,
                        jlpt_level=JlptLevel.N5,
                        word=f"問題{question_id}",
                        reading="もんだい",
                        meaning_ko=f"정답{index}",
                        part_of_speech=PartOfSpeech.NOUN,
                    )
                )
        await db.flush()
        db.add_all(
            [
                QuizSession(
                    id=source_id,
                    user_id=user_id,
                    quiz_type=quiz_type,
                    jlpt_level=JlptLevel.N5,
                    total_questions=3,
                    correct_count=1,
                    started_at=now - timedelta(minutes=10),
                    completed_at=now - timedelta(minutes=5),
                    questions_data={"mode": "smart", "questions": questions}
                    if smart
                    else {"stage_id": str(uuid.uuid4()), "questions": questions},
                ),
                QuizSession(
                    id=other_id,
                    user_id=user_id,
                    quiz_type=quiz_type,
                    jlpt_level=JlptLevel.N5,
                    total_questions=3,
                    correct_count=1,
                    started_at=now - timedelta(minutes=2),
                    questions_data=questions,
                ),
            ]
        )
        await db.flush()
        for index, question_id in enumerate(question_ids):
            correct = index == 1
            db.add(
                QuizAnswer(
                    session_id=source_id,
                    question_id=question_id,
                    question_type=quiz_type,
                    selected_option_id=f"correct-{index}" if correct else f"wrong-{index}",
                    is_correct=correct,
                    answered_at=now - timedelta(minutes=6, seconds=3 - index),
                )
            )
        await db.commit()
    return SeededSource(user_id=user_id, source_id=source_id, other_id=other_id, questions=questions)


async def _start(sessions: async_sessionmaker[AsyncSession], source: SeededSource):
    async with sessions() as db:
        user = await db.get(User, source.user_id)
        assert user is not None
        return await start_wrong_answer_review(db, user, QuizWrongReviewRequest(source_session_id=source.source_id))


async def _historical_snapshot(sessions: async_sessionmaker[AsyncSession], source: SeededSource) -> dict[str, Any]:
    async with sessions() as db:
        # Compare every field of the original sessions and answers, not merely
        # their counters. This excludes only newly created review rows.
        session_rows = (
            (
                await db.execute(
                    select(QuizSession.__table__).where(QuizSession.id.in_([source.source_id, source.other_id])).order_by(QuizSession.id)
                )
            )
            .mappings()
            .all()
        )
        answer_rows = (
            (
                await db.execute(
                    select(QuizAnswer.__table__)
                    .where(QuizAnswer.session_id.in_([source.source_id, source.other_id]))
                    .order_by(QuizAnswer.id)
                )
            )
            .mappings()
            .all()
        )
        return {
            "sessions": [dict(row) for row in session_rows],
            "answers": [dict(row) for row in answer_rows],
            "xp": await db.scalar(select(User.experience_points).where(User.id == source.user_id)),
        }


@pytest.mark.asyncio
@pytest.mark.parametrize("quiz_type", [QuizType.VOCABULARY, QuizType.GRAMMAR, QuizType.KANJI, QuizType.LISTENING])
async def test_wrong_review_uses_only_source_wrong_items_and_preserves_existing_records(
    wrong_review_sessions: async_sessionmaker[AsyncSession], quiz_type: QuizType
) -> None:
    source = await _seed_source(wrong_review_sessions, quiz_type=quiz_type, smart=quiz_type in {QuizType.GRAMMAR, QuizType.LISTENING})
    before = await _historical_snapshot(wrong_review_sessions, source)

    result = await _start(wrong_review_sessions, source)

    assert [item.question_id for item in result.questions] == [source.questions[0]["id"], source.questions[2]["id"]]
    assert result.answered_question_ids == []
    assert (result.correct_count, result.total_questions, result.quiz_type) == (0, 2, quiz_type.value)
    assert await _historical_snapshot(wrong_review_sessions, source) == before
    async with wrong_review_sessions() as db:
        review = await db.get(QuizSession, uuid.UUID(result.session_id))
        assert review is not None
        assert review.jlpt_level == JlptLevel.N5
        assert review.questions_data == {
            "mode": "wrong_answer_review",
            "source_session_id": str(source.source_id),
            "questions": [source.questions[0], source.questions[2]],
        }
        assert await db.scalar(select(func.count()).select_from(QuizAnswer)) == 3


@pytest.mark.asyncio
async def test_concurrent_wrong_review_starts_and_lost_response_retries_reuse_one_active_session(
    wrong_review_sessions: async_sessionmaker[AsyncSession],
) -> None:
    source = await _seed_source(wrong_review_sessions)
    before = await _historical_snapshot(wrong_review_sessions, source)

    results = await asyncio.wait_for(asyncio.gather(*(_start(wrong_review_sessions, source) for _ in range(4))), timeout=10)
    repeated = await _start(wrong_review_sessions, source)

    assert len({result.session_id for result in [*results, repeated]}) == 1
    assert await _historical_snapshot(wrong_review_sessions, source) == before
    async with wrong_review_sessions() as db:
        assert await db.scalar(select(func.count()).select_from(QuizSession)) == 3


@pytest.mark.asyncio
@pytest.mark.parametrize("quiz_type", [QuizType.VOCABULARY, QuizType.GRAMMAR])
async def test_wrong_review_partial_resume_and_completion_apply_new_answers_once_without_stage_completion(
    wrong_review_sessions: async_sessionmaker[AsyncSession], quiz_type: QuizType
) -> None:
    source = await _seed_source(wrong_review_sessions, quiz_type=quiz_type)
    before = await _historical_snapshot(wrong_review_sessions, source)
    started = await _start(wrong_review_sessions, source)
    review_id = uuid.UUID(started.session_id)
    first = QuizAnswerRequest(
        session_id=review_id,
        question_id=uuid.UUID(source.questions[0]["id"]),
        question_type=quiz_type,
        selected_option_id="correct-0",
    )
    async with wrong_review_sessions() as db:
        user = await db.get(User, source.user_id)
        assert user is not None
        await submit_quiz_answer(db, user, first)
        await submit_quiz_answer(db, user, first)
        banner = await get_incomplete_quiz_session(db, user)
        assert banner is not None
        assert (banner.id, banner.answered_count, banner.total_questions) == (started.session_id, 1, 2)
    resumed = await _start(wrong_review_sessions, source)
    assert resumed.session_id == started.session_id
    assert resumed.answered_question_ids == [source.questions[0]["id"]]
    assert (resumed.correct_count, resumed.total_questions) == (1, 2)
    assert await _historical_snapshot(wrong_review_sessions, source) == before
    async with wrong_review_sessions() as db:
        user = await db.get(User, source.user_id)
        assert user is not None
        await submit_quiz_answer(
            db,
            user,
            QuizAnswerRequest(
                session_id=review_id,
                question_id=uuid.UUID(source.questions[2]["id"]),
                question_type=quiz_type,
                selected_option_id="correct-2",
            ),
        )
        completed = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=review_id, stage_id=uuid.uuid4()))
        assert (completed.correct_count, completed.total_questions, completed.xp_earned) == (2, 2, 20)
        repeated = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=review_id))
        assert repeated.xp_earned == 0
        assert user.experience_points == 143
        assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == review_id)) == 2
        assert await db.scalar(select(func.count()).select_from(UserStudyStageProgress)) == 0
        assert await db.scalar(text("SELECT count(*) FROM review_events WHERE session_id = :session_id"), {"session_id": review_id}) == 2
        progress_model = UserGrammarProgress if quiz_type == QuizType.GRAMMAR else UserVocabProgress
        progress = (await db.scalars(select(progress_model).where(progress_model.user_id == source.user_id))).all()
        assert len(progress) == 2
        assert all((item.correct_count, item.incorrect_count) == (1, 0) for item in progress)
    after = await _historical_snapshot(wrong_review_sessions, source)
    assert after["sessions"] == before["sessions"]
    assert after["answers"] == before["answers"]
    new_attempt = await _start(wrong_review_sessions, source)
    assert new_attempt.session_id != started.session_id


@pytest.mark.asyncio
async def test_legacy_first_answers_and_snapshot_order_match_wrong_answer_display(
    wrong_review_sessions: async_sessionmaker[AsyncSession],
) -> None:
    source = await _seed_source(wrong_review_sessions, quiz_type=QuizType.GRAMMAR)
    async with wrong_review_sessions() as db:
        for index, (question_id, correct) in enumerate(
            [(source.questions[0]["id"], True), (source.questions[1]["id"], False), (str(uuid.uuid4()), False)]
        ):
            db.add(
                QuizAnswer(
                    session_id=source.source_id,
                    question_id=uuid.UUID(question_id),
                    question_type=QuizType.GRAMMAR,
                    selected_option_id=f"later-{index}",
                    is_correct=correct,
                    answered_at=datetime.now(UTC),
                )
            )
        await db.commit()
    before = await _historical_snapshot(wrong_review_sessions, source)

    started = await _start(wrong_review_sessions, source)
    async with wrong_review_sessions() as db:
        user = await db.get(User, source.user_id)
        assert user is not None
        displayed = await get_wrong_answers_data(db, user, session_id=str(source.source_id))

    expected = [source.questions[0]["id"], source.questions[2]["id"]]
    assert [item.question_id for item in started.questions] == expected
    assert [item.question_id for item in displayed] == expected
    assert [item.word for item in displayed] == ["問題0", "問題2"]
    assert await _historical_snapshot(wrong_review_sessions, source) == before


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "failure",
    [
        "missing",
        "foreign",
        "unfinished",
        "partial",
        "no-wrong",
        "deleted-content",
        "bad-snapshot",
        "answer-type",
        "wrong-grade",
        "unknown-option",
    ],
)
async def test_invalid_wrong_review_source_fails_without_changing_learning_records(
    wrong_review_sessions: async_sessionmaker[AsyncSession], failure: str
) -> None:
    source = await _seed_source(wrong_review_sessions)
    requested_id = source.source_id
    async with wrong_review_sessions() as db:
        session = await db.get(QuizSession, source.source_id)
        assert session is not None
        if failure == "missing":
            requested_id = uuid.uuid4()
        elif failure == "foreign":
            other_user_id = uuid.uuid4()
            db.add(User(id=other_user_id, email=f"{other_user_id}@example.test", nickname="다른 사용자"))
            await db.flush()
            session.user_id = other_user_id
        elif failure == "unfinished":
            session.completed_at = None
        elif failure == "partial":
            answer = await db.scalar(select(QuizAnswer).where(QuizAnswer.session_id == source.source_id).limit(1))
            assert answer is not None
            await db.delete(answer)
        elif failure == "no-wrong":
            for answer in (await db.scalars(select(QuizAnswer).where(QuizAnswer.session_id == source.source_id))).all():
                index = next(index for index, question in enumerate(source.questions) if question["id"] == str(answer.question_id))
                answer.selected_option_id = f"correct-{index}"
                answer.is_correct = True
        elif failure == "deleted-content":
            content = await db.get(Vocabulary, uuid.UUID(source.questions[1]["id"]))
            assert content is not None
            await db.delete(content)
        elif failure == "bad-snapshot":
            payload = deepcopy(session.questions_data)
            assert isinstance(payload, dict)
            payload["questions"][0]["correctOptionId"] = "not-an-option"
            session.questions_data = payload
        else:
            answer = await db.scalar(select(QuizAnswer).where(QuizAnswer.session_id == source.source_id).limit(1))
            assert answer is not None
            if failure == "answer-type":
                answer.question_type = QuizType.GRAMMAR
            elif failure == "wrong-grade":
                answer.is_correct = not answer.is_correct
            else:
                answer.selected_option_id = "not-an-option"
        await db.commit()
    before = await _historical_snapshot(wrong_review_sessions, source)
    async with wrong_review_sessions() as db:
        user = await db.get(User, source.user_id)
        assert user is not None
        with pytest.raises(QuizQueryServiceError) as error:
            await start_wrong_answer_review(db, user, QuizWrongReviewRequest(source_session_id=requested_id))
        assert error.value.status_code == (404 if failure in {"missing", "foreign"} else 409)
    assert await _historical_snapshot(wrong_review_sessions, source) == before
    async with wrong_review_sessions() as db:
        assert await db.scalar(select(func.count()).select_from(QuizSession)) == 2
        assert await db.scalar(select(func.count()).select_from(UserVocabProgress)) == 0
        assert await db.scalar(text("SELECT count(*) FROM review_events")) == 0


@pytest.mark.asyncio
@pytest.mark.parametrize("quiz_type", [QuizType.KANA, QuizType.CLOZE, QuizType.SENTENCE_ARRANGE])
async def test_special_quiz_source_is_explicitly_unsupported_without_general_review_fallback(
    wrong_review_sessions: async_sessionmaker[AsyncSession], quiz_type: QuizType
) -> None:
    source = await _seed_source(wrong_review_sessions, quiz_type=quiz_type)
    before = await _historical_snapshot(wrong_review_sessions, source)

    with pytest.raises(QuizQueryServiceError) as error:
        await _start(wrong_review_sessions, source)

    assert error.value.status_code == 400
    assert await _historical_snapshot(wrong_review_sessions, source) == before
    async with wrong_review_sessions() as db:
        assert await db.scalar(select(func.count()).select_from(QuizSession)) == 2


@pytest.mark.asyncio
async def test_completed_wrong_review_can_be_the_source_of_its_own_remaining_wrong_items(
    wrong_review_sessions: async_sessionmaker[AsyncSession],
) -> None:
    source = await _seed_source(wrong_review_sessions)
    first_review = await _start(wrong_review_sessions, source)
    async with wrong_review_sessions() as db:
        user = await db.get(User, source.user_id)
        assert user is not None
        for index, correct in [(0, True), (2, False)]:
            await submit_quiz_answer(
                db,
                user,
                QuizAnswerRequest(
                    session_id=uuid.UUID(first_review.session_id),
                    question_id=uuid.UUID(source.questions[index]["id"]),
                    question_type=QuizType.VOCABULARY,
                    selected_option_id=f"correct-{index}" if correct else f"wrong-{index}",
                ),
            )
        await complete_quiz_session(db, user, QuizCompleteRequest(session_id=uuid.UUID(first_review.session_id)))
        next_review = await start_wrong_answer_review(
            db, user, QuizWrongReviewRequest(source_session_id=uuid.UUID(first_review.session_id))
        )
        assert [question.question_id for question in next_review.questions] == [source.questions[2]["id"]]
        assert next_review.total_questions == 1
        assert user.experience_points == 133


@pytest.mark.asyncio
async def test_existing_general_start_policy_can_close_a_wrong_review_then_explicit_retry_creates_a_new_attempt(
    wrong_review_sessions: async_sessionmaker[AsyncSession],
) -> None:
    source = await _seed_source(wrong_review_sessions)
    first_review = await _start(wrong_review_sessions, source)
    async with wrong_review_sessions() as db:
        user = await db.get(User, source.user_id)
        assert user is not None
        await submit_quiz_answer(
            db,
            user,
            QuizAnswerRequest(
                session_id=uuid.UUID(first_review.session_id),
                question_id=uuid.UUID(source.questions[0]["id"]),
                question_type=QuizType.VOCABULARY,
                selected_option_id="correct-0",
            ),
        )
        await start_quiz_session(db, user, QuizStartRequest(quiz_type=QuizType.VOCABULARY, jlpt_level=JlptLevel.N5, count=1))
        previous = await db.get(QuizSession, uuid.UUID(first_review.session_id), populate_existing=True)
        assert previous is not None and previous.completed_at is not None
    next_review = await _start(wrong_review_sessions, source)
    assert next_review.session_id != first_review.session_id
    assert next_review.answered_question_ids == []


@pytest.mark.asyncio
async def test_existing_incomplete_timeout_policy_remains_unchanged_for_wrong_reviews(
    wrong_review_sessions: async_sessionmaker[AsyncSession],
) -> None:
    source = await _seed_source(wrong_review_sessions)
    first_review = await _start(wrong_review_sessions, source)
    async with wrong_review_sessions() as db:
        review = await db.get(QuizSession, uuid.UUID(first_review.session_id))
        assert review is not None
        review.started_at = datetime.now(UTC) - timedelta(hours=25)
        await db.commit()
        user = await db.get(User, source.user_id)
        assert user is not None
        assert await get_incomplete_quiz_session(db, user) is None
        assert review.completed_at is not None
        assert user.experience_points == 123
    next_review = await _start(wrong_review_sessions, source)
    assert next_review.session_id != first_review.session_id
