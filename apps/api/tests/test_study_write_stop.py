"""The legacy STOP gate is explicit, pre-dependency and source-controlled."""

import re
from typing import Annotated

import pytest
from fastapi import Depends, FastAPI
from fastapi.routing import APIRoute
from httpx import ASGITransport, AsyncClient
from starlette.responses import JSONResponse

from app.config import settings
from app.db.session import get_db
from app.dependencies import get_current_user
from app.main import app
from app.middleware import study_write_stop as stop

# Explicit exceptions keep the audit honest: a new route cannot silently be
# classified as a read just because it uses GET (missions/incomplete both write).
REVIEWED_ALLOW_ROUTES = frozenset(
    {
        ("GET", "/health"),
        ("GET", "/api/v1/achievements"),
        ("POST", "/api/v1/auth/kakao/exchange"),
        ("POST", "/api/v1/auth/ensure-user"),
        ("POST", "/api/v1/auth/onboarding"),
        ("GET", "/api/v1/user/profile"),
        ("GET", "/api/v1/quiz/stats"),
        ("GET", "/api/v1/quiz/wrong-answers"),
        ("GET", "/api/v1/quiz/smart-preview"),
        ("GET", "/api/v1/quiz/recommendations"),
        ("GET", "/api/v1/kana/characters"),
        ("GET", "/api/v1/kana/stages"),
        ("GET", "/api/v1/kana/progress"),
        ("POST", "/api/v1/kana/tts"),
        ("POST", "/api/v1/chat/tts"),
        ("POST", "/api/v1/chat/voice/transcribe"),
        ("GET", "/api/v1/chat/scenarios"),
        ("GET", "/api/v1/chat/history"),
        ("GET", "/api/v1/chat/characters"),
        ("GET", "/api/v1/chat/characters/stats"),
        ("GET", "/api/v1/chat/characters/favorites"),
        ("POST", "/api/v1/chat/characters/favorites"),
        ("GET", "/api/v1/chat/{conversation_id}"),
        ("GET", "/api/v1/stats/dashboard"),
        ("GET", "/api/v1/stats/history"),
        ("GET", "/api/v1/stats/heatmap"),
        ("GET", "/api/v1/stats/jlpt-progress"),
        ("GET", "/api/v1/stats/time-chart"),
        ("GET", "/api/v1/stats/volume-chart"),
        ("GET", "/api/v1/stats/by-category"),
        ("GET", "/api/v1/wordbook/"),
        ("POST", "/api/v1/wordbook/"),
        ("GET", "/api/v1/wordbook/{entry_id}"),
        ("PATCH", "/api/v1/wordbook/{entry_id}"),
        ("DELETE", "/api/v1/wordbook/{entry_id}"),
        ("GET", "/api/v1/subscription/status"),
        ("POST", "/api/v1/subscription/checkout"),
        ("POST", "/api/v1/subscription/activate"),
        ("POST", "/api/v1/subscription/store/verify"),
        ("POST", "/api/v1/subscription/cancel"),
        ("POST", "/api/v1/subscription/resume"),
        ("GET", "/api/v1/payments"),
        ("POST", "/api/v1/webhook/portone"),
        ("POST", "/api/v1/webhook/apple/app-store-server"),
        ("POST", "/api/v1/webhook/google/play"),
        ("POST", "/api/v1/cron/subscription-renewal"),
        ("POST", "/api/v1/cron/ensure-partitions"),
        ("POST", "/api/v1/cron/fsrs-shadow-report"),
        ("POST", "/api/v1/push/subscribe"),
        ("GET", "/api/v1/notifications/"),
        ("PATCH", "/api/v1/notifications/"),
        ("POST", "/api/v1/vocab/tts"),
        ("GET", "/api/v1/study/learned-words"),
        ("GET", "/api/v1/study/wrong-answers"),
        ("GET", "/api/v1/study/stages"),
        ("GET", "/api/v1/study/capabilities"),
        ("GET", "/api/v1/lessons/{lesson_id}/submissions/{submission_id}"),
        ("GET", "/api/v1/lessons/chapters"),
        ("GET", "/api/v1/lessons/review/summary"),
        ("POST", "/api/v1/lessons/{lesson_id}/script-lines/{line_index}/tts"),
        ("POST", "/api/v1/lessons/{lesson_id}/questions/{question_order}/tts"),
        ("GET", "/api/v1/lessons/{lesson_id}"),
    }
)


