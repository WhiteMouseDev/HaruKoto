"""Wordbook ranking with the wrong-answer notebook's stored vocabulary counts."""

import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.base import Base
from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import UserVocabProgress, Vocabulary, WordbookEntry
from app.models.enums import JlptLevel, PartOfSpeech, WordbookSource
from app.models.user import User
from app.routers.wordbook import router
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url


@pytest.mark.asyncio
async def test_most_wrong_rank_respects_identity_account_filters_and_pagination(isolated_postgres_url: str) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    owner_id, other_owner_id = uuid.uuid4(), uuid.uuid4()
    owner = User(id=owner_id, email=f"{owner_id}@example.test")
    other_owner = User(id=other_owner_id, email=f"{other_owner_id}@example.test")

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

            def add_entry(
                number: int,
                day: int,
                identity: tuple[str, str, str],
                *,
                source: WordbookSource = WordbookSource.QUIZ,
                user_id: uuid.UUID = owner_id,
            ) -> None:
                word, reading, meaning = identity
                db.add(
                    WordbookEntry(
                        id=uuid.UUID(int=number),
                        user_id=user_id,
                        word=word,
                        reading=reading,
                        meaning_ko=meaning,
                        source=source,
                        created_at=datetime(2026, 11, day, tzinfo=UTC),
                    )
                )

            def add_count(
                identity: tuple[str, str, str],
                count: int,
                *,
                level: JlptLevel = JlptLevel.N5,
                user_id: uuid.UUID = owner_id,
            ) -> None:
                word, reading, meaning = identity
                vocabulary_id = uuid.uuid4()
                db.add(
                    Vocabulary(
                        id=vocabulary_id,
                        word=word,
                        reading=reading,
                        meaning_ko=meaning,
                        jlpt_level=level,
                        part_of_speech=PartOfSpeech.VERB,
                    )
                )
                db.add(UserVocabProgress(user_id=user_id, vocabulary_id=vocabulary_id, incorrect_count=count))

            ranks = [
                (1, 1, ("本を読む", "ほんをよむ", "책을 읽다")),
                (2, 2, ("本を借りる", "ほんをかりる", "책을 빌리다")),
                (3, 2, ("本を買う", "ほんをかう", "책을 사다")),
            ]
            for number, day, identity in ranks:
                add_entry(number, day, identity)
                add_count(identity, 7)

            ambiguous = ("本を閉じる", "ほんをとじる", "책을 덮다")
            add_entry(4, 6, ambiguous)
            add_count(ambiguous, 100)
            add_count(ambiguous, 100, level=JlptLevel.N4)

            add_entry(5, 5, ("本を開く", "ほんをひらく", "책을 펼치다"))
            add_count(("本を開く", "ほんをあく", "책을 펼치다"), 100)
            add_count(("本を開く", "ほんをひらく", "책을 열다"), 100)

            other_progress = ("本を書く", "ほんをかく", "책을 쓰다")
            add_entry(6, 4, other_progress)
            add_count(other_progress, 100, user_id=other_owner_id)
            add_entry(9, 8, other_progress, user_id=other_owner_id)

            manual = ("本を売る", "ほんをうる", "책을 팔다")
            add_entry(7, 3, manual, source=WordbookSource.MANUAL)
            add_count(manual, 20)
            outside_search = ("荷物を預ける", "にもつをあずける", "짐을 맡기다")
            add_entry(8, 3, outside_search)
            add_count(outside_search, 30)
            await db.commit()

        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            for page, expected_ids in [(1, [2, 3]), (2, [1, 4]), (3, [5, 6])]:
                response = await client.get(
                    "/api/v1/wordbook/",
                    params={"sort": "most-wrong", "search": "本", "source": "QUIZ", "page": page, "limit": 2},
                )
                assert response.status_code == 200
                data = response.json()
                assert (data["total"], data["totalPages"], data["page"]) == (6, 3, page)
                assert [entry["id"] for entry in data["entries"]] == [str(uuid.UUID(int=number)) for number in expected_ids]

            response = await client.get("/api/v1/wordbook/", params={"sort": "most-wrong", "limit": 2})
            assert response.status_code == 200
            assert [entry["word"] for entry in response.json()["entries"]] == ["荷物を預ける", "本を売る"]
    finally:
        await engine.dispose()
