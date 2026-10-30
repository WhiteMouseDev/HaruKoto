"""Special resume keeps original snapshots and first answers in disposable PostgreSQL."""

from __future__ import annotations

import asyncio
import uuid
from copy import deepcopy
from datetime import UTC, datetime, timedelta

import pytest
from fastapi import Depends, FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select, text

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import (
    Grammar,
    QuizAnswer,
    QuizSession,
    SentenceArrangeQuestion,
    StudyStage,
    UserGrammarProgress,
    UserVocabProgress,
    Vocabulary,
)
from app.models.enums import JlptLevel, PartOfSpeech, QuizType
from app.models.user import User
from app.routers.quiz import router
from app.schemas.quiz import QuizAnswerRequest, QuizCompleteRequest, QuizResumeRequest, QuizStartRequest, QuizWrongReviewRequest
from app.services.quiz_answer import QuizAnswerServiceError, submit_quiz_answer
from app.services.quiz_complete import complete_quiz_session
from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_session_query import get_incomplete_quiz_session, resume_quiz_session
from app.services.quiz_start import start_quiz_session
from app.services.quiz_wrong_review import start_wrong_answer_review
from app.services.study_capabilities import get_study_capabilities_data
from tests.test_quiz_wrong_review_postgres import wrong_review_postgres_url as wrong_review_postgres_url
from tests.test_quiz_wrong_review_postgres import wrong_review_sessions as wrong_review_sessions


async def seed(sessions, category="VOCABULARY"):
    user_id, stage_id = uuid.uuid4(), uuid.uuid4()
    ids = [uuid.uuid4() for _ in range(3)]
    async with sessions() as db:
        db.add(User(id=user_id, email=f"{user_id}@example.test", nickname="특수 이어하기", experience_points=50))
        for index, question_id in enumerate(ids):
            if category == "VOCABULARY":
                db.add(
                    Vocabulary(
                        id=question_id,
                        jlpt_level=JlptLevel.N5,
                        word=f"単語{question_id}",
                        reading="たんご",
                        meaning_ko=f"뜻{index}",
                        part_of_speech=PartOfSpeech.NOUN,
                    )
                )
            elif category == "GRAMMAR":
                db.add(
                    Grammar(
                        id=question_id, jlpt_level=JlptLevel.N5, pattern=f"文法{question_id}", meaning_ko=f"뜻{index}", explanation="설명"
                    )
                )
            else:
                db.add(
                    SentenceArrangeQuestion(
                        id=question_id,
                        jlpt_level=JlptLevel.N5,
                        korean_sentence=f"저는 학생{index}입니다.",
                        japanese_sentence=f"私は学生{index}です。",
                        tokens=["私", "は", f"学生{index}", "です"],
                        explanation="어순",
                    )
                )
        db.add(
            StudyStage(
                id=stage_id,
                category=category,
                jlpt_level=JlptLevel.N5,
                stage_number=1,
                title="재개 회귀",
                content_ids=[str(i) for i in ids],
            )
        )
        await db.commit()
    return user_id, stage_id


async def snapshot(sessions):
    async with sessions() as db:
        return {
            table: await db.scalar(text(f"SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM {table} t"))
            for table in [
                "users",
                "quiz_sessions",
                "quiz_answers",
                "user_vocab_progress",
                "user_grammar_progress",
                "daily_progress",
                "review_events",
            ]
        }


def api(sessions, user_id):
    app = FastAPI()
    app.include_router(router)

    async def database():
        async with sessions() as db:
            yield db

    async def user(db=Depends(get_db)):
        return await db.get(User, user_id)

    app.dependency_overrides[get_db] = database
    app.dependency_overrides[get_current_user] = user
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://isolated.test")


async def answer(sessions, user_id, session_id, question, *, correct):
    async with sessions() as db:
        user = await db.get(User, user_id)
        session = await db.get(QuizSession, session_id)
        return await submit_quiz_answer(
            db,
            user,
            QuizAnswerRequest(
                session_id=session_id,
                question_id=uuid.UUID(question["id"]),
                selected_option_id=question["correctOptionId"] if correct else "wrong",
                question_type=session.quiz_type,
            ),
        )


