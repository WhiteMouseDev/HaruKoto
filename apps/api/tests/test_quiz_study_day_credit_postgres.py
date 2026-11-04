"""Additive credit override and real delayed completion in disposable PostgreSQL."""

import asyncio
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.models import DailyProgress, QuizAnswer, QuizSession
from app.models.enums import JlptLevel, QuizType
from app.models.user import User
from app.routers.stats import get_history
from app.routers.user import get_profile
from app.schemas.kana import KanaProgressRecord
from app.schemas.quiz import QuizAnswerRequest, QuizCompleteRequest
from app.services import (
    kana_progress,
    lesson_study_activity,
    quiz_answer,
    quiz_complete,
    stats_dashboard,
    study_daily_goal,
    study_day_credit,
)
from app.services.stats_dashboard import get_dashboard_data
from app.services.stats_history import get_history_data
from app.services.study_day_recording import lock_study_user
from app.services.vocabulary_goal import get_vocabulary_goal
from app.utils.date import study_date_kst
from tests.test_lesson_study_day_postgres import (
    RUNTIME_REVISION,
    _answer,
    _complete_activity,
    _freeze,
    _kana_answer,
    _new_kana,
    _new_quiz,
    _record,
    _seed,
    _seed_activity,
    _state,
)
from tests.test_lesson_study_day_postgres import engine as engine
from tests.test_lesson_study_day_postgres import isolated_postgres_url as isolated_postgres_url
from tests.test_lesson_study_day_postgres import study_day_database as study_day_database
from tests.test_public_access_hardening_postgres import _alembic, _scalar

NOW = datetime(2026, 11, 3, 1, tzinfo=UTC)
OLD = NOW - timedelta(days=3)


@pytest.fixture(autouse=True)
def credit_policy_tests_explicitly_enable_separation(monkeypatch):
    # These cases exercise the reviewed ON policy, independently of the release
    # artifact's source gate. Compatible-OFF cases explicitly switch it below.
    monkeypatch.setattr(study_day_credit, "STUDY_DAY_CREDIT_SEPARATION_ENABLED", True)


async def _old_quiz(engine, attempt):
    sid = await _seed_activity(engine, attempt, "quiz")
    async with async_sessionmaker(engine)() as db:
        session = await db.get(QuizSession, sid)
        session.started_at = OLD
        answer = await db.scalar(select(QuizAnswer).where(QuizAnswer.session_id == sid))
        answer.answered_at = OLD
        answer.time_spent_seconds = 90
        await db.commit()
    return sid


async def _complete(engine, attempt, sid):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        return await quiz_complete.complete_quiz_session(db, await db.get(User, attempt.user_id), QuizCompleteRequest(session_id=sid))


async def test_delayed_completion_rewards_once_without_new_day_goal_srs_or_replay_effect(engine, monkeypatch):
    attempt = await _seed(engine)
    sid = await _old_quiz(engine, attempt)
    _freeze(monkeypatch, quiz_complete, NOW)
    monkeypatch.setattr(stats_dashboard, "get_today_kst", lambda: study_date_kst(NOW))
    before = await _state(engine, attempt.user_id)
    results = await asyncio.gather(_complete(engine, attempt, sid), _complete(engine, attempt, sid))
    assert sorted(result.xp_earned for result in results) == [0, 10]
    state = await _state(engine, attempt.user_id)
    assert state["user"]["streak_count"] == 0 and state["user"]["last_study_date"] is None
    assert state["user"]["experience_points"] == before["user"]["experience_points"] + 10
    assert state["daily"][0]["study_day_credited"] is False
    assert state["daily"][0]["xp_earned"] == 10 and state["daily"][0]["study_minutes"] == 1
    for key in ("quizAnswers", "words", "grammar", "events", "activities", "receipts"):
        assert state[key] == before[key], key
    async with async_sessionmaker(engine)() as db:
        user = await db.get(User, attempt.user_id)
        dashboard = await get_dashboard_data(db, user)
        history = await get_history_data(db, user_id=user.id, year=NOW.year, month=NOW.month)
        profile = await get_profile(user, db)
        assert dashboard.today.has_studied is False and dashboard.streak.studied_today is False
        assert dashboard.today.vocabulary_goal.answered_count == 0
        assert next(row for row in dashboard.weekly_stats if row.date == str(NOW.date())).has_studied is False
        assert history.records[0].has_studied is False and history.records[0].xp_earned == 10
        assert profile.summary.total_study_days == 0 and profile.summary.total_quizzes_completed == 1
    _freeze(monkeypatch, quiz_complete, NOW + timedelta(days=1))
    assert (await _complete(engine, attempt, sid)).xp_earned == 0
    assert await _state(engine, attempt.user_id) == state


