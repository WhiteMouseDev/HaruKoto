"""Long-lived resume uses real isolated PostgreSQL; production is never queried."""

from __future__ import annotations

import asyncio
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select

from app.models import DailyProgress, QuizAnswer, QuizSession, Vocabulary
from app.models.enums import JlptLevel, QuizType
from app.models.user import User
from app.schemas.quiz import QuizCompleteRequest, QuizResumeRequest
from app.services.quiz_answer import QuizAnswerServiceError
from app.services.quiz_complete import QuizCompleteServiceError, complete_quiz_session
from app.services.quiz_session_query import resume_quiz_session
from app.services.study_activity import has_study_activity
from app.utils.date import study_date_kst
from tests.test_quiz_wrong_review_postgres import wrong_review_postgres_url as wrong_review_postgres_url
from tests.test_quiz_wrong_review_postgres import wrong_review_sessions as wrong_review_sessions
from tests.test_special_quiz_resume_postgres import answer, api, seed, snapshot


async def start_matching(sessions):
    user_id, _ = await seed(sessions)
    async with api(sessions, user_id) as client:
        response = await client.post(
            "/api/v1/quiz/start", json={"quizType": "VOCABULARY", "jlptLevel": "N5", "mode": "matching", "count": 3}
        )
        assert response.status_code == 200
    session_id = uuid.UUID(response.json()["sessionId"])
    async with sessions() as db:
        session = await db.get(QuizSession, session_id)
        questions = session.questions_data["questions"]
    return user_id, session_id, questions


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "age",
    [
        timedelta(hours=24, microseconds=-1),
        timedelta(hours=24),
        timedelta(hours=24, microseconds=1),
        timedelta(days=3),
        timedelta(days=7),
        timedelta(days=30),
    ],
    ids=["before-24h", "exact-24h", "after-24h", "3-days", "7-days", "30-days"],
)
async def test_old_quiz_listing_and_cold_resume_do_not_change_any_learning_record(wrong_review_sessions, age):
    sessions = wrong_review_sessions
    user_id, session_id, questions = await start_matching(sessions)
    await answer(sessions, user_id, session_id, questions[0], correct=False)
    async with sessions() as db:
        stored = await db.get(QuizSession, session_id)
        stored.started_at = datetime.now(UTC) - age
        await db.commit()
    baseline = await snapshot(sessions)
    async with api(sessions, user_id) as client:
        banner = (await client.get("/api/v1/quiz/incomplete")).json()["session"]
        page = (await client.get("/api/v1/quiz/incomplete-sessions")).json()
        assert banner["id"] == str(session_id)
        assert page["sessions"][0]["id"] == str(session_id)
        assert page["sessions"][0]["remainingCount"] == 2
        assert "correctCount" not in page["sessions"][0]
        assert page["nextCursor"] is None
    async with sessions() as db:
        resumed = await resume_quiz_session(db, await db.get(User, user_id), QuizResumeRequest(session_id=session_id))
        assert resumed.answered_question_ids == [questions[0]["id"]]
        assert [q.question_id for q in resumed.questions] == [q["id"] for q in questions]
    assert await snapshot(sessions) == baseline


@pytest.mark.asyncio
async def test_starting_another_regular_or_smart_quiz_preserves_saved_answers_srs_and_xp(wrong_review_sessions):
    sessions = wrong_review_sessions
    user_id, first_id, questions = await start_matching(sessions)
    await answer(sessions, user_id, first_id, questions[0], correct=True)
    baseline = await snapshot(sessions)
    async with api(sessions, user_id) as client:
        for path, body in [
            ("/api/v1/quiz/start", {"quizType": "VOCABULARY", "jlptLevel": "N5", "count": 2}),
            ("/api/v1/quiz/smart-start", {"category": "VOCABULARY", "jlptLevel": "N5", "count": 2}),
        ]:
            response = await client.post(path, json=body)
            assert response.status_code == 200, response.text
            assert response.json()["sessionId"] != str(first_id)
        # An unsupported/failed start must not settle or close the prior quiz either.
        failed = await client.post("/api/v1/quiz/start", json={"quizType": "KANJI", "jlptLevel": "N5", "mode": "matching"})
        assert failed.status_code == 400
        resumed = await client.post("/api/v1/quiz/resume", json={"sessionId": str(first_id)})
        assert resumed.status_code == 200
    after = await snapshot(sessions)
    for table in baseline:
        if table != "quiz_sessions":
            assert after[table] == baseline[table], table
    assert next(row for row in after["quiz_sessions"] if row["id"] == str(first_id)) == baseline["quiz_sessions"][0]


