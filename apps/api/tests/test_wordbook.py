import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from asyncpg.exceptions import UniqueViolationError
from sqlalchemy.exc import IntegrityError

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
@pytest.mark.parametrize("note_fields", [{}, {"note": "내 메모"}, {"note": None}])
async def test_create_wordbook_entry(client, mock_wordbook_entry, note_fields):
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
            **note_fields,
        },
    )
    assert response.status_code == 201

    data = response.json()
    assert data["word"] == "食べる"
    assert data["reading"] == "たべる"
    assert data["meaningKo"] == "먹다"
    update_clause = str(mock_session.execute.await_args_list[0].args[0]).split("DO UPDATE SET", 1)[1]
    assert ("note =" in update_clause) == ("note" in note_fields)
    assert " WHERE " not in update_clause


@pytest.mark.asyncio
async def test_save_conversation_expression_preserves_existing_personal_entry(client, mock_wordbook_entry):
    from app.main import app

    mock_wordbook_entry.note = "내가 직접 쓴 메모"
    selected = MagicMock()
    selected.scalar_one.return_value = mock_wordbook_entry
    db = AsyncMock()
    db.execute.side_effect = [MagicMock(), selected]

    async def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    response = await client.post(
        "/api/v1/wordbook/",
        json={"word": "食べる", "reading": "", "meaningKo": "AI 뜻", "source": "CONVERSATION", "preserveExisting": True},
    )
    assert response.status_code == 201
    assert response.json()["note"] == "내가 직접 쓴 메모"
    assert response.json()["meaningKo"] == "먹다"
    assert response.json()["source"] == "MANUAL"
    assert "DO NOTHING" in str(db.execute.await_args_list[0].args[0])


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
async def test_update_wordbook_entry(client, mock_wordbook_entry):
    """Test PATCH /api/v1/wordbook/{id} updates the entry note."""
    from app.main import app

    mock_session = AsyncMock()
    mock_wordbook_entry.source = WordbookSource.QUIZ
    mock_session.scalar.return_value = mock_wordbook_entry

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
    assert data["word"] == "食べる"


@pytest.fixture
def wordbook_db(client, mock_wordbook_entry):
    from app.main import app

    db = AsyncMock()
    db.get.return_value = mock_wordbook_entry
    db.scalar.return_value = mock_wordbook_entry

    async def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    return db


@pytest.mark.parametrize("source", ["QUIZ", "CONVERSATION"])
async def test_legacy_import_never_overwrites_manual_entry(client, mock_wordbook_entry, wordbook_db, source):
    mock_wordbook_entry.note = "직접 작성한 메모"
    selected = MagicMock()
    selected.scalar_one.return_value = mock_wordbook_entry
    wordbook_db.execute.side_effect = [MagicMock(), selected]

    response = await client.post(
        "/api/v1/wordbook/",
        json={"word": "食べる", "reading": "別", "meaningKo": "다른 뜻", "source": source, "note": "다른 메모"},
    )

    assert response.status_code == 201
    assert response.json()["reading"] == "たべる"
    assert response.json()["meaningKo"] == "먹다"
    assert response.json()["note"] == "직접 작성한 메모"
    stmt = wordbook_db.execute.await_args_list[0].args[0]
    assert "WHERE wordbook_entries.source !=" in str(stmt)
    assert stmt.compile().params["source_1"] == WordbookSource.MANUAL


