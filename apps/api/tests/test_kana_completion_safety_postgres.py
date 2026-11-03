"""Completion replays/failures on a disposable, migrated PostgreSQL database."""

import asyncio
from datetime import timedelta
from uuid import uuid4

import pytest
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.models import KanaCharacter, KanaLearningStage, QuizSession, StudyActivityReceipt
from app.models.enums import JlptLevel, KanaType, QuizType
from app.models.user import User
from app.schemas.kana import KanaQuizAnswerRequest, KanaQuizCompleteRequest, KanaStageCompleteRequest
from app.services import kana_quiz_answer, kana_quiz_complete, kana_stage_complete, study_day_recording
from app.services.vocabulary_goal import get_vocabulary_goal
from tests.test_lesson_study_day_postgres import NOW, _freeze, _metadata, _seed
from tests.test_lesson_study_day_postgres import engine as engine
from tests.test_lesson_study_day_postgres import study_day_database as study_day_database
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url


@pytest.fixture(autouse=True)
def freeze_processing_time(monkeypatch):
    for module in [kana_quiz_answer, kana_quiz_complete, kana_stage_complete]:
        _freeze(monkeypatch, module, NOW)


async def _new_quiz(engine, *, tagged=True, answered=2):
    attempt = await _seed(engine)
    session_id = uuid4()
    ids = [uuid4(), uuid4()]
    questions = [
        {
            "id": str(item_id),
            "question": "あ",
            "options": [{"id": "a", "text": "아"}, {"id": "b", "text": "이"}],
            "correctOptionId": "a",
            **({"_answerActivityVersion": 1} if tagged else {}),
        }
        for item_id in ids
    ]
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        db.add_all(
            [
                KanaCharacter(
                    id=item_id,
                    kana_type=KanaType.HIRAGANA,
                    character=str(item_id),
                    romaji="a",
                    pronunciation="a",
                    row="a",
                    column="a",
                    stroke_count=1,
                )
                for item_id in ids
            ]
        )
        db.add(
            QuizSession(
                id=session_id,
                user_id=attempt.user_id,
                quiz_type=QuizType.KANA,
                jlpt_level=JlptLevel.N5,
                total_questions=2,
                questions_data=questions,
            )
        )
        await db.commit()
    for item_id in ids[:answered]:
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            user = await db.get(User, attempt.user_id)
            await kana_quiz_answer.submit_kana_quiz_answer(
                db, user, KanaQuizAnswerRequest(session_id=session_id, question_id=item_id, selected_option_id="a")
            )
    return attempt, session_id


async def _new_stage(engine):
    attempt = await _seed(engine)
    stage_id = uuid4()
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        largest = await db.scalar(select(KanaLearningStage.stage_number).order_by(KanaLearningStage.stage_number.desc()).limit(1))
        db.add(
            KanaLearningStage(
                id=stage_id,
                kana_type=KanaType.HIRAGANA,
                stage_number=(largest or 0) + 1,
                title="완료 재시도",
                description="격리 검사",
                characters=[],
            )
        )
        await db.commit()
    return attempt, stage_id


async def _call(db, user_id, domain_id, kind):
    user = await db.get(User, user_id)
    if kind == "quiz":
        return await kana_quiz_complete.complete_kana_quiz_session(db, user, KanaQuizCompleteRequest(session_id=domain_id))
    return await kana_stage_complete.complete_kana_stage(db, user, KanaStageCompleteRequest(stage_id=domain_id, quiz_score=85))


async def _complete(engine, user_id, domain_id, kind="quiz"):
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        return await _call(db, user_id, domain_id, kind)


async def _snapshot(engine, user_id):
    async with engine.connect() as connection:
        return await connection.scalar(
            text("""SELECT jsonb_build_object(
              'user',(SELECT to_jsonb(u) FROM users u WHERE id=:uid),
              'daily',(SELECT jsonb_agg(to_jsonb(d) ORDER BY date) FROM daily_progress d WHERE user_id=:uid),
              'sessions',(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM quiz_sessions s WHERE user_id=:uid),
              'stages',(SELECT jsonb_agg(to_jsonb(s) ORDER BY id) FROM user_kana_stages s WHERE user_id=:uid),
              'kana',(SELECT jsonb_agg(to_jsonb(k) ORDER BY id) FROM user_kana_progress k WHERE user_id=:uid),
              'receipts',(SELECT jsonb_agg(to_jsonb(r) ORDER BY activity_id) FROM study_activity_receipts r WHERE user_id=:uid),
              'words',(SELECT jsonb_agg(to_jsonb(w) ORDER BY id) FROM user_vocab_progress w WHERE user_id=:uid),
              'grammar',(SELECT jsonb_agg(to_jsonb(g) ORDER BY id) FROM user_grammar_progress g WHERE user_id=:uid),
              'achievements',(SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM user_achievements a WHERE user_id=:uid))"""),
            {"uid": user_id},
        )


