from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app import dependencies
from app.dependencies import require_reviewer
from app.models.user import User


@pytest.mark.asyncio
async def test_require_reviewer_returns_user_when_token_has_reviewer_flag(monkeypatch: pytest.MonkeyPatch) -> None:
    user_id = uuid.UUID("00000000-0000-0000-0000-000000000099")
    user = _make_user(user_id)
    db = _FakeDb([_ScalarOneOrNoneResult(user)])

    monkeypatch.setattr(
        dependencies,
        "_decode_token",
        lambda token: {"sub": str(user_id), "app_metadata": {"reviewer": True}},
    )

    result = await require_reviewer(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials="token"),
        db,  # type: ignore[arg-type]
    )

    assert result is user
    assert db.execute_calls == 1


@pytest.mark.asyncio
async def test_require_reviewer_rejects_token_without_reviewer_flag(monkeypatch: pytest.MonkeyPatch) -> None:
    db = _FakeDb([])

    monkeypatch.setattr(
        dependencies,
        "_decode_token",
        lambda token: {"sub": str(uuid.uuid4()), "app_metadata": {"reviewer": False}},
    )

    with pytest.raises(HTTPException) as exc_info:
        await require_reviewer(
            HTTPAuthorizationCredentials(scheme="Bearer", credentials="token"),
            db,  # type: ignore[arg-type]
        )

    assert exc_info.value.status_code == 403
    assert exc_info.value.detail == "Reviewer role required"
    assert db.execute_calls == 0


@pytest.mark.asyncio
async def test_require_reviewer_rejects_invalid_subject_claim(monkeypatch: pytest.MonkeyPatch) -> None:
    db = _FakeDb([])

    monkeypatch.setattr(
        dependencies,
        "_decode_token",
        lambda token: {"sub": "not-a-uuid", "app_metadata": {"reviewer": True}},
    )

    with pytest.raises(HTTPException) as exc_info:
        await require_reviewer(
            HTTPAuthorizationCredentials(scheme="Bearer", credentials="token"),
            db,  # type: ignore[arg-type]
        )

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "Invalid subject claim"
    assert db.execute_calls == 0


def _make_user(user_id: uuid.UUID) -> User:
    now = datetime.now(UTC)
    return User(
        id=user_id,
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
        created_at=now,
        updated_at=now,
    )


class _FakeDb:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.execute_calls = 0

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)


class _ScalarOneOrNoneResult:
    def __init__(self, value: Any) -> None:
        self._value = value

    def scalar_one_or_none(self) -> Any:
        return self._value