def sample_path(template):
    return re.sub(r"\{[^}]+\}", "10000000-0000-4000-8000-000000000001", template)


def test_source_policy_is_boolean_and_every_legacy_route_has_an_explicit_review_classification():
    assert type(stop.STUDY_WRITES_PAUSED) is bool
    actual = {
        (method, route.path)
        for route in app.routes
        if isinstance(route, APIRoute) and not route.path.startswith("/api/v1/admin")
        for method in route.methods
    }
    # These explicitly reviewed future routes need no new ORM in the legacy
    # bridge. A later feature integration must still revalidate its own schema.
    future_read = {("GET", "/api/v1/lessons/{lesson_id}/study-activities/{activity_id}")}
    future = {("POST", "/api/v1/lessons/{lesson_id}/study-activities")} | future_read
    assert stop.BLOCKED_ROUTES.isdisjoint(REVIEWED_ALLOW_ROUTES)
    assert actual | future == stop.BLOCKED_ROUTES | REVIEWED_ALLOW_ROUTES | future_read


@pytest.mark.parametrize("method,template", sorted(stop.BLOCKED_ROUTES))
async def test_paused_actual_app_rejects_each_writer_before_any_auth_or_db_dependency(monkeypatch, method, template):
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)

    async def forbidden():
        raise AssertionError("A paused writer must not open auth/DB or enter its service")

    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = forbidden
    app.dependency_overrides[get_current_user] = forbidden
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            # Invalid JSON/IDs cannot force body validation or dependency access.
            response = await client.request(method, sample_path(template), content=b"invalid-json")
        assert response.status_code == 503
        assert response.json() == {"detail": stop.STOP_MESSAGE}
        assert response.headers["Retry-After"] == "60"
        assert response.headers["Cache-Control"] == "private, no-store"
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)


@pytest.mark.parametrize("method,template", sorted(stop.BLOCKED_ROUTES | REVIEWED_ALLOW_ROUTES))
async def test_off_delegates_original_method_path_and_body_without_rewriting(method, template):
    seen = []

    async def downstream(scope, receive, send):
        seen.append((scope["method"], scope["path"], await receive()))
        await JSONResponse({"original": True})(scope, receive, send)

    async with AsyncClient(transport=ASGITransport(app=stop.StudyWriteStopMiddleware(downstream)), base_url="http://test") as client:
        response = await client.request(method, sample_path(template), content=b"payload")
    assert response.status_code == 200
    assert response.headers.get("Retry-After") is None
    assert seen[0][0:2] == (method, sample_path(template))
    assert seen[0][2]["body"] == b"payload"


@pytest.mark.parametrize("method,template", sorted(REVIEWED_ALLOW_ROUTES))
async def test_paused_passes_login_read_audio_billing_and_independent_metadata_to_original_app(monkeypatch, method, template):
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    calls = []

    async def downstream(scope, receive, send):
        calls.append(scope["path"])
        await JSONResponse({"original": True})(scope, receive, send)

    async with AsyncClient(transport=ASGITransport(app=stop.StudyWriteStopMiddleware(downstream)), base_url="http://test") as client:
        response = await client.request(method, sample_path(template))
    assert response.status_code == 200 and len(calls) == 1


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/quiz/answer/",
        "/api//v1///quiz/answer",
        "/api/v1/quiz/%61nswer",
        "/api/v1/quiz/%2561nswer",
        "/api/v1/quiz%2Fanswer",
        "/api/v1/quiz%252Fanswer",
        "/api/v1/x/../quiz/answer",
    ],
)
async def test_ambiguous_paths_cannot_bypass_pause(monkeypatch, path):
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)

    async def forbidden(scope, receive, send):
        raise AssertionError("Encoded writer reached the handler")

    async with AsyncClient(transport=ASGITransport(app=stop.StudyWriteStopMiddleware(forbidden)), base_url="http://test") as client:
        response = await client.post(path)
    assert response.status_code == 503