@pytest.mark.parametrize("recognition", [False, True], ids=["recognition-off", "recognition-on"])
@pytest.mark.parametrize("answered", [0, 1], ids=["no-answers", "partial-answers"])
async def test_tagged_kana_completion_requires_all_durable_answers(engine, monkeypatch, recognition, answered):
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", recognition)
    attempt, session_id = await _new_quiz(engine, answered=answered)
    before = await _snapshot(engine, attempt.user_id)
    with pytest.raises(kana_quiz_complete.KanaQuizCompleteServiceError) as error:
        await _complete(engine, attempt.user_id, session_id)
    assert error.value.status_code == 409
    assert await _snapshot(engine, attempt.user_id) == before


@pytest.mark.parametrize("tagged", [False, True], ids=["legacy-untagged", "receipt-tagged"])
async def test_quiz_replay_next_day_preserves_original_completion_and_rewards(engine, monkeypatch, tagged):
    monkeypatch.setattr(study_day_recording, "ANSWERED_STUDY_DAY_RECOGNITION_ENABLED", True)
    attempt, session_id = await _new_quiz(engine, tagged=tagged)
    first = await _complete(engine, attempt.user_id, session_id)
    assert first.xp_earned == 20
    committed = await _snapshot(engine, attempt.user_id)
    _freeze(monkeypatch, kana_quiz_complete, NOW + timedelta(days=1))
    replay = await _complete(engine, attempt.user_id, session_id)
    assert replay.accuracy == first.accuracy and replay.xp_earned == 0 and replay.events == []
    assert await _snapshot(engine, attempt.user_id) == committed


@pytest.mark.parametrize("kind", ["quiz", "stage"])
async def test_concurrent_kana_completion_applies_rewards_once(engine, kind):
    attempt, domain_id = await (_new_quiz(engine) if kind == "quiz" else _new_stage(engine))
    before = await _snapshot(engine, attempt.user_id)
    results = await asyncio.gather(*[_complete(engine, attempt.user_id, domain_id, kind) for _ in range(8)])
    expected = 20 if kind == "quiz" else 30
    assert sum(result.xp_earned for result in results) == expected
    after = await _snapshot(engine, attempt.user_id)
    assert after["user"]["experience_points"] == before["user"]["experience_points"] + expected
    assert len(after["daily"]) == 1 and after["daily"][0]["xp_earned"] == expected


@pytest.mark.parametrize("kind", ["quiz", "stage"])
@pytest.mark.parametrize("failure", ["daily-before", "daily-after", "commit-before"])
async def test_completion_failure_rolls_back_state_and_retry_is_safe(engine, monkeypatch, kind, failure):
    attempt, domain_id = await (_new_quiz(engine) if kind == "quiz" else _new_stage(engine))
    before = await _snapshot(engine, attempt.user_id)
    module = kana_quiz_complete if kind == "quiz" else kana_stage_complete
    original = module.apply_daily_progress_increment

    async def failed_daily(*args, **kwargs):
        if failure == "daily-after":
            await original(*args, **kwargs)
        raise RuntimeError("synthetic daily write failure")

    with monkeypatch.context() as patch:
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            if failure == "commit-before":

                async def failed_commit():
                    # Flush pending session/user mutations first; rollback must
                    # also undo SQL already sent, not only unflushed objects.
                    await db.flush()
                    raise RuntimeError("synthetic pre-commit failure")

                patch.setattr(db, "commit", failed_commit)
            else:
                patch.setattr(module, "apply_daily_progress_increment", failed_daily)
            with pytest.raises(RuntimeError, match="synthetic"):
                await _call(db, attempt.user_id, domain_id, kind)
            assert db.in_transaction() is False
    assert await _snapshot(engine, attempt.user_id) == before
    retried = await _complete(engine, attempt.user_id, domain_id, kind)
    assert retried.xp_earned == (20 if kind == "quiz" else 30)
    committed = await _snapshot(engine, attempt.user_id)
    await _complete(engine, attempt.user_id, domain_id, kind)
    assert await _snapshot(engine, attempt.user_id) == committed


