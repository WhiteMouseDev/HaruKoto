"""Tests for Phase 4/6: Admin TTS endpoints with per-field audio support."""

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
    mock_db.add = MagicMock()

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
    field: str = "reading",
    created_at: datetime | None = None,
) -> MagicMock:
    record = MagicMock(spec=TtsAudio)
    record.audio_url = audio_url
    record.text = text
    record.provider = provider
    record.field = field
    record.created_at = created_at or datetime.now(UTC)
    return record


def _scalars_result(objs: list):
    """Mock result that returns scalars().all() -> list."""
    r = MagicMock()
    scalars_mock = MagicMock()
    scalars_mock.all.return_value = objs
    r.scalars.return_value = scalars_mock
    return r


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
# GET /api/v1/admin/content/{content_type}/{item_id}/tts (map response)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_tts_returns_map_with_existing_audio(client):
    """GET returns audios map with populated field when TtsAudio records exist."""
    ac, mock_db = client
    record = _make_tts_record(field="reading")
    mock_db.execute.return_value = _scalars_result([record])

    resp = await ac.get("/api/v1/admin/content/vocabulary/test-id/tts")
    assert resp.status_code == 200
    data = resp.json()
    assert "audios" in data
    assert data["audios"]["reading"] is not None
    assert data["audios"]["reading"]["audioUrl"] == record.audio_url
    assert data["audios"]["reading"]["provider"] == "elevenlabs"
    # Other fields should be null
    assert data["audios"]["word"] is None
    assert data["audios"]["example_sentence"] is None


@pytest.mark.asyncio
async def test_get_tts_returns_all_null_when_no_records(client):
    """GET returns audios map with all null when no TtsAudio records exist."""
    ac, mock_db = client
    mock_db.execute.return_value = _scalars_result([])

    resp = await ac.get("/api/v1/admin/content/vocabulary/test-id/tts")
    assert resp.status_code == 200
    data = resp.json()
    assert "audios" in data
    assert data["audios"]["reading"] is None
    assert data["audios"]["word"] is None
    assert data["audios"]["example_sentence"] is None


@pytest.mark.asyncio
async def test_get_tts_returns_multiple_fields(client):
    """GET returns audios map with multiple populated fields."""
    ac, mock_db = client
    reading_rec = _make_tts_record(field="reading", audio_url="https://cdn/reading.mp3")
    word_rec = _make_tts_record(field="word", audio_url="https://cdn/word.mp3")
    mock_db.execute.return_value = _scalars_result([reading_rec, word_rec])

    resp = await ac.get("/api/v1/admin/content/vocabulary/test-id/tts")
    assert resp.status_code == 200
    data = resp.json()
    assert data["audios"]["reading"]["audioUrl"] == "https://cdn/reading.mp3"
    assert data["audios"]["word"]["audioUrl"] == "https://cdn/word.mp3"
    assert data["audios"]["example_sentence"] is None


@pytest.mark.asyncio
async def test_get_tts_invalid_content_type_400(client):
    """GET returns 400 for unknown content_type."""
    ac, mock_db = client
    resp = await ac.get("/api/v1/admin/content/invalid_type/test-id/tts")
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# POST /api/v1/admin/content/tts/regenerate (field-scoped)
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
        patch("app.routers.admin_content.upload_tts_to_gcs") as mock_upload,
    ):
        mock_tts.return_value = fake_tts
        mock_upload.return_value = "https://cdn.example.com/tts/admin/vocabulary/test-id/reading.mp3"

        resp = await ac.post(
            "/api/v1/admin/content/tts/regenerate",
            json={"contentType": "vocabulary", "itemId": "test-id", "field": "reading"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["audioUrl"] == "https://cdn.example.com/tts/admin/vocabulary/test-id/reading.mp3"
    assert data["provider"] == "elevenlabs"
    assert data["field"] == "reading"

    # Verify GCS path includes field
    mock_upload.assert_called_once()
    gcs_path_arg = mock_upload.call_args[0][0]
    assert "/reading.mp3" in gcs_path_arg


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


@pytest.mark.asyncio
async def test_regenerate_tts_invalid_field_422(client):
    """POST regenerate returns 422 when field is not valid for content_type."""
    ac, mock_db = client

    resp = await ac.post(
        "/api/v1/admin/content/tts/regenerate",
        json={"contentType": "vocabulary", "itemId": "test-id", "field": "nonexistent_field"},
    )

    assert resp.status_code == 422
    body = resp.json()
    # Custom error handler wraps HTTPException detail into error.message
    assert "Invalid field" in (body.get("detail", "") or body.get("error", {}).get("message", ""))


@pytest.mark.asyncio
async def test_regenerate_tts_field_scoped_delete(client):
    """POST regenerate only deletes the targeted field's row, not other fields."""
    ac, mock_db = client

    vocab = _make_vocab(reading="テスト")
    call_count = 0
    delete_stmt_captured = None

    def execute_side_effect(stmt):
        nonlocal call_count, delete_stmt_captured
        call_count += 1
        if call_count == 1:
            return _scalar_result(vocab)
        if call_count == 2:
            # Capture the delete statement to verify field-scoped delete
            delete_stmt_captured = stmt
            return MagicMock()
        return MagicMock()

    mock_db.execute.side_effect = execute_side_effect

    fake_tts = FakeTtsResult(audio=b"fake-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    with (
        patch("app.routers.admin_content.generate_tts") as mock_tts,
        patch("app.routers.admin_content.upload_tts_to_gcs") as mock_upload,
    ):
        mock_tts.return_value = fake_tts
        mock_upload.return_value = "https://cdn.example.com/tts/admin/vocabulary/test-id/reading.mp3"

        resp = await ac.post(
            "/api/v1/admin/content/tts/regenerate",
            json={"contentType": "vocabulary", "itemId": "test-id", "field": "reading"},
        )

    assert resp.status_code == 200
    # The delete statement should have been called (2nd execute call)
    assert delete_stmt_captured is not None
    # Verify that the delete includes field filter by checking compiled SQL
    compiled = str(delete_stmt_captured.compile(compile_kwargs={"literal_binds": True}))
    assert "field" in compiled.lower()


@pytest.mark.asyncio
async def test_regenerate_tts_adds_field_to_tts_audio(client):
    """POST regenerate includes field in TtsAudio constructor."""
    ac, mock_db = client

    vocab = _make_vocab(reading="テスト")
    call_count = 0

    def execute_side_effect(stmt):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return _scalar_result(vocab)
        return MagicMock()

    mock_db.execute.side_effect = execute_side_effect

    fake_tts = FakeTtsResult(audio=b"fake-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    with (
        patch("app.routers.admin_content.generate_tts") as mock_tts,
        patch("app.routers.admin_content.upload_tts_to_gcs") as mock_upload,
    ):
        mock_tts.return_value = fake_tts
        mock_upload.return_value = "https://cdn.example.com/tts/admin/vocabulary/test-id/reading.mp3"

        await ac.post(
            "/api/v1/admin/content/tts/regenerate",
            json={"contentType": "vocabulary", "itemId": "test-id", "field": "reading"},
        )

    # Verify db.add was called with a TtsAudio that has field set
    mock_db.add.assert_called_once()
    added_obj = mock_db.add.call_args[0][0]
    assert isinstance(added_obj, TtsAudio)
    assert added_obj.field == "reading"
