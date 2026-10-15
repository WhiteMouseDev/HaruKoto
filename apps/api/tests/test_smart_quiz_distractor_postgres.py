"""Verify quiz pool reuse through the real HTTP route on disposable PostgreSQL."""

from __future__ import annotations

import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import event
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.base import Base
from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import QuizSession, UserVocabProgress, Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech
from app.models.user import User
from app.routers.quiz import router
from app.services.distractor import load_distractor_pool
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url


@pytest.mark.asyncio
@pytest.mark.parametrize("question_count", [2, 10])
async def test_smart_start_reads_distractor_candidates_and_seen_ids_once(isolated_postgres_url: str, question_count: int) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    statements: list[str] = []

    def capture_select(_connection, _cursor, statement, _parameters, _context, _executemany):
        if statement.lstrip().upper().startswith("SELECT"):
            statements.append(statement)

    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with sessions() as db:
            user = User(id=uuid.uuid4(), email=f"{uuid.uuid4()}@example.test", nickname="퀴즈 조회 테스트")
            other_user = User(id=uuid.uuid4(), email=f"{uuid.uuid4()}@example.test", nickname="다른 사용자")
            meaning_prefix = uuid.uuid4().hex
            vocabularies = [
                Vocabulary(
                    id=uuid.uuid4(),
                    jlpt_level=JlptLevel.N5,
                    word=f"単語{uuid.uuid4()}",
                    reading="たんご",
                    meaning_ko=f"의미{meaning_prefix}{index}",
                    meaning_glosses_ko=[f"의미{meaning_prefix}{index}"],
                    part_of_speech=PartOfSpeech.NOUN,
                    category_tag="daily",
                )
                for index in range(16)
            ]
            db.add_all([user, other_user, *vocabularies])
            await db.flush()
            db.add_all(
                [
                    UserVocabProgress(user_id=user.id, vocabulary_id=vocabularies[-1].id, state="LEARNING"),
                    UserVocabProgress(user_id=user.id, vocabulary_id=vocabularies[-2].id, state="UNSEEN"),
                    UserVocabProgress(user_id=other_user.id, vocabulary_id=vocabularies[-3].id, state="REVIEW"),
                ]
            )
            await db.commit()
            pool = await load_distractor_pool(db, item_type="WORD", jlpt_level="N5", user_id=user.id)
            assert pool.seen_ids == frozenset({vocabularies[-1].id})

        app = FastAPI()
        app.include_router(router)

        async def current_user():
            return user

        async def test_db():
            async with sessions() as db:
                yield db

        app.dependency_overrides[get_current_user] = current_user
        app.dependency_overrides[get_db] = test_db
        event.listen(engine.sync_engine, "before_cursor_execute", capture_select)
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/api/v1/quiz/smart-start",
                json={"category": "VOCABULARY", "jlptLevel": "N5", "count": question_count},
            )
        event.remove(engine.sync_engine, "before_cursor_execute", capture_select)
        assert response.status_code == 200, response.text
        payload = response.json()
        assert payload["totalQuestions"] == question_count
        assert len(payload["questions"]) == question_count
        for question in payload["questions"]:
            assert len(question["options"]) == 4
            assert sum(option["id"] == question["correctOptionId"] for option in question["options"]) == 1

        candidate_reads = [
            statement
            for statement in statements
            if statement.startswith("SELECT vocabularies.id,") and "JOIN" not in statement and "LIMIT" not in statement
        ]
        seen_reads = [
            statement
            for statement in statements
            if statement.startswith("SELECT user_vocab_progress.vocabulary_id") and "user_vocab_progress.state !=" in statement
        ]
        assert len(candidate_reads) == 1
        assert len(seen_reads) == 1

        async with sessions() as db:
            session = await db.get(QuizSession, uuid.UUID(payload["sessionId"]))
            assert session is not None
            questions = session.questions_data["questions"]
            assert len(questions) == question_count
            for question in questions:
                options = question["options"]
                assert len(options) == 4
                assert len({option["text"] for option in options}) == 4
                correct = [option for option in options if option["id"] == question["correctOptionId"]]
                assert len(correct) == 1
                assert correct[0]["text"] == question["meaningKo"]
    finally:
        await engine.dispose()
