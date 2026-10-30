from __future__ import annotations

from unittest.mock import AsyncMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError

from app.db.session import get_db
from app.error_handlers import register_error_handlers
from app.routers.stats import router
from app.schemas.stats import TodayStats

LEGACY_TODAY = {
    "wordsStudied": 8,
    "quizzesCompleted": 2,
    "correctAnswers": 17,
    "totalAnswers": 20,
    "xpEarned": 120,
    "goalProgress": 1.0,
    "hasStudied": True,
}


@pytest.mark.parametrize("count", [0, 1, 15])
def test_today_serializes_required_vocabulary_goal_and_preserves_legacy_fields(count: int) -> None:
    payload = {**LEGACY_TODAY, "vocabularyGoal": {"date": "2026-10-30", "answeredCount": count}}

    assert TodayStats.model_validate(payload).model_dump(mode="json", by_alias=True) == payload


@pytest.mark.parametrize(
    "extra",
    [{}, {"vocabularyGoal": None}, {"vocabularyGoal": {}}, {"vocabularyGoal": {"date": "2026-10-30", "answeredCount": -1}}],
    ids=["missing", "null", "empty", "negative-count"],
)
def test_today_requires_nonnull_vocabulary_goal_with_nonnegative_count(extra: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        TodayStats.model_validate({**LEGACY_TODAY, **extra})


@pytest.mark.asyncio
async def test_dashboard_still_requires_auth_before_reading_progress() -> None:
    app = FastAPI()
    app.include_router(router)
    register_error_handlers(app)
    db = AsyncMock()

    async def override_db():
        yield db

    app.dependency_overrides[get_db] = override_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/api/v1/stats/dashboard")

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json()["error"]["code"] == "AUTH_UNAUTHORIZED"
    db.execute.assert_not_awaited()


def test_dashboard_openapi_exposes_additive_required_vocabulary_goal_without_auth_changes() -> None:
    from app.main import app

    spec = app.openapi()
    dashboard = spec["paths"]["/api/v1/stats/dashboard"]["get"]
    today = spec["components"]["schemas"]["TodayStats"]

    assert dashboard["security"] == [{"HTTPBearer": []}]
    assert dashboard.get("parameters", []) == []
    assert dashboard["responses"]["200"]["content"]["application/json"]["schema"] == {"$ref": "#/components/schemas/DashboardResponse"}
    assert set(today["required"]) == {*LEGACY_TODAY, "vocabularyGoal"}
    assert set(today["properties"]) == {*LEGACY_TODAY, "vocabularyGoal"}
    goal_ref = today["properties"]["vocabularyGoal"]["$ref"].rsplit("/", 1)[1]
    goal = spec["components"]["schemas"][goal_ref]
    assert set(goal["required"]) == {"date", "answeredCount"}
    assert set(goal["properties"]) == {"date", "answeredCount"}
    assert goal["properties"]["date"]["type"] == "string"
    assert goal["properties"]["date"]["format"] == "date"
    assert goal["properties"]["answeredCount"]["type"] == "integer"
    assert goal["properties"]["answeredCount"]["minimum"] == 0
