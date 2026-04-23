from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

import pytest

from app.models.user import User
from app.services.auth_identity import (
    InvalidSubjectClaimError,
    MissingSubjectClaimError,
    get_user_by_id,
    payload_has_reviewer_role,
    required_user_id_from_payload,
)


def test_required_user_id_from_payload_returns_uuid() -> None:
    user_id = uuid.uuid4()

    assert required_user_id_from_payload({"sub": str(user_id)}) == user_id


def test_required_user_id_from_payload_rejects_missing_subject() -> None:
    with pytest.raises(MissingSubjectClaimError):
        required_user_id_from_payload({})


def test_required_user_id_from_payload_rejects_invalid_subject() -> None:
    with pytest.raises(InvalidSubjectClaimError):
        required_user_id_from_payload({"sub": "not-a-uuid"})


@pytest.mark.parametrize(
    ("payload", "expected"),
    [
        ({"app_metadata": {"reviewer": True}}, True),
        ({"app_metadata": {"reviewer": False}}, False),
        ({"app_metadata": {}}, False),
        ({"app_metadata": []}, False),
        ({}, False),
    ],
)
def test_payload_has_reviewer_role(payload: dict[str, Any], expected: bool) -> None:
    assert payload_has_reviewer_role(payload) is expected


@pytest.mark.asyncio
async def test_get_user_by_id_returns_matching_user() -> None:
    user_id = uuid.UUID("00000000-0000-0000-0000-000000000099")
    user = _make_user(user_id)
    db = _FakeDb(_ScalarOneOrNoneResult(user))

    result = await get_user_by_id(db, user_id)  # type: ignore[arg-type]

    assert result is user
    assert db.execute_calls == 1


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
    def __init__(self, result: Any) -> None:
        self._result = result
        self.execute_calls = 0

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        return self._result


class _ScalarOneOrNoneResult:
    def __init__(self, value: Any) -> None:
        self._value = value

    def scalar_one_or_none(self) -> Any:
        return self._value