async def add_matching_content(sessions, category, level):
    content_id = uuid.uuid4()
    async with sessions() as db:
        if category == "VOCABULARY":
            db.add(
                Vocabulary(
                    id=content_id,
                    jlpt_level=level,
                    word=f"範囲外{content_id}",
                    reading="はんいがい",
                    meaning_ko="범위 확인 단어",
                    part_of_speech=PartOfSpeech.NOUN,
                )
            )
        else:
            db.add(Grammar(id=content_id, jlpt_level=level, pattern=f"範囲外{content_id}", meaning_ko="범위 확인 문법", explanation="설명"))
        await db.commit()
    return content_id


@pytest.mark.asyncio
@pytest.mark.parametrize("category", ["VOCABULARY", "GRAMMAR"])
async def test_free_matching_uses_requested_level_and_cold_resume_keeps_first_answers_and_records(wrong_review_sessions, category):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions, category)
    excluded_id = await add_matching_content(sessions, category, JlptLevel.N4)
    other_id = uuid.uuid4()
    async with sessions() as db:
        stage = await db.get(StudyStage, stage_id)
        expected_ids = set(stage.content_ids)
        db.add(User(id=other_id, email=f"{other_id}@example.test", nickname="다른 사용자"))
        await db.flush()
        progress_model = UserVocabProgress if category == "VOCABULARY" else UserGrammarProgress
        content_key = "vocabulary_id" if category == "VOCABULARY" else "grammar_id"
        db.add(
            progress_model(
                user_id=other_id, next_review_at=datetime.now(UTC) + timedelta(days=7), **{content_key: uuid.UUID(stage.content_ids[0])}
            )
        )
        await db.commit()
        original_stages = await db.scalar(text("SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM study_stages t"))
    async with api(sessions, user_id) as client:
        started = await client.post("/api/v1/quiz/start", json={"quizType": category, "jlptLevel": "N5", "count": 3, "mode": "matching"})
        assert started.status_code == 200
        start = started.json()
        session_id = uuid.UUID(start["sessionId"])
        assert start["mode"] == "matching" and start["totalQuestions"] == 3
        assert {q["questionId"] for q in start["questions"]} == expected_ids
        assert str(excluded_id) not in {q["questionId"] for q in start["questions"]}
        async with sessions() as db:
            stored = await db.get(QuizSession, session_id)
            raw = deepcopy(stored.questions_data)
            assert raw["mode"] == "matching" and "stage_id" not in raw
            assert raw["matchingPairs"] == start["matchingPairs"]
            assert len({p["id"] for p in raw["matchingPairs"]}) == 3
            assert await db.scalar(text("SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM study_stages t")) == original_stages
        questions = raw["questions"]
        await answer(sessions, user_id, session_id, questions[2], correct=False)
        await answer(sessions, user_id, session_id, questions[0], correct=True)
        baseline = await snapshot(sessions)
        banner = (await client.get("/api/v1/quiz/incomplete")).json()["session"]
        assert (banner["mode"], banner["resumeStatus"], banner["answeredCount"], banner["correctCount"]) == ("matching", "available", 2, 1)
        resumed = await client.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})
        assert resumed.status_code == 200
        assert resumed.json()["questions"] == start["questions"]
        assert resumed.json()["matchingPairs"] == start["matchingPairs"]
        assert resumed.json()["answeredQuestionIds"] == [questions[0]["id"], questions[2]["id"]]
    async with api(sessions, other_id) as foreign:
        denied = await foreign.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})
        assert denied.status_code == 404
    async with sessions() as db:
        user = await db.get(User, user_id)
        cold = await resume_quiz_session(db, user, QuizResumeRequest(session_id=session_id))
        assert cold.mode == "matching" and cold.correct_count == 1
        assert [q.question_id for q in cold.questions if q.question_id not in cold.answered_question_ids] == [questions[1]["id"]]
        assert [p.model_dump() for p in cold.matching_pairs] == raw["matchingPairs"]
    assert await snapshot(sessions) == baseline  # Includes both users' SRS dates and original answers.


@pytest.mark.asyncio
@pytest.mark.parametrize("category", ["VOCABULARY", "GRAMMAR"])
async def test_stage_matching_keeps_content_id_scope_when_level_pool_has_other_items(wrong_review_sessions, category):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions, category)
    await add_matching_content(sessions, category, JlptLevel.N5)
    await add_matching_content(sessions, category, JlptLevel.N4)
    async with sessions() as db:
        stage = await db.get(StudyStage, stage_id)
        expected_ids = set(stage.content_ids)
    async with api(sessions, user_id) as client:
        response = await client.post(
            "/api/v1/quiz/start", json={"quizType": category, "jlptLevel": "N5", "count": 10, "mode": "matching", "stageId": str(stage_id)}
        )
        assert response.status_code == 200
        assert {q["questionId"] for q in response.json()["questions"]} == expected_ids


