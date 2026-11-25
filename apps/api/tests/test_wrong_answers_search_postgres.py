"""Wrong-answer list filters against a disposable PostgreSQL database."""

import uuid
from collections.abc import AsyncIterator

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.base import Base
from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import UserVocabProgress, Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech
from app.models.user import User
from app.routers.study import router
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url


@pytest.mark.asyncio
async def test_wrong_answer_filters_apply_before_pagination_without_changing_global_summary(
    isolated_postgres_url: str,
) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    owner_id, other_owner_id = uuid.uuid4(), uuid.uuid4()
    owner = User(id=owner_id, email=f"{owner_id}@example.test")
    other_owner = User(id=other_owner_id, email=f"{other_owner_id}@example.test")
    path = "/api/v1/study/wrong-answers"

    async def test_db() -> AsyncIterator[AsyncSession]:
        async with sessions() as db:
            yield db

    async def test_user() -> User:
        return owner

    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_db] = test_db
    app.dependency_overrides[get_current_user] = test_user

    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with sessions() as db:
            db.add_all([owner, other_owner])

            def add_word(
                word: str,
                reading: str,
                meaning: str,
                incorrect_count: int,
                *,
                user_id: uuid.UUID = owner_id,
                mastered: bool = False,
                level: JlptLevel = JlptLevel.N5,
            ) -> None:
                vocab_id = uuid.uuid4()
                db.add(
                    Vocabulary(
                        id=vocab_id,
                        word=word,
                        reading=reading,
                        meaning_ko=meaning,
                        jlpt_level=level,
                        part_of_speech=PartOfSpeech.NOUN,
                    )
                )
                db.add(
                    UserVocabProgress(
                        user_id=user_id,
                        vocabulary_id=vocab_id,
                        incorrect_count=incorrect_count,
                        mastered=mastered,
                    )
                )

            add_word("学校", "がっこう", "학교", 7)
            add_word("学生", "がくせい", "학생", 4, level=JlptLevel.N4)
            add_word("学習", "がくしゅう", "학습", 8, mastered=True)
            add_word("割合", "わりあい", "Rate 100%_/", 3, mastered=True)
            add_word("無関係", "むかんけい", "Rate 100AB/", 2, mastered=True)
            add_word("学園", "がくえん", "학원", 99, user_id=other_owner_id)
            add_word("学業", "がくぎょう", "학업", 0)
            await db.commit()

        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            legacy = await client.get(path)
            assert legacy.status_code == 200
            legacy_data = legacy.json()
            summary = {"totalWrong": 5, "mastered": 3, "remaining": 2}
            assert legacy_data["summary"] == summary
            assert legacy_data["total"] == 5
            assert legacy_data["supportsSearchAndStatus"] is True
            assert [row["word"] for row in legacy_data["entries"]] == ["学習", "学校", "学生", "割合", "無関係"]

            for page, word in [(1, "学校"), (2, "学生")]:
                response = await client.get(path, params={"search": "  학  ", "status": "LEARNING", "page": page, "limit": 1})
                assert response.status_code == 200
                data = response.json()
                assert data["summary"] == summary
                assert (data["total"], data["totalPages"], data["page"]) == (2, 2, page)
                assert [row["word"] for row in data["entries"]] == [word]

            for params, expected_words in [
                ({"status": "MASTERED"}, ["学習", "割合", "無関係"]),
                ({"level": "N4"}, ["学生"]),
                ({"search": "学校"}, ["学校"]),
                ({"search": "がくせい"}, ["学生"]),
                ({"search": "rate 100%_/"}, ["割合"]),
                ({"search": f"  {'가' * 100}  "}, []),
                ({"search": "학원"}, []),
            ]:
                response = await client.get(path, params=params)
                assert response.status_code == 200
                data = response.json()
                assert data["summary"] == summary
                assert data["total"] == len(expected_words)
                assert [row["word"] for row in data["entries"]] == expected_words
    finally:
        await engine.dispose()