@pytest.mark.parametrize(
    ("matches", "sentence", "translation"),
    [
        ([("朝ご飯を食べる。", "아침밥을 먹다.")], "朝ご飯を食べる。", "아침밥을 먹다."),
        ([("朝ご飯を食べる。", None)], "朝ご飯を食べる。", None),
        ([("朝ご飯を食べる。", "아침밥을 먹다."), ("お寿司を食べる。", "초밥을 먹다.")], None, None),
        ([], None, None),
    ],
)
async def test_wordbook_detail_uses_only_unambiguous_exact_example(
    client, mock_wordbook_entry, wordbook_db, matches, sentence, translation
):
    result = MagicMock()
    result.tuples.return_value.all.return_value = matches
    wordbook_db.execute.return_value = result

    response = await client.get(f"/api/v1/wordbook/{mock_wordbook_entry.id}")

    assert response.status_code == 200
    assert response.json()["exampleSentence"] == sentence
    assert response.json()["exampleTranslation"] == translation
    assert response.json()["word"] == mock_wordbook_entry.word
    query = wordbook_db.execute.await_args.args[0]
    assert query.compile().params == {
        "word_1": "食べる",
        "reading_1": "たべる",
        "meaning_ko_1": "먹다",
        "btrim_1": "",
        "param_1": 2,
    }
    assert "SELECT DISTINCT" in str(query)


async def test_wordbook_detail_other_user_cannot_look_up_examples(client, mock_wordbook_entry, wordbook_db):
    mock_wordbook_entry.user_id = uuid.uuid4()

    response = await client.get(f"/api/v1/wordbook/{mock_wordbook_entry.id}")

    assert response.status_code == 404
    wordbook_db.execute.assert_not_awaited()


async def test_wordbook_patch_manual_fields_preserve_omitted_note(client, mock_wordbook_entry, wordbook_db, test_user_id):
    mock_wordbook_entry.note = "내 메모"

    response = await client.patch(
        f"/api/v1/wordbook/{mock_wordbook_entry.id}",
        json={"word": "  飯  ", "reading": "めし", "meaningKo": "밥"},
    )

    assert response.status_code == 200
    assert response.json()["word"] == "飯"
    assert response.json()["reading"] == "めし"
    assert response.json()["meaningKo"] == "밥"
    assert response.json()["note"] == "내 메모"
    query = wordbook_db.scalar.await_args.args[0]
    assert query.compile().params == {"id_1": mock_wordbook_entry.id, "user_id_1": test_user_id}
    assert "FOR UPDATE" in str(query)


@pytest.mark.parametrize(
    ("body", "source", "status"),
    [
        ({"word": "飯"}, WordbookSource.CONVERSATION, 403),
        ({"reading": "めし"}, WordbookSource.QUIZ, 403),
        ({"meaningKo": "  "}, WordbookSource.MANUAL, 422),
    ],
)
async def test_wordbook_patch_rejects_ineligible_edit(client, mock_wordbook_entry, wordbook_db, body, source, status):
    mock_wordbook_entry.source = source
    response = await client.patch(f"/api/v1/wordbook/{mock_wordbook_entry.id}", json=body)
    assert response.status_code == status
    wordbook_db.commit.assert_not_awaited()


async def test_wordbook_patch_missing_or_other_users_entry_is_not_found(client, mock_wordbook_entry, wordbook_db):
    wordbook_db.scalar.return_value = None
    response = await client.patch(f"/api/v1/wordbook/{mock_wordbook_entry.id}", json={"word": "飯"})
    assert response.status_code == 404
    wordbook_db.commit.assert_not_awaited()


@pytest.mark.parametrize("constraint_name", ["wordbook_entries_user_id_word_key", "unrelated_key"])
async def test_wordbook_patch_rolls_back_constraint_failure(client, mock_wordbook_entry, wordbook_db, constraint_name):
    driver_error = UniqueViolationError("duplicate key")
    driver_error.constraint_name = constraint_name
    adapter_error = Exception("adapter error")
    adapter_error.__cause__ = driver_error
    error = IntegrityError("UPDATE wordbook_entries", {}, adapter_error)
    wordbook_db.commit.side_effect = error
    url = f"/api/v1/wordbook/{mock_wordbook_entry.id}"

    if constraint_name == "wordbook_entries_user_id_word_key":
        response = await client.patch(url, json={"word": "飯", "note": "보존할 메모"})
        assert response.status_code == 409
    else:
        with pytest.raises(IntegrityError) as raised:
            await client.patch(url, json={"word": "飯"})
        assert raised.value is error
    wordbook_db.rollback.assert_awaited_once()


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
    assert response.json()["error"]["message"] == "단어장 항목을 찾을 수 없습니다"