@pytest.mark.asyncio
@pytest.mark.parametrize("quiz_type", ["KANJI", "LISTENING", "SENTENCE_ARRANGE", "CLOZE"])
async def test_unsupported_free_matching_rolls_back_pending_completion_and_xp(wrong_review_sessions, quiz_type):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions)
    async with sessions() as db:
        user = await db.get(User, user_id)
        started = await start_quiz_session(
            db, user, QuizStartRequest(quiz_type=QuizType.VOCABULARY, jlpt_level=JlptLevel.N5, mode="matching", stage_id=stage_id, count=3)
        )
        session_id, questions = started.session.id, deepcopy(started.questions)
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    before = await snapshot(sessions)
    async with api(sessions, user_id) as client:
        response = await client.post("/api/v1/quiz/start", json={"quizType": quiz_type, "jlptLevel": "N5", "count": 3, "mode": "matching"})
        assert response.status_code == 400 and "단어와 문법" in response.json()["detail"]
    assert await snapshot(sessions) == before


@pytest.mark.asyncio
@pytest.mark.parametrize("category", ["VOCABULARY", "GRAMMAR"])
async def test_conflicting_stage_matching_category_rolls_back_pending_completion_and_xp(wrong_review_sessions, category):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions, category)
    async with sessions() as db:
        user = await db.get(User, user_id)
        started = await start_quiz_session(
            db, user, QuizStartRequest(quiz_type=QuizType(category), jlpt_level=JlptLevel.N5, mode="matching", stage_id=stage_id, count=3)
        )
        session_id, questions = started.session.id, deepcopy(started.questions)
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    before = await snapshot(sessions)
    opposite = "GRAMMAR" if category == "VOCABULARY" else "VOCABULARY"
    async with api(sessions, user_id) as client:
        response = await client.post(
            "/api/v1/quiz/start", json={"quizType": opposite, "jlptLevel": "N5", "count": 3, "mode": "matching", "stageId": str(stage_id)}
        )
        assert response.status_code == 400
    assert await snapshot(sessions) == before


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "category,mode", [("VOCABULARY", "matching"), ("GRAMMAR", "matching"), ("SENTENCE", "matching"), ("SENTENCE", "arrange")]
)
async def test_special_start_partial_resume_keeps_snapshot_saved_right_and_wrong_and_completes_once(wrong_review_sessions, category, mode):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions, category)
    quiz_type = "SENTENCE_ARRANGE" if category == "SENTENCE" else category
    async with api(sessions, user_id) as client:
        started = await client.post(
            "/api/v1/quiz/start", json={"quizType": quiz_type, "jlptLevel": "N5", "count": 3, "mode": mode, "stageId": str(stage_id)}
        )
        assert started.status_code == 200
        start = started.json()
        session_id = uuid.UUID(start["sessionId"])
        assert start["mode"] == mode
        async with sessions() as db:
            session = await db.get(QuizSession, session_id)
            raw = deepcopy(session.questions_data)
        questions = raw["questions"]
        assert raw["mode"] == mode and raw["stage_id"] == str(stage_id)
        assert [q["questionId"] for q in start["questions"]] == [q["id"] for q in questions]
        if mode == "matching":
            assert start["matchingPairs"] == raw["matchingPairs"]
        # Matching answers need not follow list order; a saved wrong answer is
        # still answered and may never be re-graded by resume.
        await answer(sessions, user_id, session_id, questions[2], correct=False)
        await answer(sessions, user_id, session_id, questions[0], correct=True)
        baseline = await snapshot(sessions)
        incomplete = await client.get("/api/v1/quiz/incomplete")
        banner = incomplete.json()["session"]
        assert (banner["mode"], banner["resumeStatus"], banner["answeredCount"]) == (mode, "available", 2)
        resumed = await client.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})
        assert resumed.status_code == 200
        data = resumed.json()
        assert data["mode"] == mode and data["totalQuestions"] == 3 and data["correctCount"] == 1
        assert data["questions"] == start["questions"]
        assert data["matchingPairs"] == start["matchingPairs"]
        assert data["answeredQuestionIds"] == [questions[0]["id"], questions[2]["id"]]
        assert await snapshot(sessions) == baseline
    # A fresh DB session/process restores the remaining single pair/question.
    async with sessions() as db:
        user = await db.get(User, user_id)
        restored = await resume_quiz_session(db, user, QuizResumeRequest(session_id=session_id))
        remaining = [q for q in restored.questions if q.question_id not in restored.answered_question_ids]
        assert len(remaining) == 1 and remaining[0].question_id == questions[1]["id"]
    await answer(sessions, user_id, session_id, questions[1], correct=True)
    async with sessions() as db:
        user = await db.get(User, user_id)
        restored = await resume_quiz_session(db, user, QuizResumeRequest(session_id=session_id))
        assert len(restored.answered_question_ids) == 3
        completed = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=session_id))
        retried = await complete_quiz_session(db, user, QuizCompleteRequest(session_id=session_id))
        assert (completed.correct_count, completed.total_questions, completed.xp_earned, retried.xp_earned) == (2, 3, 20, 0)
        assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == session_id)) == 3