@pytest.mark.parametrize("kind", ["quiz", "stage"])
async def test_completion_response_loss_replays_without_new_day_or_reward(engine, monkeypatch, kind):
    attempt, domain_id = await (_new_quiz(engine) if kind == "quiz" else _new_stage(engine))
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        original = db.commit

        async def lost_response():
            await original()
            raise RuntimeError("synthetic committed response loss")

        with monkeypatch.context() as patch:
            patch.setattr(db, "commit", lost_response)
            with pytest.raises(RuntimeError, match="response loss"):
                await _call(db, attempt.user_id, domain_id, kind)
    committed = await _snapshot(engine, attempt.user_id)
    _freeze(monkeypatch, kana_quiz_complete if kind == "quiz" else kana_stage_complete, NOW + timedelta(days=1))
    recovered = await _complete(engine, attempt.user_id, domain_id, kind)
    assert recovered.xp_earned == 0 and recovered.events == []
    assert await _snapshot(engine, attempt.user_id) == committed


async def test_stage_replay_keeps_score_timestamp_and_existing_unlock(engine, monkeypatch):
    attempt, stage_id = await _new_stage(engine)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        stage = await db.get(KanaLearningStage, stage_id)
        next_stage = KanaLearningStage(
            id=uuid4(),
            kana_type=stage.kana_type,
            stage_number=stage.stage_number + 1,
            title="다음",
            description="다음",
            characters=[],
        )
        db.add(next_stage)
        await db.commit()
    first = await _complete(engine, attempt.user_id, stage_id, "stage")
    assert first.next_stage_unlocked is True
    before = await _snapshot(engine, attempt.user_id)
    _freeze(monkeypatch, kana_stage_complete, NOW + timedelta(days=1))
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        user = await db.get(User, attempt.user_id)
        replay = await kana_stage_complete.complete_kana_stage(db, user, KanaStageCompleteRequest(stage_id=stage_id, quiz_score=100))
    assert replay.xp_earned == 0 and replay.next_stage_unlocked is True
    assert await _snapshot(engine, attempt.user_id) == before


async def test_completed_legacy_quiz_does_not_require_new_receipts_or_repair_history(engine):
    attempt, session_id = await _new_quiz(engine, tagged=False, answered=0)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        session = await db.get(QuizSession, session_id)
        session.questions_data = None
        session.completed_at = NOW - timedelta(days=3)
        await db.commit()
    before = await _snapshot(engine, attempt.user_id)
    result = await _complete(engine, attempt.user_id, session_id)
    assert result.xp_earned == 0
    assert await _snapshot(engine, attempt.user_id) == before


async def test_new_tagged_quiz_grades_receipts_and_preserves_goal_due_and_security(engine):
    attempt, session_id = await _new_quiz(engine)
    before = await _snapshot(engine, attempt.user_id)
    security = await _metadata(engine)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        session = await db.get(QuizSession, session_id)
        session.correct_count = 100  # A stale aggregate must not mint rewards.
        await db.commit()
        goal = await get_vocabulary_goal(db, user_id=attempt.user_id, day=NOW.date())
    completed = await _complete(engine, attempt.user_id, session_id)
    assert completed.accuracy == 100 and completed.xp_earned == 20
    after = await _snapshot(engine, attempt.user_id)
    assert after["sessions"][0]["correct_count"] == 2
    for key in ["words", "grammar", "kana", "receipts"]:
        assert after[key] == before[key]
    assert after["user"]["daily_goal"] == before["user"]["daily_goal"]
    assert after["user"]["email"] == before["user"]["email"]
    async with async_sessionmaker(engine)() as db:
        assert await get_vocabulary_goal(db, user_id=attempt.user_id, day=NOW.date()) == goal
    assert await _metadata(engine) == security


@pytest.mark.parametrize("corruption", ["mixed-version", "duplicate-question", "changed-source", "bad-receipt"])
async def test_tagged_completion_fails_closed_for_inconsistent_evidence(engine, corruption):
    attempt, session_id = await _new_quiz(engine)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        session = await db.get(QuizSession, session_id)
        questions = [dict(question) for question in session.questions_data]
        if corruption == "mixed-version":
            questions[1].pop("_answerActivityVersion")
        elif corruption == "duplicate-question":
            questions[1] = dict(questions[0])
        elif corruption == "changed-source":
            questions[0]["correctOptionId"] = "b"
        else:
            receipt = await db.scalar(select(StudyActivityReceipt).where(StudyActivityReceipt.source_scope_id == session_id))
            receipt.response_body = {"isCorrect": "yes", "correctOptionId": "a"}
        session.questions_data = questions
        await db.commit()
    before = await _snapshot(engine, attempt.user_id)
    with pytest.raises(kana_quiz_complete.KanaQuizCompleteServiceError) as error:
        await _complete(engine, attempt.user_id, session_id)
    assert error.value.status_code in {409, 503}
    assert await _snapshot(engine, attempt.user_id) == before
