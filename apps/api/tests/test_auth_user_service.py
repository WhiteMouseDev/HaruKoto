from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.enums import JlptLevel, UserGoal
from app.models.user import User
from app.schemas.auth import OnboardingRequest
from app.services.auth_user import complete_onboarding_profile, get_or_create_user_profile


class _DbResult:
    def __init__(self, user: User | None) -> None:
        self._user = user

    def scalar_one_or_none(self) -> User | None:
        return self._user


def _user(
    *,
    user_id: uuid.UUID | None = None,
    email: str = "test@example.com",
    jlpt_level: JlptLevel = JlptLevel.N5,
    show_kana: bool = False,
) -> User:
    return User(
        id=user_id or uuid.UUID("00000000-0000-0000-0000-000000000001"),
        email=email,
        nickname="테스터",
        jlpt_level=jlpt_level,
        daily_goal=10,
        experience_points=120,
        level=2,
        streak_count=3,
        longest_streak=5,
        is_premium=False,
        show_kana=show_kana,
        onboarding_completed=False,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )


def _hydrate_created_user(user: User) -> None:
    user.nickname = None
    user.jlpt_level = JlptLevel.N5
    user.goal = None
    user.goals = None
    user.daily_goal = 10
    user.experience_points = 0
    user.level = 1
    user.streak_count = 0
    user.longest_streak = 0
    user.is_premium = False
    user.show_kana = False
    user.onboarding_completed = False
    user.call_settings = None
    user.app_settings = None
    user.created_at = datetime.now(UTC)
    user.updated_at = datetime.now(UTC)


@pytest.mark.asyncio
async def test_get_or_create_user_profile_returns_existing_user_profile() -> None:
    existing_user = _user()
    db = SimpleNamespace(
        execute=AsyncMock(return_value=_DbResult(existing_user)),
        add=MagicMock(),
        commit=AsyncMock(),
        refresh=AsyncMock(),
    )

    profile = await get_or_create_user_profile(
        db,
        user_id=existing_user.id,
        email=existing_user.email,
    )

    assert profile.id == existing_user.id
    assert profile.email == "test@example.com"
    assert profile.level_progress is not None
    assert profile.level_progress.current_xp == 20
    db.add.assert_not_called()
    db.commit.assert_not_awaited()
    db.refresh.assert_not_awaited()


@pytest.mark.asyncio
async def test_get_or_create_user_profile_creates_missing_user() -> None:
    user_id = uuid.UUID("11111111-1111-1111-1111-111111111111")

    async def refresh_user(user: User) -> None:
        _hydrate_created_user(user)

    db = SimpleNamespace(
        execute=AsyncMock(return_value=_DbResult(None)),
        add=MagicMock(),
        commit=AsyncMock(),
        refresh=AsyncMock(side_effect=refresh_user),
    )

    profile = await get_or_create_user_profile(
        db,
        user_id=user_id,
        email="new@example.com",
    )

    added_user = db.add.call_args.args[0]
    assert isinstance(added_user, User)
    assert added_user.id == user_id
    assert added_user.email == "new@example.com"
    assert profile.id == user_id
    assert profile.email == "new@example.com"
    db.commit.assert_awaited_once()
    db.refresh.assert_awaited_once_with(added_user)


@pytest.mark.asyncio
async def test_complete_onboarding_profile_updates_user_and_truncates_goals() -> None:
    user = _user()
    db = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())
    body = OnboardingRequest(
        nickname="하루학생",
        jlpt_level=JlptLevel.N4,
        daily_goal=15,
        goal=UserGoal.JLPT_N3,
        goals=["TRAVEL", "JLPT", "WORK", "HOBBY"],
        show_kana=False,
    )

    profile = await complete_onboarding_profile(db, user, body)

    assert user.nickname == "하루학생"
    assert user.jlpt_level == JlptLevel.N4
    assert user.daily_goal == 15
    assert user.goal == UserGoal.JLPT_N3
    assert user.goals == ["TRAVEL", "JLPT", "WORK"]
    assert user.show_kana is False
    assert user.onboarding_completed is True
    assert profile.nickname == "하루학생"
    assert profile.daily_goal == 15
    db.commit.assert_awaited_once()
    db.refresh.assert_awaited_once_with(user)


@pytest.mark.asyncio
async def test_complete_onboarding_profile_forces_kana_for_absolute_zero() -> None:
    user = _user(show_kana=False)
    db = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())
    body = OnboardingRequest(
        nickname="처음학습자",
        jlpt_level=JlptLevel.ABSOLUTE_ZERO,
        daily_goal=10,
        show_kana=False,
    )

    profile = await complete_onboarding_profile(db, user, body)

    assert user.show_kana is True
    assert profile.show_kana is True
