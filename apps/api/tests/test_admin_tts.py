"""Tests for Phase 4: Admin TTS endpoints."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.models.tts import TtsAudio
from app.models.user import User
from app.routers.admin_content import require_reviewer

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def reviewer_user():
    """A mock reviewer User."""
    return User(
        id=uuid.UUID("00000000-0000-0000-0000-000000000099"),
        email="reviewer@example.com",
        nickname="リビュアー",
        jlpt_level="N5",
        daily_goal=10,
        experience_points=0,
        level=1,
        streak_count=0,
        longest_streak=0,
        is_premium=False,
        show_kana=False,
        onboarding_completed=True,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )


@pytest_asyncio.fixture
async def client(reviewer_user):
    """HTTP client with require_reviewer and get_db overridden."""
    from app.main import app

    mock_db = AsyncMock()

    async def override_require_reviewer():
        return reviewer_user

    async def override_get_db():
        yield mock_db

    app.dependency_overrides[require_reviewer] = override_require_reviewer
    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac, mock_db

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Helper builders
# ---------------------------------------------------------------------------


def _make_tts_record(
    audio_url: str = "https://storage.googleapis.com/harukoto-tts/tts/vocab/123.mp3",
    text: str = "こんにちは",
    provider: str = "elevenlabs",
) -> MagicMock:
    record = MagicMock(spec=TtsAudio)
    record.audio_url = audio_url
    record.text = text
    record.provider = provider
    return record


def _scalar_result(obj):
    r = MagicMock()
    r.scalar_one_or_none.return_value = obj
    return r


def _make_vocab(reading: str = "テスト") -> MagicMock:
    v = MagicMock()
    v.id = uuid.uuid4()
    v.word = "テスト"
    v.reading = reading
    v.meaning_ko = "테스트"
    return v


@dataclass
class FakeTtsResult:
    audio: bytes
    provider: str
    model: str


# ---------------------------------------------------------------------------
# GET /api/v1/admin/content/{content_type}/{item_id}/tts
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_tts_returns_audio_url(client):
    """GET returns audio_url when TtsAudio record exists."""
    ac, mock_db = client
    record = _make_tts_record()
    mock_db.execute.return_value = _scalar_result(record)

    resp = await ac.get("/api/v1/admin/content/vocabulary/test-id/tts")
    assert resp.status_code == 200
    data = resp.json()
    assert data["audioUrl"] == "https://storage.googleapis.com/harukoto-tts/tts/vocab/123.mp3"
    assert data["provider"] == "elevenlabs"


@pytest.mark.asyncio
async def test_get_tts_returns_null_when_no_record(client):
    """GET returns audio_url=null when no TtsAudio record exists."""
    ac, mock_db = client
    mock_db.execute.return_value = _scalar_result(None)

    resp = await ac.get("/api/v1/admin/content/vocabulary/test-id/tts")
    assert resp.status_code == 200
    data = resp.json()
    assert data["audioUrl"] is None
    assert data["field"] is None
    assert data["provider"] is None


# ---------------------------------------------------------------------------
# POST /api/v1/admin/content/tts/regenerate
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_regenerate_tts_success(client):
    """POST regenerate returns 200 with audio_url on success."""
    ac, mock_db = client

    vocab = _make_vocab(reading="テスト")
    call_count = 0

    def execute_side_effect(stmt):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            # Content item fetch
            return _scalar_result(vocab)
        # delete or other — return a generic mock
        return MagicMock()

    mock_db.execute.side_effect = execute_side_effect

    fake_tts = FakeTtsResult(audio=b"fake-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    with (
        patch("app.routers.admin_content.generate_tts") as mock_tts,
        patch("app.routers.admin_content._upload_to_gcs") as mock_upload,
    ):
        mock_tts.return_value = fake_tts
        mock_upload.return_value = "https://cdn.example.com/tts/admin/vocabulary/test-id.mp3"

        resp = await ac.post(
            "/api/v1/admin/content/tts/regenerate",
            json={"contentType": "vocabulary", "itemId": "test-id", "field": "reading"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["audioUrl"] == "https://cdn.example.com/tts/admin/vocabulary/test-id.mp3"
    assert data["provider"] == "elevenlabs"


@pytest.mark.asyncio
async def test_regenerate_tts_not_found_404(client):
    """POST regenerate returns 404 when content item does not exist."""
    ac, mock_db = client
    mock_db.execute.return_value = _scalar_result(None)

    resp = await ac.post(
        "/api/v1/admin/content/tts/regenerate",
        json={"contentType": "vocabulary", "itemId": "nonexistent-id", "field": "reading"},
    )

    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_regenerate_tts_empty_field_422(client):
    """POST regenerate returns 422 when requested field is empty on the content item."""
    ac, mock_db = client

    vocab = MagicMock()
    vocab.id = uuid.uuid4()
    vocab.reading = ""  # empty field
    mock_db.execute.return_value = _scalar_result(vocab)

    resp = await ac.post(
        "/api/v1/admin/content/tts/regenerate",
        json={"contentType": "vocabulary", "itemId": "test-id", "field": "reading"},
    )

    assert resp.status_code == 422