@pytest.mark.parametrize(
    "credit,xp,expected",
    [(None, 0, False), (None, 20, True), (False, 20, False), (True, 0, True)],
    ids=["empty-legacy", "positive-legacy", "existing-false", "existing-true"],
)
async def test_late_completion_preserves_preexisting_day_before_adding_rewards(engine, monkeypatch, credit, xp, expected):
    attempt = await _seed(engine)
    sid = await _old_quiz(engine, attempt)
    async with async_sessionmaker(engine)() as db:
        db.add(DailyProgress(user_id=attempt.user_id, date=NOW.date(), study_day_credited=credit, xp_earned=xp))
        await db.commit()
    _freeze(monkeypatch, quiz_complete, NOW)
    await _complete(engine, attempt, sid)
    state = await _state(engine, attempt.user_id)
    assert state["daily"][0]["study_day_credited"] is expected
    assert state["daily"][0]["xp_earned"] == xp + 10
    assert state["user"]["streak_count"] == 0 and state["user"]["last_study_date"] is None


async def test_compatible_off_keeps_false_then_actual_answer_promotes_true(engine, monkeypatch):
    attempt = await _seed(engine)
    first = await _old_quiz(engine, attempt)
    second = await _old_quiz(engine, attempt)
    _freeze(monkeypatch, quiz_complete, NOW)
    await _complete(engine, attempt, first)
    monkeypatch.setattr(study_day_credit, "STUDY_DAY_CREDIT_SEPARATION_ENABLED", False)
    await _complete(engine, attempt, second)
    state = await _state(engine, attempt.user_id)
    assert state["daily"][0]["study_day_credited"] is False and state["daily"][0]["xp_earned"] == 20
    assert state["user"]["streak_count"] == 0
    _, body = await _new_quiz(engine, attempt)
    _freeze(monkeypatch, quiz_answer, NOW)
    await _answer(engine, attempt, body)
    fresh = await _state(engine, attempt.user_id)
    assert fresh["daily"][0]["study_day_credited"] is True and fresh["daily"][0]["xp_earned"] == 20
    assert fresh["user"]["streak_count"] == 1
    async with async_sessionmaker(engine)() as db:
        assert (await get_vocabulary_goal(db, user_id=attempt.user_id, day=NOW.date())).answered_count == 1
    monkeypatch.setattr(study_day_credit, "STUDY_DAY_CREDIT_SEPARATION_ENABLED", True)
    third = await _old_quiz(engine, attempt)
    await _complete(engine, attempt, third)
    assert (await _state(engine, attempt.user_id))["daily"][0]["study_day_credited"] is True


@pytest.mark.parametrize(
    "credit,expected,streak",
    [(None, True, 1), (False, False, 0), (True, True, 1)],
    ids=["new-day-keeps-legacy-credit", "stored-false-preserved", "stored-true-preserved"],
)
async def test_compatible_off_completion_preserves_credit_decisions(engine, monkeypatch, credit, expected, streak):
    monkeypatch.setattr(study_day_credit, "STUDY_DAY_CREDIT_SEPARATION_ENABLED", False)
    attempt = await _seed(engine)
    sid = await _old_quiz(engine, attempt)
    if credit is not None:
        async with async_sessionmaker(engine)() as db:
            db.add(DailyProgress(user_id=attempt.user_id, date=NOW.date(), study_day_credited=credit, xp_earned=20))
            await db.commit()
    _freeze(monkeypatch, quiz_complete, NOW)
    await _complete(engine, attempt, sid)
    state = await _state(engine, attempt.user_id)
    assert state["daily"][0]["study_day_credited"] is expected
    assert state["daily"][0]["xp_earned"] == (10 if credit is None else 30)
    assert state["user"]["streak_count"] == streak
    await _complete(engine, attempt, sid)
    assert await _state(engine, attempt.user_id) == state