@pytest.mark.asyncio
@pytest.mark.parametrize("category,mode", [("VOCABULARY", "matching"), ("GRAMMAR", "matching"), ("SENTENCE", "arrange")])
@pytest.mark.parametrize("envelope", [False, True], ids=["array", "stage-envelope"])
async def test_legacy_special_snapshots_resume_without_backfill_or_review_date_changes(wrong_review_sessions, category, mode, envelope):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions, category)
    quiz_type = QuizType.SENTENCE_ARRANGE if category == "SENTENCE" else QuizType(category)
    async with sessions() as db:
        user = await db.get(User, user_id)
        started = await start_quiz_session(
            db, user, QuizStartRequest(quiz_type=quiz_type, jlpt_level=JlptLevel.N5, mode=mode, stage_id=stage_id, count=3)
        )
        session_id, questions = started.session.id, deepcopy(started.questions)
        started.session.questions_data = {"stage_id": str(stage_id), "questions": questions} if envelope else questions
        await db.commit()
    await answer(sessions, user_id, session_id, questions[1], correct=False)
    baseline = await snapshot(sessions)
    for _ in range(2):
        async with sessions() as db:
            user = await db.get(User, user_id)
            data = await resume_quiz_session(db, user, QuizResumeRequest(session_id=session_id))
            assert data.mode == mode and data.answered_question_ids == [questions[1]["id"]]
            assert [q.question_id for q in data.questions] == [q["id"] for q in questions]
    assert await snapshot(sessions) == baseline


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "mutation",
    ["missing-japanese", "missing-side", "mixed-mode", "duplicate-id", "unknown-mode", "foreign-answer", "wrong-grade", "foreign-pair"],
)
async def test_unavailable_special_session_returns_409_without_mutating_learning_or_backfilling(wrong_review_sessions, mutation):
    sessions = wrong_review_sessions
    category = "SENTENCE" if mutation == "missing-japanese" else "VOCABULARY"
    user_id, stage_id = await seed(sessions, category)
    quiz_type = QuizType.SENTENCE_ARRANGE if category == "SENTENCE" else QuizType.VOCABULARY
    async with sessions() as db:
        user = await db.get(User, user_id)
        started = await start_quiz_session(
            db, user, QuizStartRequest(quiz_type=quiz_type, jlpt_level=JlptLevel.N5, mode="matching", stage_id=stage_id, count=3)
        )
        session_id, questions = started.session.id, deepcopy(started.questions)
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    async with sessions() as db:
        session = await db.get(QuizSession, session_id)
        raw = deepcopy(session.questions_data)
        if mutation == "missing-japanese":
            raw = [
                {
                    "id": q["id"],
                    "type": "SENTENCE_ARRANGE",
                    "question": "과거 한국어 문장",
                    "options": [],
                    "correctOptionId": q["correctOptionId"],
                }
                for q in questions
            ]
        elif mutation == "missing-side":
            del raw["questions"][0]["meaningKo"]
        elif mutation == "mixed-mode":
            raw["mode"] = "arrange"
        elif mutation == "duplicate-id":
            raw["questions"][1]["id"] = raw["questions"][0]["id"]
        elif mutation == "unknown-mode":
            raw["mode"] = "typing"
        elif mutation == "foreign-answer":
            db.add(
                QuizAnswer(
                    session_id=session_id,
                    question_id=uuid.uuid4(),
                    question_type=QuizType.VOCABULARY,
                    selected_option_id="wrong",
                    is_correct=False,
                )
            )
        elif mutation == "wrong-grade":
            saved = await db.scalar(select(QuizAnswer).where(QuizAnswer.session_id == session_id))
            saved.is_correct = False
        elif mutation == "foreign-pair":
            raw["matchingPairs"][0]["id"] = str(uuid.uuid4())
        session.questions_data = raw
        await db.commit()
    baseline = await snapshot(sessions)
    async with api(sessions, user_id) as client:
        banner = (await client.get("/api/v1/quiz/incomplete")).json()["session"]
        assert banner["resumeStatus"] == ("legacy_unavailable" if mutation == "missing-japanese" else "invalid_snapshot")
        response = await client.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})
        assert response.status_code == 409 and isinstance(response.json()["detail"], str)
        assert "학습 기록은 유지" in response.json()["detail"]
    assert await snapshot(sessions) == baseline


