"""Dashboard vocabulary goal regressions on disposable PostgreSQL only."""

from __future__ import annotations

import uuid
from collections.abc import AsyncIterator
from datetime import UTC, date, datetime, timedelta

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import event, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.base import Base
from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import DailyProgress, QuizAnswer, QuizSession
from app.models.enums import JlptLevel, QuizType
from app.models.user import User
from app.routers.quiz import router as quiz_router
from app.routers.stats import router
from app.services import quiz_smart, stats_dashboard
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("legacy_timestamp", "session_timezone"),
    [(False, "Asia/Seoul"), (False, "America/Los_Angeles"), (True, "Asia/Seoul"), (True, "America/Los_Angeles")],
    ids=["aware-korea", "aware-los-angeles", "legacy-korea", "legacy-los-angeles"],
)
async def test_dashboard_vocabulary_goal_counts_distinct_saved_words_by_kst_answer_day(
    isolated_postgres_url: str, monkeypatch: pytest.MonkeyPatch, legacy_timestamp: bool, session_timezone: str
) -> None:
    today = date(2026, 10, 30)
    start = datetime(2026, 10, 29, 15, tzinfo=UTC)
    end = start + timedelta(days=1)
    monkeypatch.setattr(stats_dashboard, "get_today_kst", lambda: today)
    monkeypatch.setattr(quiz_smart, "get_today_kst", lambda: today)
    admin_engine = create_async_engine(isolated_postgres_url)
    schema = f"vocabulary_goal_{uuid.uuid4().hex}"
    engine = create_async_engine(
        isolated_postgres_url, connect_args={"server_settings": {"search_path": schema, "timezone": session_timezone}}
    )
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id, other_user_id, empty_user_id = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    authenticated_user_id = user_id
    statements: list[str] = []

    def capture_statement(_connection, _cursor, statement, _parameters, _context, _executemany):
        statements.append(statement)

    app = FastAPI()
    app.include_router(router)
    app.include_router(quiz_router)

    async def test_db() -> AsyncIterator[AsyncSession]:
        async with sessions() as db:
            yield db

    async def test_user() -> User:
        async with sessions() as db:
            user = await db.get(User, authenticated_user_id)
            assert user is not None
            return user

    app.dependency_overrides[get_db] = test_db
    app.dependency_overrides[get_current_user] = test_user
    try:
        async with admin_engine.begin() as connection:
            await connection.execute(text(f'CREATE SCHEMA "{schema}"'))
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with sessions() as db:
            db.add_all(
                [
                    User(
                        id=user_id,
                        email=f"{user_id}@example.test",
                        nickname="오늘 단어 목표",
                        daily_goal=10,
                        experience_points=200,
                        streak_count=3,
                        longest_streak=8,
                        last_study_date=start - timedelta(hours=1),
                    ),
                    User(id=other_user_id, email=f"{other_user_id}@example.test"),
                    User(id=empty_user_id, email=f"{empty_user_id}@example.test"),
                ]
            )
            await db.flush()
            db.add(
                DailyProgress(
                    user_id=user_id,
                    date=today,
                    words_studied=2,
                    quizzes_completed=1,
                    correct_answers=3,
                    total_answers=4,
                    conversation_count=1,
                    xp_earned=70,
                )
            )

            async def add_session(
                *,
                owner: uuid.UUID = user_id,
                quiz_type: QuizType = QuizType.VOCABULARY,
                level: JlptLevel = JlptLevel.N5,
                completed_at: datetime | None = None,
                review: bool = False,
            ) -> QuizSession:
                session = QuizSession(
                    user_id=owner,
                    quiz_type=quiz_type,
                    jlpt_level=level,
                    total_questions=20,
                    started_at=start - timedelta(days=1),
                    completed_at=completed_at,
                    questions_data={"mode": "wrong-review", "questions": []} if review else [],
                )
                db.add(session)
                await db.flush()
                return session

            def add_answer(
                session: QuizSession,
                at: datetime,
                *,
                question_id: uuid.UUID | None = None,
                question_type: QuizType = QuizType.VOCABULARY,
                correct: bool = False,
            ) -> uuid.UUID:
                word_id = question_id or uuid.uuid4()
                db.add(
                    QuizAnswer(
                        session_id=session.id,
                        question_id=word_id,
                        question_type=question_type,
                        selected_option_id="correct" if correct else "wrong",
                        is_correct=correct,
                        answered_at=at,
                    )
                )
                return word_id

            ongoing = await add_session()
            repeated_word = add_answer(ongoing, start)  # Inclusive KST midnight; incorrect and unfinished counts.
            add_answer(ongoing, start + timedelta(minutes=1), question_id=repeated_word, correct=True)
            review = await add_session(level=JlptLevel.N1, completed_at=end + timedelta(days=1), review=True)
            add_answer(review, start + timedelta(hours=1), question_id=repeated_word)
            add_answer(review, end - timedelta(milliseconds=1), correct=True)  # Last legacy millisecond belongs to today.
            for level in [JlptLevel.N2, JlptLevel.N3, JlptLevel.N4]:
                session = await add_session(level=level, completed_at=start + timedelta(hours=2))
                add_answer(session, start + timedelta(hours=1), correct=level == JlptLevel.N2)
            # Answer time, rather than session completion time, owns the learning day.
            add_answer(ongoing, start - timedelta(milliseconds=1))
            add_answer(ongoing, end)  # Exclusive next KST midnight.
            await add_session()  # An unanswered quiz has no vocabulary activity.
            foreign = await add_session(owner=other_user_id)
            add_answer(foreign, start + timedelta(hours=1))
            # Session and answer must both be vocabulary, even for corrupt legacy pairs.
            for excluded_type in QuizType:
                if excluded_type == QuizType.VOCABULARY:
                    continue
                excluded = await add_session(quiz_type=excluded_type)
                add_answer(excluded, start + timedelta(hours=1), question_type=excluded_type)
                add_answer(excluded, start + timedelta(hours=1))
                add_answer(ongoing, start + timedelta(hours=1), question_type=excluded_type)
            await db.commit()
        if legacy_timestamp:
            async with engine.begin() as connection:
                await connection.execute(
                    text(
                        "ALTER TABLE quiz_answers ALTER COLUMN answered_at TYPE TIMESTAMP(3) WITHOUT TIME ZONE "
                        "USING answered_at AT TIME ZONE 'UTC'"
                    )
                )

        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            history_before = await client.get("/api/v1/stats/history", params={"year": 2026, "month": 10})
            event.listen(engine.sync_engine, "before_cursor_execute", capture_statement)
            response = await client.get("/api/v1/stats/dashboard")
            event.remove(engine.sync_engine, "before_cursor_execute", capture_statement)
            assert response.status_code == 200, response.text
            payload = response.json()
            assert payload["today"] == {
                "wordsStudied": 2,
                "quizzesCompleted": 1,
                "correctAnswers": 3,
                "totalAnswers": 4,
                "xpEarned": 70,
                "goalProgress": 0.7,
                "hasStudied": True,
                "vocabularyGoal": {"date": "2026-10-30", "answeredCount": 5},
            }
            assert payload["streak"] == {"current": 3, "longest": 8, "studiedToday": True, "needsActionToday": False}
            assert payload["weeklyStats"][-1] == {"date": "2026-10-30", "wordsStudied": 2, "xpEarned": 70, "hasStudied": True}
            assert payload["showKana"] is False
            assert payload["levelProgress"] == {
                "vocabulary": {"total": 0, "mastered": 0, "inProgress": 0},
                "grammar": {"total": 0, "mastered": 0, "inProgress": 0},
            }
            assert payload["kanaProgress"] == {
                "hiragana": {"learned": 0, "mastered": 0, "total": 0},
                "katakana": {"learned": 0, "mastered": 0, "total": 0},
            }
            assert len(statements) == 11  # Existing ten dashboard/auth reads plus one bounded aggregate.
            assert all(statement.lstrip().upper().startswith("SELECT") for statement in statements)
            preview = await client.get("/api/v1/quiz/smart-preview", params={"category": "VOCABULARY", "jlptLevel": "N5"})
            assert preview.status_code == 200, preview.text
            assert preview.json()["todayCompleted"] == payload["today"]["vocabularyGoal"]["answeredCount"] == 5
            assert preview.json()["dailyGoal"] == 10
            assert preview.json()["sessionDistribution"] == {"new": 5, "review": 0, "retry": 0, "total": 5}
            assert preview.json()["poolSize"] == {"newReady": 0, "reviewDue": 0, "retryDue": 0}
            history_after = await client.get("/api/v1/stats/history", params={"year": 2026, "month": 10})
            assert history_before.status_code == history_after.status_code == 200
            assert history_before.json() == history_after.json()
            authenticated_user_id = other_user_id
            answer_only = await client.get("/api/v1/stats/dashboard")
            assert answer_only.status_code == 200
            assert answer_only.json()["today"] == {
                "wordsStudied": 0,
                "quizzesCompleted": 0,
                "correctAnswers": 0,
                "totalAnswers": 0,
                "xpEarned": 0,
                "goalProgress": 0.0,
                "hasStudied": False,
                "vocabularyGoal": {"date": "2026-10-30", "answeredCount": 1},
            }
            authenticated_user_id = user_id
            monkeypatch.setattr(stats_dashboard, "get_today_kst", lambda: today + timedelta(days=1))
            monkeypatch.setattr(quiz_smart, "get_today_kst", lambda: today + timedelta(days=1))
            next_day = await client.get("/api/v1/stats/dashboard")
            assert next_day.status_code == 200
            assert next_day.json()["today"]["vocabularyGoal"] == {"date": "2026-10-31", "answeredCount": 1}
            next_preview = await client.get("/api/v1/quiz/smart-preview", params={"category": "VOCABULARY", "jlptLevel": "N1"})
            assert next_preview.status_code == 200
            assert next_preview.json()["todayCompleted"] == next_day.json()["today"]["vocabularyGoal"]["answeredCount"] == 1
            assert next_preview.json()["sessionDistribution"] == {"new": 9, "review": 0, "retry": 0, "total": 9}
            authenticated_user_id = empty_user_id
            empty = await client.get("/api/v1/stats/dashboard")
            assert empty.status_code == 200
            assert empty.json()["today"]["vocabularyGoal"] == {"date": "2026-10-31", "answeredCount": 0}
            empty_preview = await client.get("/api/v1/quiz/smart-preview", params={"category": "VOCABULARY", "jlptLevel": "N5"})
            assert empty_preview.status_code == 200
            assert empty_preview.json()["todayCompleted"] == empty.json()["today"]["vocabularyGoal"]["answeredCount"] == 0
            assert empty_preview.json()["sessionDistribution"] == {"new": 10, "review": 0, "retry": 0, "total": 10}
        async with sessions() as db:
            user = await db.get(User, user_id)
            assert user is not None
            assert (user.experience_points, user.streak_count, user.longest_streak) == (200, 3, 8)
    finally:
        await engine.dispose()
        async with admin_engine.begin() as connection:
            await connection.execute(text(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE'))
        await admin_engine.dispose()
