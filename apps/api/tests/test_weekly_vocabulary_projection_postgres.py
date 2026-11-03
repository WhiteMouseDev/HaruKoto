"""Read-only grouped weekly projection on legacy and aware PostgreSQL clocks."""

from datetime import UTC, date, datetime, time, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import event, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.base import Base
from app.models import DailyProgress, QuizAnswer, QuizSession
from app.models.enums import JlptLevel, QuizType
from app.models.user import User
from app.services.stats_dashboard import _get_weekly_stats
from app.services.vocabulary_goal import get_vocabulary_answered_counts, get_vocabulary_goal
from app.utils.date import KST
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url


@pytest.mark.parametrize("today", [date(2026, 11, 2), date(2027, 1, 1)], ids=["month-boundary", "year-boundary"])
@pytest.mark.parametrize(
    "legacy_timestamp,session_timezone",
    [(False, "Asia/Seoul"), (False, "America/Los_Angeles"), (True, "Asia/Seoul"), (True, "America/Los_Angeles")],
    ids=["aware-kst", "aware-la", "legacy-kst", "legacy-la"],
)
async def test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history(
    isolated_postgres_url, today, legacy_timestamp, session_timezone
):
    admin = create_async_engine(isolated_postgres_url)
    schema = "weekly_saved_" + uuid4().hex
    engine = create_async_engine(
        isolated_postgres_url, connect_args={"server_settings": {"search_path": schema, "timezone": session_timezone}}
    )
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    start_day = today - timedelta(days=6)
    start = datetime.combine(start_day, time.min, tzinfo=KST).astimezone(UTC)
    end = datetime.combine(today + timedelta(days=1), time.min, tzinfo=KST).astimezone(UTC)
    uid, foreign = uuid4(), uuid4()
    statements = []

    def capture(conn, cursor, statement, params, ctx, many):
        statements.append(statement)

    try:
        async with admin.begin() as c:
            await c.execute(text(f'CREATE SCHEMA "{schema}"'))
        async with engine.begin() as c:
            await c.run_sync(Base.metadata.create_all)
        async with sessions() as db:
            db.add_all(
                [
                    User(id=uid, email=f"{uid}@example.test", experience_points=444, streak_count=3, longest_streak=8),
                    User(id=foreign, email=f"{foreign}@example.test"),
                ]
            )
            await db.flush()

            async def session(owner=uid, kind=QuizType.VOCABULARY):
                value = QuizSession(
                    id=uuid4(), user_id=owner, quiz_type=kind, jlpt_level=JlptLevel.N5, total_questions=20, questions_data=[]
                )
                db.add(value)
                await db.flush()
                return value.id

            def answer(sid, qid, at, kind=QuizType.VOCABULARY, correct=False):
                db.add(
                    QuizAnswer(
                        session_id=sid,
                        question_id=qid,
                        question_type=kind,
                        selected_option_id="wrong" if not correct else "right",
                        is_correct=correct,
                        answered_at=at,
                    )
                )

            sid = await session()
            repeated = uuid4()
            answer(sid, repeated, start)
            answer(sid, repeated, start + timedelta(seconds=1), correct=True)
            another = await session()
            answer(another, repeated, start + timedelta(hours=1))
            answer(sid, repeated, start + timedelta(days=4))
            answer(sid, uuid4(), end - timedelta(milliseconds=1))
            answer(sid, uuid4(), start - timedelta(milliseconds=1))
            answer(sid, uuid4(), end)
            fsid = await session(foreign)
            answer(fsid, uuid4(), start + timedelta(hours=1))
            for kind in QuizType:
                if kind == QuizType.VOCABULARY:
                    continue
                excluded = await session(kind=kind)
                answer(excluded, uuid4(), start + timedelta(days=1), kind=kind)
                answer(excluded, uuid4(), start + timedelta(days=1))
                answer(sid, uuid4(), start + timedelta(days=1), kind=kind)
            db.add_all(
                [
                    DailyProgress(user_id=uid, date=start_day + timedelta(days=1), grammar_studied=1),
                    DailyProgress(user_id=uid, date=start_day + timedelta(days=2), kana_learned=1),
                    DailyProgress(user_id=uid, date=start_day + timedelta(days=3), activity_recorded=True),
                    DailyProgress(user_id=uid, date=start_day + timedelta(days=4), words_studied=5, xp_earned=50),
                ]
            )
            await db.commit()
        if legacy_timestamp:
            async with engine.begin() as c:
                await c.execute(
                    text(
                        "ALTER TABLE quiz_answers ALTER COLUMN answered_at TYPE TIMESTAMP(3) WITHOUT TIME ZONE "
                        "USING answered_at AT TIME ZONE 'UTC'"
                    )
                )

        async def state():
            async with engine.connect() as c:
                return await c.scalar(
                    text("""SELECT jsonb_build_object(
                  'users',(SELECT jsonb_agg(to_jsonb(u) ORDER BY id) FROM users u),
                  'sessions',(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM quiz_sessions s),
                  'answers',(SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM quiz_answers a),
                  'daily',(SELECT jsonb_agg(to_jsonb(d) ORDER BY id) FROM daily_progress d))""")
                )

        before = await state()
        event.listen(engine.sync_engine, "before_cursor_execute", capture)
        async with sessions() as db:
            weekly = await _get_weekly_stats(db, user_id=uid, today=today)
        event.remove(engine.sync_engine, "before_cursor_execute", capture)
        assert len(statements) == 2 and sum("GROUP BY" in s for s in statements) == 1
        assert all(s.lstrip().upper().startswith("SELECT") for s in statements)
        assert [item.date for item in weekly] == [str(start_day + timedelta(days=i)) for i in range(7)]
        assert [item.vocabulary_answered_count for item in weekly] == [1, 0, 0, 0, 1, 0, 1]
        assert sum(item.vocabulary_answered_count for item in weekly) == 3
        assert [item.has_studied for item in weekly] == [False, True, True, True, True, False, False]
        assert weekly[4].words_studied == 5 and weekly[4].xp_earned == 50
        async with sessions() as db:
            counts = await get_vocabulary_answered_counts(db, user_id=uid, start_day=start_day, end_day=today)
            for i, item in enumerate(weekly):
                goal = await get_vocabulary_goal(db, user_id=uid, day=start_day + timedelta(days=i))
                assert item.vocabulary_answered_count == goal.answered_count
            foreign_counts = await get_vocabulary_answered_counts(db, user_id=foreign, start_day=start_day, end_day=today)
        assert foreign_counts == {start_day: 1}
        assert counts == {start_day: 1, start_day + timedelta(days=4): 1, today: 1}
        # Exact native web expression shares the API's epoch/KST/ownership rules.
        async with engine.connect() as c:
            web = (
                await c.execute(
                    text("""SELECT FLOOR((EXTRACT(EPOCH FROM answer.answered_at)+32400)/86400)::integer AS bucket,
              COUNT(DISTINCT answer.question_id)::integer AS count FROM quiz_answers AS answer
              JOIN quiz_sessions AS session ON session.id=answer.session_id
              WHERE session.user_id=:uid AND session.quiz_type='VOCABULARY' AND answer.question_type='VOCABULARY'
              AND EXTRACT(EPOCH FROM answer.answered_at)>=:start AND EXTRACT(EPOCH FROM answer.answered_at)<:end
              GROUP BY 1 ORDER BY 1"""),
                    {"uid": uid, "start": start.timestamp(), "end": end.timestamp()},
                )
            ).all()
        assert {date(1970, 1, 1) + timedelta(days=row[0]): row[1] for row in web} == counts
        assert await state() == before
    finally:
        await engine.dispose()
        async with admin.begin() as c:
            await c.execute(text(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE'))
        await admin.dispose()