@pytest.mark.parametrize("answer_first", [False, True], ids=["completion-first", "answer-first"])
async def test_delayed_completion_and_fresh_answer_share_lock_without_credit_demotion(engine, monkeypatch, answer_first):
    attempt = await _seed(engine)
    sid = await _old_quiz(engine, attempt)
    _, body = await _new_quiz(engine, attempt)
    _freeze(monkeypatch, quiz_complete, NOW)
    _freeze(monkeypatch, quiz_answer, NOW)
    entered, waiting, release = (asyncio.Event() for _ in range(3))

    async def first_lock(db, user):
        await lock_study_user(db, user)
        entered.set()
        await release.wait()

    async def second_lock(db, user):
        waiting.set()
        await lock_study_user(db, user)

    monkeypatch.setattr(quiz_answer if answer_first else quiz_complete, "lock_study_user", first_lock)
    monkeypatch.setattr(quiz_complete if answer_first else quiz_answer, "lock_study_user", second_lock)
    first = asyncio.create_task(_answer(engine, attempt, body) if answer_first else _complete(engine, attempt, sid))
    await asyncio.wait_for(entered.wait(), 10)
    second = asyncio.create_task(_complete(engine, attempt, sid) if answer_first else _answer(engine, attempt, body))
    try:
        await asyncio.wait_for(waiting.wait(), 10)
        assert not second.done()
    finally:
        release.set()
    await asyncio.wait_for(asyncio.gather(first, second), 15)
    state = await _state(engine, attempt.user_id)
    assert state["daily"][0]["study_day_credited"] is True
    assert state["daily"][0]["xp_earned"] == 10 and state["daily"][0]["quizzes_completed"] == 1
    assert state["user"]["streak_count"] == 1 and len(state["quizAnswers"]) == 2


@pytest.mark.parametrize("failure", ["before-commit", "response-lost"])
async def test_completion_credit_commit_failure_and_result_recovery_are_atomic(engine, monkeypatch, failure):
    attempt = await _seed(engine)
    sid = await _old_quiz(engine, attempt)
    _freeze(monkeypatch, quiz_complete, NOW)
    before = await _state(engine, attempt.user_id)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        commit = db.commit

        async def lost_response():
            await commit()
            raise RuntimeError("synthetic response loss")

        monkeypatch.setattr(db, "commit", lost_response if failure == "response-lost" else AsyncMock(side_effect=RuntimeError("synthetic")))
        with pytest.raises(RuntimeError):
            await quiz_complete.complete_quiz_session(db, await db.get(User, attempt.user_id), QuizCompleteRequest(session_id=sid))
    if failure == "before-commit":
        assert await _state(engine, attempt.user_id) == before
    result = await _complete(engine, attempt, sid)
    assert result.xp_earned == (10 if failure == "before-commit" else 0)
    state = await _state(engine, attempt.user_id)
    assert state["daily"][0]["study_day_credited"] is False and state["daily"][0]["xp_earned"] == 10
    assert state["user"]["streak_count"] == 0


@pytest.mark.parametrize("activity", ["lesson", "kana-answer", "kana-quiz", "kana-stage", "kana-progress", "conversation"])
async def test_other_genuine_activity_writers_promote_false_without_losing_rewards(engine, monkeypatch, activity):
    attempt = await _seed(engine)
    sid = await _old_quiz(engine, attempt)
    _freeze(monkeypatch, quiz_complete, NOW)
    await _complete(engine, attempt, sid)
    if activity == "lesson":
        _freeze(monkeypatch, lesson_study_activity, NOW)
        await _record(engine, attempt)
    elif activity in {"kana-answer", "kana-progress"}:
        from app.services import kana_quiz_answer

        _freeze(monkeypatch, kana_quiz_answer, NOW)
        body = await _new_kana(engine, attempt)
        if activity == "kana-answer":
            await _kana_answer(engine, attempt, body)
        else:
            monkeypatch.setattr(kana_progress, "get_today_kst", lambda: NOW.date())
            async with async_sessionmaker(engine)() as db:
                await kana_progress.record_kana_learning_progress(
                    db, await db.get(User, attempt.user_id), KanaProgressRecord(kana_id=body.question_id)
                )
    else:
        from app.services import kana_quiz_complete, kana_stage_complete

        _freeze(monkeypatch, kana_quiz_complete, NOW)
        _freeze(monkeypatch, kana_stage_complete, NOW)
        # Existing conversation helper's explicit timestamp is Nov 2; align the
        # helper only, without modifying the real conversation policy.
        import tests.test_lesson_study_day_postgres as helpers

        monkeypatch.setattr(helpers, "NOW", NOW)
        domain_id = await _seed_activity(engine, attempt, activity)
        await _complete_activity(engine, attempt, activity, domain_id)
    state = await _state(engine, attempt.user_id)
    assert len(state["daily"]) == 1
    assert state["daily"][0]["study_day_credited"] is True and state["daily"][0]["xp_earned"] >= 10