async def test_gate_reads_no_request_body_and_has_no_request_header_override(monkeypatch):
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    received = []
    sent = []

    async def receive():
        received.append(True)
        raise AssertionError("No body should be consumed")

    async def send(message):
        sent.append(message)

    async def forbidden(scope, receive, send):
        raise AssertionError("Paused request reached app")

    scope = {"type": "http", "method": "POST", "path": "/api/v1/quiz/answer", "headers": [(b"x-study-writes-paused", b"false")]}
    await stop.StudyWriteStopMiddleware(forbidden)(scope, receive, send)
    assert not received and sent[0]["status"] == 503


@pytest.mark.parametrize("path", ["/api/v1/missions/today", "/api/v1/quiz/incomplete"])
async def test_head_of_read_writer_is_paused_too(monkeypatch, path):
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.head(path)
    assert response.status_code == 503


async def test_cors_preflight_and_paused_response_keep_original_origin_policy(monkeypatch):
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    origin = settings.cors_origins_list[0]
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        preflight = await client.options("/api/v1/quiz/answer", headers={"Origin": origin, "Access-Control-Request-Method": "POST"})
        paused = await client.post("/api/v1/quiz/answer", headers={"Origin": origin})
    assert preflight.status_code == 200 and preflight.headers["Access-Control-Allow-Origin"] == origin
    assert paused.status_code == 503 and paused.headers["Access-Control-Allow-Origin"] == origin


async def test_auth_is_not_relaxed_for_allowed_get_or_post_when_paused(monkeypatch):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        original_get = await client.get("/api/v1/user/profile")
        original_post = await client.post("/api/v1/auth/ensure-user", json={})
        monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
        paused_get = await client.get("/api/v1/user/profile")
        paused_post = await client.post("/api/v1/auth/ensure-user", json={})
    assert paused_get.status_code == original_get.status_code in {401, 403}
    assert paused_post.status_code == original_post.status_code in {401, 403}


async def test_mounted_root_path_cannot_bypass_pause(monkeypatch):
    monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
    app_under_mount = FastAPI()
    app_under_mount.mount("/prefix", stop.StudyWriteStopMiddleware(FastAPI()))
    async with AsyncClient(transport=ASGITransport(app=app_under_mount), base_url="http://test") as client:
        response = await client.post("/prefix/api/v1/quiz/answer")
    assert response.status_code == 503


async def test_flag_can_be_reopened_in_isolated_process_without_replacing_domain_logic(monkeypatch):
    calls = []
    probe = FastAPI()

    async def dependency():
        calls.append("dependency")

    @probe.post("/api/v1/quiz/start")
    async def start(body: dict, allowed: Annotated[None, Depends(dependency)]):
        calls.append("handler")
        return body

    probe.add_middleware(stop.StudyWriteStopMiddleware)
    async with AsyncClient(transport=ASGITransport(app=probe), base_url="http://test") as client:
        monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", True)
        assert (await client.post("/api/v1/quiz/start", json={"same": "payload"})).status_code == 503
        assert calls == []
        monkeypatch.setattr(stop, "STUDY_WRITES_PAUSED", False)
        assert (await client.post("/api/v1/quiz/start", json={"same": "payload"})).json() == {"same": "payload"}
    assert calls == ["dependency", "handler"]