@pytest.mark.asyncio
@pytest.mark.parametrize("storage", ["text", "enum"])
async def test_study_capabilities_reads_text_and_enum_chapter_levels_without_rewriting_records(wrong_review_sessions, storage):
    sessions = wrong_review_sessions
    user_id, _ = await seed(sessions)
    async with sessions() as db:
        if storage == "text":
            await db.execute(text("ALTER TABLE chapters ALTER COLUMN jlpt_level TYPE TEXT USING jlpt_level::text"))
        column_type = await db.scalar(
            text("SELECT format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='chapters'::regclass AND attname='jlpt_level'")
        )
        assert column_type == "text" if storage == "text" else "JlptLevel" in column_type
        for index, level in enumerate(["N5", "N4"]):
            await db.execute(
                text(
                    "INSERT INTO chapters(id,jlpt_level,part_no,chapter_no,title,order_no,is_published) "
                    "VALUES (:id,:level,1,:number,:title,1,:published)"
                ),
                {"id": uuid.uuid4(), "level": level, "number": index + 1, "title": f"{level} 단원", "published": level == "N5"},
            )
        await db.commit()
    before = await snapshot(sessions)
    async with sessions() as db:
        chapters = await db.scalar(text("SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM chapters t"))
        user = await db.get(User, user_id)
        n5 = await get_study_capabilities_data(db, user, jlpt_level="N5")
        n4 = await get_study_capabilities_data(db, user, jlpt_level="N4")
        assert n5.lesson is True and n5.quiz.vocabulary is True and n5.stage.vocabulary is True
        assert n4.lesson is False
        assert await db.scalar(text("SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM chapters t")) == chapters
    assert await snapshot(sessions) == before


@pytest.mark.asyncio
@pytest.mark.parametrize("category", ["VOCABULARY", "GRAMMAR"])
async def test_legacy_arrange_category_conflict_is_unavailable_without_regrading_or_srs_rewrite(wrong_review_sessions, category):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions, "SENTENCE")
    async with sessions() as db:
        user = await db.get(User, user_id)
        started = await start_quiz_session(
            db,
            user,
            QuizStartRequest(quiz_type=QuizType.SENTENCE_ARRANGE, jlpt_level=JlptLevel.N5, mode="arrange", stage_id=stage_id, count=3),
        )
        session_id, questions = started.session.id, deepcopy(started.questions)
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    async with sessions() as db:
        session = await db.get(QuizSession, session_id)
        session.quiz_type = QuizType(category)
        session.questions_data = questions  # Historical missing mode plus conflicting category.
        await db.commit()
    before = await snapshot(sessions)
    async with api(sessions, user_id) as client:
        banner = (await client.get("/api/v1/quiz/incomplete")).json()["session"]
        assert banner["resumeStatus"] == "legacy_unavailable" and banner["quizType"] == category
        response = await client.post("/api/v1/quiz/resume", json={"sessionId": str(session_id)})
        assert response.status_code == 409 and "학습 기록은 유지" in response.json()["detail"]
    assert await snapshot(sessions) == before


