from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.enums import KanaType
from app.schemas.kana import KanaStageCompleteRequest
from app.services import kana_stage_complete
from app.services.kana_stage_complete import (
    KanaCompletionStatus,
    KanaStageCompleteServiceError,
    complete_kana_stage,
    is_kana_type_complete,
)
from app.utils.constants import KANA_REWARDS


def test_is_kana_type_complete_requires_positive_total():
    assert is_kana_type_complete(mastered_count=0, total_count=0) is False
    assert is_kana_type_complete(mastered_count=5, total_count=5) is True
    assert is_kana_type_complete(mastered_count=4, total_count=5) is False


def test_kana_completion_status_reports_all_complete():
    status = KanaCompletionStatus(
        hiragana_total=46,
        hiragana_mastered=46,
        katakana_total=46,
        katakana_mastered=46,
    )

    assert status.hiragana_complete is True
    assert status.katakana_complete is True
    assert status.all_complete is True


@pytest.mark.asyncio
async def test_complete_kana_stage_unlocks_next_stage_and_disables_show_kana(monkeypatch):
    user = SimpleNamespace(
        id=uuid.uuid4(),
        level=1,
        experience_points=70,
        last_study_date=None,
        streak_count=0,
        longest_streak=0,
        show_kana=True,
    )
    stage = SimpleNamespace(id=uuid.uuid4(), kana_type=KanaType.HIRAGANA, stage_number=1)
    next_stage = SimpleNamespace(id=uuid.uuid4())
    next_stage_result = MagicMock()
    next_stage_result.scalar_one_or_none.return_value = next_stage
    totals_result = MagicMock()
    totals_result.all.return_value = [(KanaType.HIRAGANA, 46), (KanaType.KATAKANA, 46)]
    mastered_result = MagicMock()
    mastered_result.all.return_value = [(KanaType.HIRAGANA, 46), (KanaType.KATAKANA, 46)]
    db = AsyncMock()
    db.get = AsyncMock(return_value=stage)
    db.execute = AsyncMock(
        side_effect=[
            MagicMock(),
            next_stage_result,
            MagicMock(),
            MagicMock(),
            totals_result,
            mastered_result,
        ]
    )
    db.commit = AsyncMock()
    achievement_context: dict[str, object] = {}

    async def fake_check_and_grant_achievements(db_arg, user_id, context):
        achievement_context.update(context)
        return [{"type": "achievement"}]

    monkeypatch.setattr(kana_stage_complete, "get_today_kst", lambda: date(2026, 4, 21))
    monkeypatch.setattr(kana_stage_complete, "check_and_grant_achievements", fake_check_and_grant_achievements)

    result = await complete_kana_stage(
        db,
        user,
        KanaStageCompleteRequest(stage_id=stage.id, quiz_score=90),
    )

    assert result.success is True
    assert result.xp_earned == KANA_REWARDS.STAGE_COMPLETE_XP
    assert result.level == 2
    assert result.events == [{"type": "achievement"}]
    assert result.next_stage_unlocked is True
    assert user.experience_points == 100
    assert user.level == 2
    assert user.streak_count == 1
    assert user.longest_streak == 1
    assert user.show_kana is False
    assert achievement_context == {
        "total_xp": 100,
        "new_level": 2,
        "old_level": 1,
        "streak_count": 1,
        "kana_first_char": True,
        "kana_hiragana_complete": True,
        "kana_katakana_complete": True,
    }
    assert db.execute.await_count == 6
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_complete_kana_stage_keeps_next_stage_locked_when_none(monkeypatch):
    user = SimpleNamespace(
        id=uuid.uuid4(),
        level=1,
        experience_points=0,
        last_study_date=None,
        streak_count=0,
        longest_streak=0,
        show_kana=True,
    )
    stage = SimpleNamespace(id=uuid.uuid4(), kana_type=KanaType.KATAKANA, stage_number=10)
    next_stage_result = MagicMock()
    next_stage_result.scalar_one_or_none.return_value = None
    totals_result = MagicMock()
    totals_result.all.return_value = [(KanaType.HIRAGANA, 46), (KanaType.KATAKANA, 46)]
    mastered_result = MagicMock()
    mastered_result.all.return_value = [(KanaType.HIRAGANA, 46), (KanaType.KATAKANA, 45)]
    db = AsyncMock()
    db.get = AsyncMock(return_value=stage)
    db.execute = AsyncMock(
        side_effect=[
            MagicMock(),
            next_stage_result,
            MagicMock(),
            totals_result,
            mastered_result,
        ]
    )
    db.commit = AsyncMock()

    async def fake_check_and_grant_achievements(db_arg, user_id, context):
        return []

    monkeypatch.setattr(kana_stage_complete, "get_today_kst", lambda: date(2026, 4, 21))
    monkeypatch.setattr(kana_stage_complete, "check_and_grant_achievements", fake_check_and_grant_achievements)

    result = await complete_kana_stage(
        db,
        user,
        KanaStageCompleteRequest(stage_id=stage.id, quiz_score=None),
    )

    assert result.next_stage_unlocked is False
    assert user.show_kana is True
    assert db.execute.await_count == 5


@pytest.mark.asyncio
async def test_complete_kana_stage_rejects_missing_stage():
    user = SimpleNamespace(id=uuid.uuid4())
    db = AsyncMock()
    db.get = AsyncMock(return_value=None)

    with pytest.raises(KanaStageCompleteServiceError) as exc_info:
        await complete_kana_stage(
            db,
            user,
            KanaStageCompleteRequest(stage_id=uuid.uuid4(), quiz_score=90),
        )

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "스테이지를 찾을 수 없습니다"
