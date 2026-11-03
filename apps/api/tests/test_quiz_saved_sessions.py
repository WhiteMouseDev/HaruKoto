from __future__ import annotations

import base64
import json
import uuid
from datetime import UTC, datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from sqlalchemy.dialects import postgresql

from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_saved_sessions import _cursor, _read_cursor, saved_sessions_query, utc_instant


@pytest.mark.parametrize(
    "raw",
    [
        [],
        {},
        [1, "bad", "bad", None, None],
        [True, "2026-11-03T00:00:00Z", str(uuid.uuid4()), None, None],
        [1, "2026-11-03T00:00:00Z", 12, None, None],
        [1, "2026-11-03T00:00:00", str(uuid.uuid4()), None, None],
    ],
)
def test_malformed_cursor_returns_safe_client_error(raw):
    value = base64.urlsafe_b64encode(json.dumps(raw).encode()).decode()
    with pytest.raises(QuizQueryServiceError) as error:
        _read_cursor(value, None, None)
    assert error.value.status_code == 400


@pytest.mark.parametrize(
    "stored",
    [datetime(2026, 11, 3, 1), datetime(2026, 11, 3, 1, tzinfo=UTC), datetime(2026, 11, 3, 10, tzinfo=timezone(timedelta(hours=9)))],
)
def test_cursor_uses_utc_and_rejects_changed_filters(stored):
    session = SimpleNamespace(id=uuid.uuid4(), started_at=stored)
    cursor = _cursor(session, "VOCABULARY", "N5")
    assert _read_cursor(cursor, "VOCABULARY", "N5") == (datetime(2026, 11, 3, 1, tzinfo=UTC), session.id)
    assert utc_instant(stored) == datetime(2026, 11, 3, 1, tzinfo=UTC)
    with pytest.raises(QuizQueryServiceError):
        _read_cursor(cursor, "VOCABULARY", "N4")


def test_saved_query_excludes_empty_kana_foreign_and_completed_before_limit():
    user_id = uuid.uuid4()
    query = saved_sessions_query(user_id).limit(21)
    compiled = query.compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True})
    sql = str(compiled)
    assert str(user_id) in sql
    assert "completed_at IS NULL" in sql
    assert "quiz_type != 'KANA'" in sql
    assert "EXISTS (SELECT quiz_answers.id" in sql
    assert sql.index("EXISTS") < sql.index("LIMIT")
    assert "quiz_sessions.started_at DESC, quiz_sessions.id DESC" in sql
