import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.db.session import get_db
from app.models.enums import WordbookSource


@pytest.fixture
def mock_wordbook_entry(test_user_id):
    """Create a mock WordbookEntry with real attribute values for pydantic model_validate."""

    class FakeEntry:
        def __init__(self):
            self.id = uuid.uuid4()
            self.user_id = test_user_id
            self.word = "食べる"
            self.reading = "たべる"
            self.meaning_ko = "먹다"
            self.source = WordbookSource.MANUAL
            self.note = None
            self.created_at = datetime.now(UTC)

    return FakeEntry()


@pytest.mark.asyncio
async def test_create_wordbook_entry(client, mock_user, mock_wordbook_entry, test_user_id):
    """Test POST /api/v1/wordbook/ creates a new wordbook entry."""
    from app.main import app

    mock_session = AsyncMock()

    # First execute: pg_insert (upsert)
    mock_upsert_result = MagicMock()
    # Second execute: select to return the created entry
    mock_select_result = MagicMock()
    mock_select_result.scalar_one.return_value = mock_wordbook_entry

    mock_session.execute = AsyncMock(side_effect=[mock_upsert_result, mock_select_result])
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/wordbook/",
        json={
            "word": "食べる",
            "reading": "たべる",
            "meaningKo": "먹다",
            "source": "MANUAL",
        },
    )
    assert response.status_code == 201

    data = response.json()
    assert data["word"] == "食べる"
    assert data["reading"] == "たべる"
    assert data["meaningKo"] == "먹다"


@pytest.mark.asyncio
async def test_list_wordbook_entries(client, mock_user, mock_wordbook_entry, test_user_id):
    """Test GET /api/v1/wordbook/ returns paginated entries."""
    from app.main import app

    mock_session = AsyncMock()

    # First execute: count query
    mock_count_result = MagicMock()
    mock_count_result.scalar.return_value = 1

    # Second execute: select entries
    mock_entries_result = MagicMock()
    mock_entries_result.scalars.return_value.all.return_value = [mock_wordbook_entry]

    mock_session.execute = AsyncMock(side_effect=[mock_count_result, mock_entries_result])

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/wordbook/")
    assert response.status_code == 200

    data = response.json()
    assert data["total"] == 1
    assert data["page"] == 1
    assert len(data["entries"]) == 1
    assert data["entries"][0]["word"] == "食べる"


@pytest.mark.asyncio
async def test_update_wordbook_entry(client, mock_user, mock_wordbook_entry, test_user_id):
    """Test PATCH /api/v1/wordbook/{id} updates the entry note."""
    from app.main import app

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_wordbook_entry)
    mock_session.commit = AsyncMock()

    async def mock_refresh(obj):
        obj.note = "새로운 메모"

    mock_session.refresh = mock_refresh

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.patch(
        f"/api/v1/wordbook/{mock_wordbook_entry.id}",
        json={"note": "새로운 메모"},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["note"] == "새로운 메모"


@pytest.mark.asyncio
async def test_delete_wordbook_entry(client, mock_user, mock_wordbook_entry, test_user_id):
    """Test DELETE /api/v1/wordbook/{id} removes the entry."""
    from app.main import app

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_wordbook_entry)
    mock_session.delete = AsyncMock()
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.delete(
        f"/api/v1/wordbook/{mock_wordbook_entry.id}",
    )
    assert response.status_code == 200
    assert response.json()["ok"] is True


@pytest.mark.asyncio
async def test_delete_wordbook_entry_not_found(client, mock_user, test_user_id):
    """Test DELETE /api/v1/wordbook/{id} returns 404 for non-existent entry."""
    from app.main import app

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=None)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.delete(
        f"/api/v1/wordbook/{uuid.uuid4()}",
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "단어장 항목을 찾을 수 없습니다"
