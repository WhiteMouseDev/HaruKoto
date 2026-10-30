from __future__ import annotations

from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError

from app.db.session import get_db
from app.dependencies import get_current_user
from app.error_handlers import register_error_handlers
from app.routers.stats import router
from app.schemas.stats import DailyProgressItem

LEGACY_RECORD = {
    "date": "2026-10-03",
    "wordsStudied": 0,
    "quizzesCompleted": 0,
    "correctAnswers": 4,
    "totalAnswers": 5,
    "conversationCount": 0,
    "studyTimeSeconds": 0,
    "xpEarned": 0,
}


@pytest.mark.parametrize("has_studied", [False, True])
def test_history_record_serializes_required_boolean_and_keeps_legacy_fields(has_studied: bool) -> None:
    payload = {**LEGACY_RECORD, "hasStudied": has_studied}

    assert DailyProgressItem.model_validate(payload).model_dump(by_alias=True) == payload


@pytest.mark.parametrize("extra", [{}, {"hasStudied": None}], ids=["missing", "null"])
def test_history_record_requires_nonnull_activity_boolean(extra: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        DailyProgressItem.model_validate({**LEGACY_RECORD, **extra})


@pytest.mark.asyncio
async def test_history_endpoint_adds_activity_boolean_and_preserves_records_and_user_scope(mock_user) -> None:
    app = FastAPI()
    app.include_router(router)
    register_error_handlers(app)
    rows = [
        SimpleNamespace(
            date=date(2026, 10, 3),
            words_studied=0,
            quizzes_completed=0,
            correct_answers=4,
            total_answers=5,
            conversation_count=0,
            study_time_seconds=0,
            xp_earned=0,
            kana_learned=0,
            grammar_studied=None,
            sentences_studied=None,
            study_minutes=None,
        ),
        # Grammar is tracked by the server but is not a legacy history field.
        SimpleNamespace(
            date=date(2026, 10, 4),
            words_studied=0,
            quizzes_completed=0,
            correct_answers=4,
            total_answers=5,
            conversation_count=0,
            study_time_seconds=0,
            xp_earned=0,
            grammar_studied=1,
        ),
    ]
    db = AsyncMock()
    result = MagicMock()
    result.scalars.return_value.all.return_value = rows
    db.execute.return_value = result

    async def override_db():
        yield db

    async def override_user():
        return mock_user

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user] = override_user
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/api/v1/stats/history", params={"year": 2026, "month": 10})

    assert response.status_code == 200
    assert response.json() == {
        "year": 2026,
        "month": 10,
        "records": [
            {**LEGACY_RECORD, "hasStudied": False},
            {**LEGACY_RECORD, "date": "2026-10-04", "hasStudied": True},
        ],
    }
    query = db.execute.await_args.args[0]
    assert query.compile().params == {
        "user_id_1": mock_user.id,
        "date_1": date(2026, 10, 1),
        "date_2": date(2026, 10, 31),
    }
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_history_endpoint_still_requires_auth_before_reading_history() -> None:
    app = FastAPI()
    app.include_router(router)
    register_error_handlers(app)
    db = AsyncMock()

    async def override_db():
        yield db

    app.dependency_overrides[get_db] = override_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/api/v1/stats/history")

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json()["error"]["code"] == "AUTH_UNAUTHORIZED"
    db.execute.assert_not_awaited()


def test_history_openapi_adds_required_boolean_without_changing_auth_or_query_contract() -> None:
    from app.main import app

    spec = app.openapi()
    history = spec["paths"]["/api/v1/stats/history"]["get"]
    record = spec["components"]["schemas"]["DailyProgressItem"]

    assert history["security"] == [{"HTTPBearer": []}]
    assert {parameter["name"] for parameter in history["parameters"]} == {"year", "month"}
    assert all(parameter["required"] is False for parameter in history["parameters"])
    assert history["responses"]["200"]["content"]["application/json"]["schema"] == {"$ref": "#/components/schemas/HistoryResponse"}
    assert record["properties"]["hasStudied"]["type"] == "boolean"
    assert set(record["required"]) == {*LEGACY_RECORD, "hasStudied"}
    assert set(record["properties"]) == {*LEGACY_RECORD, "hasStudied"}
