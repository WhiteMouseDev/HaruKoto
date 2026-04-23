"""Tests for Phase 3: Content editing, review workflow, and audit logs."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.db.session import get_db
from app.enums import JlptLevel, ReviewStatus
from app.models.enums import PartOfSpeech, ScenarioCategory
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
        nickname="리뷰어",
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
async def admin_client(reviewer_user):
    """HTTP client with require_reviewer and get_db overridden."""
    from app.main import app

    async def override_require_reviewer():
        return reviewer_user

    async def override_get_db():
        mock_session = AsyncMock()
        yield mock_session

    app.dependency_overrides[require_reviewer] = override_require_reviewer
    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac

    app.dependency_overrides.clear()


def _make_vocab(
    vocab_id: uuid.UUID | None = None,
    word: str = "食べる",
    reading: str = "たべる",
    meaning_ko: str = "먹다",
    review_status: ReviewStatus = ReviewStatus.NEEDS_REVIEW,
) -> MagicMock:
    """Build a mock Vocabulary ORM object."""
    v = MagicMock()
    v.id = vocab_id or uuid.uuid4()
    v.word = word
    v.reading = reading
    v.meaning_ko = meaning_ko
    v.jlpt_level = JlptLevel.N5
    v.part_of_speech = PartOfSpeech.VERB
    v.example_sentence = None
    v.example_reading = None
    v.example_translation = None
    v.review_status = review_status
    v.created_at = datetime.now(UTC)
    return v


def _make_grammar(
    grammar_id: uuid.UUID | None = None,
    pattern: str = "〜ている",
    meaning_ko: str = "~하고 있다",
    explanation: str = "진행 중인 상태",
    review_status: ReviewStatus = ReviewStatus.NEEDS_REVIEW,
) -> MagicMock:
    g = MagicMock()
    g.id = grammar_id or uuid.uuid4()
    g.pattern = pattern
    g.meaning_ko = meaning_ko
    g.explanation = explanation
    g.example_sentences = []
    g.jlpt_level = JlptLevel.N5
    g.review_status = review_status
    g.created_at = datetime.now(UTC)
    return g


def _make_cloze(
    cloze_id: uuid.UUID | None = None,
    sentence: str = "私は___を食べる。",
    review_status: ReviewStatus = ReviewStatus.NEEDS_REVIEW,
) -> MagicMock:
    c = MagicMock()
    c.id = cloze_id or uuid.uuid4()
    c.sentence = sentence
    c.translation = "I eat ___."
    c.correct_answer = "ご飯"
    c.options = ["ご飯", "みず", "パン"]
    c.explanation = "explanation"
    c.jlpt_level = JlptLevel.N5
    c.review_status = review_status
    c.created_at = datetime.now(UTC)
    return c


def _make_conversation(
    conv_id: uuid.UUID | None = None,
    title: str = "カフェで注文する",
    review_status: ReviewStatus = ReviewStatus.NEEDS_REVIEW,
) -> MagicMock:
    c = MagicMock()
    c.id = conv_id or uuid.uuid4()
    c.title = title
    c.title_ja = "カフェで注文する"
    c.description = "카페에서 주문하기"
    c.situation = "카페"
    c.your_role = "손님"
    c.ai_role = "점원"
    c.system_prompt = None
    c.key_expressions = ["ください", "おすすめ"]
    c.category = ScenarioCategory.DAILY
    c.review_status = review_status
    c.created_at = datetime.now(UTC)
    return c


def _scalar_result(obj):
    """Wrap obj in a mock that returns it from scalar_one_or_none()."""
    r = MagicMock()
    r.scalar_one_or_none.return_value = obj
    return r


def _scalars_result(objs: list):
    """Wrap objs in a mock that returns them from scalars().all()."""
    r = MagicMock()
    r.scalars.return_value.all.return_value = objs
    return r


def _audit_rows_result(logs: list, reviewer_email: str = "reviewer@example.com"):
    """Wrap AuditLog list in a mock shaped for list_admin_audit_logs (uses result.all())."""
    r = MagicMock()
    r.all.return_value = [(log, reviewer_email) for log in logs]
    return r


# ---------------------------------------------------------------------------
# EDIT tests (PATCH endpoints)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_patch_vocabulary_updates_changed_fields_only(admin_client, reviewer_user):
    """EDIT-01: PATCH /vocabulary/{id} updates only sent fields."""
    from app.main import app

    vocab_id = uuid.uuid4()
    vocab = _make_vocab(vocab_id=vocab_id, word="食べる")

    # Simulate: after setattr, word is changed; after commit/refresh the mock still has updated word
    def side_effect_execute(stmt):
        result = _scalar_result(vocab)
        return result

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(side_effect=side_effect_execute)
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.patch(
                f"/api/v1/admin/content/vocabulary/{vocab_id}",
                json={"word": "飲む"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    # word was updated via setattr on the mock object — the mock now has new word
    data = response.json()
    assert "id" in data


@pytest.mark.asyncio
async def test_patch_grammar_updates_changed_fields_only(admin_client, reviewer_user):
    """EDIT-02: PATCH /grammar/{id} updates only sent fields."""
    from app.main import app

    grammar_id = uuid.uuid4()
    grammar = _make_grammar(grammar_id=grammar_id)

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=_scalar_result(grammar))
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.patch(
                f"/api/v1/admin/content/grammar/{grammar_id}",
                json={"pattern": "〜てみる"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()
    assert "id" in data


@pytest.mark.asyncio
async def test_patch_quiz_updates_changed_fields_only(admin_client, reviewer_user):
    """EDIT-03: PATCH /quiz/cloze/{id} updates only sent fields."""
    from app.main import app

    cloze_id = uuid.uuid4()
    cloze = _make_cloze(cloze_id=cloze_id)

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=_scalar_result(cloze))
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.patch(
                f"/api/v1/admin/content/quiz/cloze/{cloze_id}",
                json={"sentence": "私は___を飲む。"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()
    assert "id" in data


@pytest.mark.asyncio
async def test_patch_conversation_updates_changed_fields_only(admin_client, reviewer_user):
    """EDIT-04: PATCH /conversation/{id} updates only sent fields."""
    from app.main import app

    conv_id = uuid.uuid4()
    conv = _make_conversation(conv_id=conv_id)

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=_scalar_result(conv))
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.patch(
                f"/api/v1/admin/content/conversation/{conv_id}",
                json={"title": "レストランで注文する"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()
    assert "id" in data


# ---------------------------------------------------------------------------
# REVIEW tests (POST /review endpoints)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_approve_sets_review_status_to_approved(admin_client, reviewer_user):
    """REVW-01: POST /vocabulary/{id}/review with action=approve."""
    from app.main import app

    vocab_id = uuid.uuid4()
    vocab = _make_vocab(vocab_id=vocab_id, review_status=ReviewStatus.NEEDS_REVIEW)

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=_scalar_result(vocab))
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.post(
                f"/api/v1/admin/content/vocabulary/{vocab_id}/review",
                json={"action": "approve"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()
    # review_status was set to APPROVED on the mock object via setattr
    assert data["reviewStatus"] == "approved"


@pytest.mark.asyncio
async def test_reject_without_reason_returns_422(admin_client, reviewer_user):
    """REVW-03: POST /vocabulary/{id}/review with action=reject but no reason."""
    from app.main import app

    vocab_id = uuid.uuid4()

    mock_db = AsyncMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.post(
                f"/api/v1/admin/content/vocabulary/{vocab_id}/review",
                json={"action": "reject"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# AUDIT LOG tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_audit_logs_table_exists(admin_client, reviewer_user):
    """REVW-04: Verify audit_logs table definition is accessible via ORM model."""
    from app.models.admin import AuditLog

    # Verify the AuditLog model is importable and has expected columns
    assert AuditLog.__tablename__ == "audit_logs"
    assert hasattr(AuditLog, "content_type")
    assert hasattr(AuditLog, "content_id")
    assert hasattr(AuditLog, "action")
    assert hasattr(AuditLog, "changes")
    assert hasattr(AuditLog, "reason")
    assert hasattr(AuditLog, "reviewer_id")
    assert hasattr(AuditLog, "created_at")


@pytest.mark.asyncio
async def test_review_action_writes_audit_log(admin_client, reviewer_user):
    """REVW-04: Review approve action creates audit_log entry."""
    from app.main import app
    from app.models.admin import AuditLog

    vocab_id = uuid.uuid4()
    vocab = _make_vocab(vocab_id=vocab_id, review_status=ReviewStatus.NEEDS_REVIEW)

    # Use a real AuditLog instance so model_validate works correctly
    mock_log = AuditLog(
        id=uuid.uuid4(),
        content_type="vocabulary",
        content_id=vocab_id,
        action="approve",
        changes=None,
        reason=None,
        reviewer_id=reviewer_user.id,
        created_at=datetime.now(UTC),
    )

    call_count = 0

    def execute_side_effect(stmt):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            # First call: fetch vocabulary for review endpoint
            return _scalar_result(vocab)
        else:
            # Second call: GET audit-logs
            return _audit_rows_result([mock_log])

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(side_effect=execute_side_effect)
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            # Approve
            review_resp = await ac.post(
                f"/api/v1/admin/content/vocabulary/{vocab_id}/review",
                json={"action": "approve"},
            )
            assert review_resp.status_code == 200

            # Check audit log was added to db
            mock_db.add.assert_called_once()
            added_audit = mock_db.add.call_args[0][0]
            from app.models.admin import AuditLog

            assert isinstance(added_audit, AuditLog)
            assert added_audit.action == "approve"
            assert str(added_audit.content_id) == str(vocab_id)

            # Fetch audit logs
            logs_resp = await ac.get(f"/api/v1/admin/content/vocabulary/{vocab_id}/audit-logs")
            assert logs_resp.status_code == 200
            logs = logs_resp.json()
            assert len(logs) >= 1
            assert logs[0]["action"] == "approve"
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_patch_action_writes_audit_log_with_changes(admin_client, reviewer_user):
    """REVW-04: PATCH creates audit_log with before/after changes JSON."""
    from app.main import app
    from app.models.admin import AuditLog

    vocab_id = uuid.uuid4()
    vocab = _make_vocab(vocab_id=vocab_id, word="食べる")

    # Use a real AuditLog instance so model_validate works correctly
    mock_log = AuditLog(
        id=uuid.uuid4(),
        content_type="vocabulary",
        content_id=vocab_id,
        action="edit",
        changes={"word": {"before": "食べる", "after": "飲む"}},
        reason=None,
        reviewer_id=reviewer_user.id,
        created_at=datetime.now(UTC),
    )

    call_count = 0

    def execute_side_effect(stmt):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return _scalar_result(vocab)
        else:
            return _audit_rows_result([mock_log])

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(side_effect=execute_side_effect)
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            # PATCH
            patch_resp = await ac.patch(
                f"/api/v1/admin/content/vocabulary/{vocab_id}",
                json={"word": "飲む"},
            )
            assert patch_resp.status_code == 200

            # Verify AuditLog was added with "edit" action and changes
            mock_db.add.assert_called_once()
            added_audit = mock_db.add.call_args[0][0]
            from app.models.admin import AuditLog

            assert isinstance(added_audit, AuditLog)
            assert added_audit.action == "edit"
            assert "word" in added_audit.changes

            # Fetch audit logs
            logs_resp = await ac.get(f"/api/v1/admin/content/vocabulary/{vocab_id}/audit-logs")
            assert logs_resp.status_code == 200
            logs = logs_resp.json()
            assert len(logs) >= 1
            assert logs[0]["action"] == "edit"
            assert "word" in logs[0]["changes"]
    finally:
        app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# BATCH tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_batch_review_approves_multiple_items(admin_client, reviewer_user):
    """REVW-02: POST /batch-review approves multiple items in one request."""
    from app.main import app

    ids = [uuid.uuid4(), uuid.uuid4(), uuid.uuid4()]
    vocabs = [_make_vocab(vocab_id=vid) for vid in ids]

    call_count = 0

    def execute_side_effect(stmt):
        nonlocal call_count
        result = _scalar_result(vocabs[call_count % len(vocabs)])
        call_count += 1
        return result

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(side_effect=execute_side_effect)
    mock_db.commit = AsyncMock()
    mock_db.add = MagicMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.post(
                "/api/v1/admin/content/batch-review",
                json={
                    "contentType": "vocabulary",
                    "ids": [str(i) for i in ids],
                    "action": "approve",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()
    assert data["ok"] is True
    assert data["count"] == 3


@pytest.mark.asyncio
async def test_batch_reject_without_reason_returns_422(admin_client, reviewer_user):
    """REVW-02: POST /batch-review with action=reject but no reason returns 422."""
    from app.main import app

    mock_db = AsyncMock()

    async def override_get_db():
        yield mock_db

    async def override_require_reviewer():
        return reviewer_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_reviewer] = override_require_reviewer

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.post(
                "/api/v1/admin/content/batch-review",
                json={
                    "contentType": "vocabulary",
                    "ids": [str(uuid.uuid4())],
                    "action": "reject",
                },
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422