@pytest.mark.asyncio
async def test_eligibility_before_limit_cursor_ties_filter_validation_and_owner_scope(wrong_review_sessions):
    sessions = wrong_review_sessions
    user_id, first_id, questions = await start_matching(sessions)
    await answer(sessions, user_id, first_id, questions[0], correct=True)
    tied_time = datetime.now(UTC) - timedelta(days=30)
    eligible_ids = [first_id, uuid.uuid4(), uuid.uuid4()]
    other_id = uuid.uuid4()
    async with sessions() as db:
        first = await db.get(QuizSession, first_id)
        first.started_at = tied_time
        db.add(User(id=other_id, email=f"{other_id}@example.test", nickname="다른 계정"))
        await db.flush()
        for index in range(28):
            saved = QuizSession(
                id=eligible_ids[index - 26] if index >= 27 else uuid.uuid4(),
                user_id=user_id,
                quiz_type=QuizType.KANA if index == 26 else QuizType.VOCABULARY,
                jlpt_level=JlptLevel.N5,
                total_questions=3,
                questions_data=first.questions_data,
                started_at=tied_time if index == 27 else datetime.now(UTC),
            )
            db.add(saved)
            await db.flush()
            if index >= 26:
                db.add(
                    QuizAnswer(
                        session_id=saved.id,
                        question_id=uuid.UUID(questions[0]["id"]),
                        question_type=saved.quiz_type,
                        selected_option_id="wrong",
                        is_correct=False,
                    )
                )
        # A third eligible row with an unsupported snapshot must remain visible.
        db.add(
            QuizSession(
                id=eligible_ids[2],
                user_id=user_id,
                quiz_type=QuizType.VOCABULARY,
                jlpt_level=JlptLevel.N5,
                total_questions=3,
                questions_data=None,
                started_at=tied_time,
            )
        )
        await db.flush()
        db.add(
            QuizAnswer(
                session_id=eligible_ids[2],
                question_id=uuid.UUID(questions[0]["id"]),
                question_type=QuizType.VOCABULARY,
                selected_option_id="wrong",
                is_correct=False,
            )
        )
        await db.commit()
    baseline = await snapshot(sessions)
    seen = []
    cursor = None
    async with api(sessions, user_id) as client:
        for _ in range(3):
            params = {"limit": 1, "quizType": "VOCABULARY", "jlptLevel": "N5"}
            if cursor:
                params["cursor"] = cursor
            response = await client.get("/api/v1/quiz/incomplete-sessions", params=params)
            assert response.status_code == 200
            data = response.json()
            assert len(data["sessions"]) == 1
            seen.append(uuid.UUID(data["sessions"][0]["id"]))
            cursor = data["nextCursor"]
        assert cursor is None
        assert seen == sorted(eligible_ids, reverse=True)
        first_page = (await client.get("/api/v1/quiz/incomplete-sessions", params={"limit": 1})).json()
        cursor = first_page["nextCursor"]
        assert (await client.get("/api/v1/quiz/incomplete-sessions", params={"cursor": cursor, "jlptLevel": "N4"})).status_code == 400
        for bad in ["bad!", "e30", "W10"]:
            assert (await client.get("/api/v1/quiz/incomplete-sessions", params={"cursor": bad})).status_code == 400
        assert (await client.get("/api/v1/quiz/incomplete-sessions", params={"limit": 51})).status_code == 422
        assert (await client.get("/api/v1/quiz/incomplete-sessions", params={"quizType": "INVALID"})).status_code == 422
    async with api(sessions, other_id) as client:
        assert (await client.get("/api/v1/quiz/incomplete-sessions", params={"cursor": cursor})).json()["sessions"] == []
    assert await snapshot(sessions) == baseline


@pytest.mark.asyncio
async def test_deleted_pending_catalogue_returns_preserving_conflict_but_saved_retry_stays_valid(wrong_review_sessions):
    sessions = wrong_review_sessions
    user_id, session_id, questions = await start_matching(sessions)
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    async with sessions() as db:
        await db.delete(await db.get(Vocabulary, uuid.UUID(questions[1]["id"])))
        await db.commit()
    baseline = await snapshot(sessions)
    async with api(sessions, user_id) as client:
        item = (await client.get("/api/v1/quiz/incomplete-sessions")).json()["sessions"][0]
        assert (item["resumeStatus"], item["resumeReason"], item["remainingCount"]) == ("invalid_snapshot", "CONTENT_UNAVAILABLE", None)
        assert (await client.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})).status_code == 409
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    with pytest.raises(QuizAnswerServiceError) as error:
        await answer(sessions, user_id, session_id, questions[1], correct=True)
    assert error.value.status_code == 409
    assert await snapshot(sessions) == baseline