async def test_recorded_credit_decisions_block_destructive_migration_rollback(engine, study_day_database, monkeypatch):
    attempt = await _seed(engine)
    sid = await _old_quiz(engine, attempt)
    _freeze(monkeypatch, quiz_complete, NOW)
    await _complete(engine, attempt, sid)
    before = await _state(engine, attempt.user_id)
    result = _alembic(study_day_database[0], "downgrade", "-1")
    assert result.returncode != 0 and "Study-day decisions exist" in result.stderr
    assert await _scalar(engine, "SELECT version_num FROM alembic_version") == RUNTIME_REVISION
    assert await _state(engine, attempt.user_id) == before


async def test_newer_duplicate_answer_does_not_create_completion_day_or_inflate_time(engine, monkeypatch):
    attempt = await _seed(engine)
    sid = await _old_quiz(engine, attempt)
    async with async_sessionmaker(engine)() as db:
        first = await db.scalar(select(QuizAnswer).where(QuizAnswer.session_id == sid))
        db.add(
            QuizAnswer(
                session_id=sid,
                question_id=first.question_id,
                question_type=first.question_type,
                selected_option_id="legacy-duplicate",
                is_correct=False,
                answered_at=NOW,
                time_spent_seconds=50000,
            )
        )
        await db.commit()
    _freeze(monkeypatch, quiz_complete, NOW)
    result = await _complete(engine, attempt, sid)
    assert result.correct_count == 1 and result.xp_earned == 10
    state = await _state(engine, attempt.user_id)
    assert state["daily"][0]["study_day_credited"] is False and state["daily"][0]["study_minutes"] == 1
    assert state["user"]["streak_count"] == 0 and len(state["quizAnswers"]) == 2


async def test_separate_goal_counts_and_one_persistent_trophy_per_kst_day(engine, monkeypatch):
    attempt = await _seed(engine)
    midnight = datetime(2026, 11, 3, 15, tzinfo=UTC)
    before_midnight = midnight - timedelta(milliseconds=1)
    previous_day, day = study_date_kst(before_midnight), study_date_kst(midnight)
    sessions = async_sessionmaker(engine, expire_on_commit=False)

    async def set_sentence_target(target, today=day):
        monkeypatch.setattr(study_daily_goal, "get_today_kst", lambda: today)
        async with sessions() as db:
            user = await db.get(User, attempt.user_id)
            await study_daily_goal.update_daily_goal_data(db, user, daily_goal=target, quiz_type=QuizType.SENTENCE_ARRANGE)

    async def sentence(question_id=None, mode="arrange"):
        question_id = question_id or uuid4()
        session_id = uuid4()
        async with sessions() as db:
            db.add(
                QuizSession(
                    id=session_id,
                    user_id=attempt.user_id,
                    quiz_type=QuizType.SENTENCE_ARRANGE,
                    jlpt_level=JlptLevel.N5,
                    total_questions=1,
                    questions_data={
                        "mode": mode,
                        "questions": [{"id": str(question_id), "type": "SENTENCE_ARRANGE", "correctOptionId": ""}],
                    },
                    started_at=before_midnight,
                )
            )
            await db.commit()
        body = QuizAnswerRequest(
            session_id=session_id, question_id=question_id, question_type=QuizType.SENTENCE_ARRANGE, selected_option_id="wrong"
        )
        await _answer(engine, attempt, body)
        return body

    async def read_history():
        async with sessions() as db:
            user = await db.get(User, attempt.user_id)
            response = await get_history(user, db, year=day.year, month=day.month)
            return {record.date: (record.has_studied, record.goal_achieved) for record in response.records}

    await set_sentence_target(5)
    _freeze(monkeypatch, quiz_answer, before_midnight)
    _, word = await _new_quiz(engine, attempt, wrong=True)
    await _answer(engine, attempt, word)

    _freeze(monkeypatch, quiz_answer, midnight)
    matching = await sentence(mode="matching")
    first = await sentence()
    await _answer(engine, attempt, first)  # Replay must not add a second answer.
    await sentence(first.question_id)  # A second quiz with the same question also counts once.
    assert await read_history() == {str(previous_day): (True, False), str(day): (True, False)}

    async with sessions() as db:
        grammar = QuizSession(user_id=attempt.user_id, quiz_type=QuizType.GRAMMAR, jlpt_level=JlptLevel.N5, total_questions=1)
        db.add(grammar)
        await db.flush()
        db.add_all(
            [
                QuizAnswer(
                    session_id=grammar.id,
                    question_id=uuid4(),
                    question_type=QuizType.GRAMMAR,
                    selected_option_id="wrong",
                    is_correct=False,
                    answered_at=midnight,
                ),
                QuizAnswer(
                    session_id=matching.session_id,
                    question_id=uuid4(),
                    question_type=QuizType.GRAMMAR,
                    selected_option_id="wrong",
                    is_correct=False,
                    answered_at=midnight,
                ),
            ]
        )
        await db.commit()

    for _ in range(4):
        await sentence()
    assert await read_history() == {str(previous_day): (True, False), str(day): (True, True)}

    await set_sentence_target(8)
    monkeypatch.setattr(stats_dashboard, "get_today_kst", lambda: day)
    async with sessions() as db:
        user = await db.get(User, attempt.user_id)
        goals = (await get_dashboard_data(db, user)).today.category_goals
        assert goals.vocabulary.target == user.daily_goal and goals.vocabulary.answered_count == 0
        assert goals.grammar.target == 10 and goals.grammar.answered_count == 1
        assert goals.sentence.target == 8 and goals.sentence.answered_count == 5
    assert await read_history() == {str(previous_day): (True, False), str(day): (True, True)}

    next_day = day + timedelta(days=1)
    _freeze(monkeypatch, quiz_answer, midnight + timedelta(days=1))
    for _ in range(5):
        await sentence()
    assert (await read_history())[str(next_day)] == (True, False)
    await set_sentence_target(5, next_day)
    assert (await read_history())[str(next_day)] == (True, True)