@pytest.mark.asyncio
@pytest.mark.parametrize("category", ["VOCABULARY", "GRAMMAR"])
async def test_invalid_new_arrange_category_rolls_back_pending_auto_completion_and_xp(wrong_review_sessions, category):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions, "SENTENCE")
    async with sessions() as db:
        user = await db.get(User, user_id)
        started = await start_quiz_session(
            db,
            user,
            QuizStartRequest(quiz_type=QuizType.SENTENCE_ARRANGE, jlpt_level=JlptLevel.N5, mode="arrange", stage_id=stage_id, count=3),
        )
        session_id, questions = started.session.id, deepcopy(started.questions)
    await answer(sessions, user_id, session_id, questions[0], correct=True)
    before = await snapshot(sessions)
    async with api(sessions, user_id) as client:
        response = await client.post("/api/v1/quiz/start", json={"quizType": category, "jlptLevel": "N5", "mode": "arrange", "count": 3})
        assert response.status_code == 400
    # The failed start must not commit the earlier auto-completion flush or XP.
    assert await snapshot(sessions) == before


@pytest.mark.asyncio
async def test_special_retries_concurrent_answers_and_completion_apply_srs_and_xp_once(wrong_review_sessions):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions)
    async with sessions() as db:
        user = await db.get(User, user_id)
        started = await start_quiz_session(
            db, user, QuizStartRequest(quiz_type=QuizType.VOCABULARY, jlpt_level=JlptLevel.N5, mode="matching", stage_id=stage_id, count=3)
        )
        session_id, questions = started.session.id, deepcopy(started.questions)
    await asyncio.gather(*[answer(sessions, user_id, session_id, questions[0], correct=True) for _ in range(2)])
    baseline = await snapshot(sessions)
    with pytest.raises(QuizAnswerServiceError) as error:
        await answer(sessions, user_id, session_id, questions[0], correct=False)
    assert error.value.status_code == 409
    assert await snapshot(sessions) == baseline
    await asyncio.gather(*[answer(sessions, user_id, session_id, question, correct=True) for question in questions[1:]])

    async def complete():
        async with sessions() as db:
            user = await db.get(User, user_id)
            return await complete_quiz_session(db, user, QuizCompleteRequest(session_id=session_id))

    results = await asyncio.gather(complete(), complete())
    assert sorted(r.xp_earned for r in results) == [0, 30]
    async with sessions() as db:
        assert await db.scalar(select(func.count()).select_from(QuizAnswer).where(QuizAnswer.session_id == session_id)) == 3
        assert await db.scalar(select(func.count()).select_from(UserVocabProgress).where(UserVocabProgress.user_id == user_id)) == 3
        assert await db.scalar(text("SELECT count(*) FROM review_events WHERE session_id=:id"), {"id": session_id}) == 3
        user = await db.get(User, user_id)
        assert user.experience_points == 80
        with pytest.raises(QuizQueryServiceError) as error:
            await start_wrong_answer_review(db, user, QuizWrongReviewRequest(source_session_id=session_id))
        assert error.value.status_code == 400  # Special-mode wrong review remains unsupported.


@pytest.mark.asyncio
async def test_legacy_duplicate_special_answers_keep_first_grade_and_no_read_side_effects(wrong_review_sessions):
    sessions = wrong_review_sessions
    user_id, stage_id = await seed(sessions)
    async with sessions() as db:
        user = await db.get(User, user_id)
        started = await start_quiz_session(
            db, user, QuizStartRequest(quiz_type=QuizType.VOCABULARY, jlpt_level=JlptLevel.N5, mode="matching", stage_id=stage_id, count=3)
        )
        session_id, questions = started.session.id, deepcopy(started.questions)
    await answer(sessions, user_id, session_id, questions[0], correct=False)
    async with sessions() as db:
        session = await db.get(QuizSession, session_id)
        session.correct_count = 1  # Old duplicate grading may have inflated this field.
        db.add(
            QuizAnswer(
                session_id=session_id,
                question_id=uuid.UUID(questions[0]["id"]),
                question_type=QuizType.VOCABULARY,
                selected_option_id=questions[0]["correctOptionId"],
                is_correct=True,
                answered_at=datetime.now(UTC) + timedelta(seconds=1),
            )
        )
        await db.commit()
    baseline = await snapshot(sessions)
    async with sessions() as db:
        user = await db.get(User, user_id)
        banner = await get_incomplete_quiz_session(db, user)
        data = await resume_quiz_session(db, user, QuizResumeRequest(session_id=session_id))
        assert banner.answered_count == 1 and banner.correct_count == 0
        assert data.correct_count == 0 and data.answered_question_ids == [questions[0]["id"]]
    assert await snapshot(sessions) == baseline