@pytest.mark.asyncio
async def test_concurrent_completion_waits_for_answers_and_old_result_uses_saved_seconds_only(wrong_review_sessions):
    sessions = wrong_review_sessions
    user_id, session_id, questions = await start_matching(sessions)
    for question in questions:
        await answer(sessions, user_id, session_id, question, correct=True)
    old_time = datetime.now(UTC) - timedelta(days=7)
    async with sessions() as db:
        stored = await db.get(QuizSession, session_id)
        stored.started_at = old_time
        rows = list((await db.execute(select(QuizAnswer).where(QuizAnswer.session_id == session_id))).scalars().all())
        for row in rows:
            row.answered_at = old_time
            row.time_spent_seconds = 30
        db.add(
            QuizAnswer(
                session_id=session_id,
                question_id=rows[0].question_id,
                question_type=QuizType.VOCABULARY,
                selected_option_id=rows[0].selected_option_id,
                is_correct=True,
                time_spent_seconds=10000,
                answered_at=old_time + timedelta(seconds=1),
            )
        )
        # Saved answers suffice for finalization even when the catalog was deleted.
        for question in questions:
            await db.delete(await db.get(Vocabulary, uuid.UUID(question["id"])))
        user = await db.get(User, user_id)
        user.last_study_date = old_time
        await db.commit()

    async def complete():
        async with sessions() as db:
            return await complete_quiz_session(db, await db.get(User, user_id), QuizCompleteRequest(session_id=session_id))

    results = await asyncio.gather(complete(), complete())
    assert sorted(result.xp_earned for result in results) == [0, 30]
    async with sessions() as db:
        progress = (
            await db.execute(
                select(DailyProgress).where(DailyProgress.user_id == user_id, DailyProgress.date == study_date_kst(datetime.now(UTC)))
            )
        ).scalar_one()
        assert progress.study_minutes == 1
        assert progress.quizzes_completed == 1
        assert has_study_activity(progress)  # Preserve the actual activity day already recorded before this fixture moved its answers.


@pytest.mark.asyncio
async def test_complete_before_last_answer_is_retryable_and_does_not_close_session(wrong_review_sessions):
    sessions = wrong_review_sessions
    user_id, session_id, questions = await start_matching(sessions)
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    baseline = await snapshot(sessions)
    async with sessions() as db:
        with pytest.raises(QuizCompleteServiceError) as error:
            await complete_quiz_session(db, await db.get(User, user_id), QuizCompleteRequest(session_id=session_id))
        assert error.value.status_code == 409
    assert await snapshot(sessions) == baseline
    for question in questions[1:]:
        await answer(sessions, user_id, session_id, question, correct=True)
    async with sessions() as db:
        result = await complete_quiz_session(db, await db.get(User, user_id), QuizCompleteRequest(session_id=session_id))
        assert result.correct_count == 3


@pytest.mark.asyncio
@pytest.mark.parametrize("shape", ["legacy-question-id", "non-list", "non-object"])
async def test_malformed_snapshot_rejects_new_writes_but_preserves_saved_answer_retry(wrong_review_sessions, shape):
    sessions = wrong_review_sessions
    user_id, session_id, questions = await start_matching(sessions)
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    async with sessions() as db:
        session = await db.get(QuizSession, session_id)
        if shape == "legacy-question-id":
            session.questions_data = [{"questionId": question["id"]} for question in questions]
        elif shape == "non-list":
            session.questions_data = {"questions": 7}
        else:
            session.questions_data = ["invalid", questions[1], questions[2]]
        await db.commit()
    before = await snapshot(sessions)
    # A durable answer receipt is authoritative even after snapshot corruption.
    assert (await answer(sessions, user_id, session_id, questions[0], correct=True)).success
    with pytest.raises(QuizAnswerServiceError) as new_answer:
        await answer(sessions, user_id, session_id, questions[1], correct=True)
    assert new_answer.value.status_code == 409
    async with sessions() as db:
        with pytest.raises(QuizCompleteServiceError) as completion:
            await complete_quiz_session(db, await db.get(User, user_id), QuizCompleteRequest(session_id=session_id))
        assert completion.value.status_code == 409
    assert await snapshot(sessions) == before


@pytest.mark.asyncio
async def test_completed_result_replay_does_not_require_unchanged_snapshot(wrong_review_sessions):
    sessions = wrong_review_sessions
    user_id, session_id, questions = await start_matching(sessions)
    for question in questions:
        await answer(sessions, user_id, session_id, question, correct=True)
    async with sessions() as db:
        assert (await complete_quiz_session(db, await db.get(User, user_id), QuizCompleteRequest(session_id=session_id))).xp_earned == 30
        stored = await db.get(QuizSession, session_id)
        stored.questions_data = {"unknownSerializer": True}
        await db.commit()
    before = await snapshot(sessions)
    async with sessions() as db:
        restored = await complete_quiz_session(db, await db.get(User, user_id), QuizCompleteRequest(session_id=session_id))
        assert restored.xp_earned == 0 and restored.correct_count == 3
    assert await snapshot(sessions) == before