@pytest.mark.parametrize("category", [QuizType.VOCABULARY, QuizType.GRAMMAR])
async def test_categorized_cloze_answers_count_toward_their_own_goal(engine, monkeypatch, category):
    attempt = await _seed(engine)
    day = study_date_kst(NOW)
    _freeze(monkeypatch, quiz_answer, NOW)
    monkeypatch.setattr(stats_dashboard, "get_today_kst", lambda: day)
    monkeypatch.setattr(study_daily_goal, "get_today_kst", lambda: day)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    async with sessions() as db:
        user = await db.get(User, attempt.user_id)
        await study_daily_goal.update_daily_goal_data(db, user, daily_goal=5, quiz_type=category)

    async def submit_cloze(*, session_type=category, snapshot_type=QuizType.CLOZE, question_id=None, stage=False):
        question_id = question_id or uuid4()
        questions = [{"id": str(question_id), "type": snapshot_type.value, "correctOptionId": "right"}]
        async with sessions() as db:
            session = QuizSession(
                user_id=attempt.user_id,
                quiz_type=session_type,
                jlpt_level=JlptLevel.N5,
                total_questions=1,
                questions_data={"stage_id": str(uuid4()), "questions": questions} if stage else questions,
                started_at=NOW,
            )
            db.add(session)
            await db.commit()
        body = QuizAnswerRequest(session_id=session.id, question_id=question_id, question_type=QuizType.CLOZE, selected_option_id="wrong")
        await _answer(engine, attempt, body)
        return body

    async def read_progress(*, expected_count, expected_trophy):
        async with sessions() as db:
            user = await db.get(User, attempt.user_id)
            history = await get_history(user, db, year=day.year, month=day.month)
            [record] = history.records
            assert record.date == str(day) and record.has_studied
            assert record.goal_achieved is expected_trophy
            dashboard = await get_dashboard_data(db, user)
            goals = dashboard.today.category_goals
            counts = [goals.vocabulary.answered_count, goals.grammar.answered_count, goals.sentence.answered_count]
            assert counts == ([expected_count, 0, 0] if category == QuizType.VOCABULARY else [0, expected_count, 0])
            assert dashboard.today.vocabulary_goal.answered_count == 0
            assert dashboard.weekly_stats[-1].vocabulary_answered_count == 0

    first = await submit_cloze()
    await read_progress(expected_count=1, expected_trophy=False)
    await _answer(engine, attempt, first)
    await submit_cloze(question_id=first.question_id, stage=True)
    await submit_cloze(session_type=QuizType.CLOZE)
    await submit_cloze(snapshot_type=category)
    await read_progress(expected_count=1, expected_trophy=False)
    for _ in range(4):
        await submit_cloze(stage=True)
    await read_progress(expected_count=5, expected_trophy=True)
