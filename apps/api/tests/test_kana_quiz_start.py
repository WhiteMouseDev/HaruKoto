from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models.enums import JlptLevel, KanaType
from app.schemas.kana import KanaQuizStartRequest
from app.services import kana_quiz_questions
from app.services.kana_quiz_start import (
    KanaQuizStartServiceError,
    build_stage_window,
    collect_stage_characters,
    start_kana_quiz_session,
)


def _result(rows):
    result = MagicMock()
    result.scalars.return_value.all.return_value = rows
    return result


def test_build_stage_window_clamps_to_first_stage():
    assert build_stage_window(1) == [1]
    assert build_stage_window(2) == [1, 2]
    assert build_stage_window(5) == [3, 4, 5]


def test_collect_stage_characters_preserves_stage_order():
    stages = [
        SimpleNamespace(characters=["あ", "い"]),
        SimpleNamespace(characters=["う"]),
    ]

    assert collect_stage_characters(stages) == ["あ", "い", "う"]


@pytest.mark.asyncio
async def test_start_kana_quiz_session_creates_stage_quiz(monkeypatch):
    monkeypatch.setattr(kana_quiz_questions.random, "shuffle", lambda items: None)
    user = SimpleNamespace(id=uuid.uuid4(), jlpt_level=JlptLevel.N5)
    session_id = uuid.uuid4()
    chars = [
        SimpleNamespace(id=uuid.uuid4(), character="あ", romaji="a"),
        SimpleNamespace(id=uuid.uuid4(), character="い", romaji="i"),
    ]
    db = AsyncMock()
    db.execute = AsyncMock(
        side_effect=[
            _result([SimpleNamespace(characters=["あ", "い"])]),
            _result(chars),
        ]
    )
    db.add = MagicMock()
    db.commit = AsyncMock()

    async def refresh_session(session):
        session.id = session_id

    db.refresh = refresh_session

    result = await start_kana_quiz_session(
        db,
        user,
        KanaQuizStartRequest(
            kana_type=KanaType.HIRAGANA,
            stage_number=1,
            quiz_mode="recognition",
            count=2,
        ),
    )

    assert result.session_id == session_id
    assert result.total_questions == 2
    assert result.questions[0]["question"] == "あ"
    assert "correctOptionId" not in result.questions[0]
    db.add.assert_called_once()
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_start_kana_quiz_session_creates_master_quiz(monkeypatch):
    monkeypatch.setattr(kana_quiz_questions.random, "shuffle", lambda items: None)
    user = SimpleNamespace(id=uuid.uuid4(), jlpt_level=JlptLevel.N5)
    session_id = uuid.uuid4()
    chars = [
        SimpleNamespace(id=uuid.uuid4(), character="ア", romaji="a"),
    ]
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_result(chars))
    db.add = MagicMock()
    db.commit = AsyncMock()

    async def refresh_session(session):
        session.id = session_id

    db.refresh = refresh_session

    result = await start_kana_quiz_session(
        db,
        user,
        KanaQuizStartRequest(
            kana_type=KanaType.KATAKANA,
            stage_number=None,
            quiz_mode="recognition",
            count=10,
        ),
    )

    assert result.session_id == session_id
    assert result.total_questions == 1
    assert db.execute.await_count == 1


@pytest.mark.asyncio
async def test_start_kana_quiz_session_rejects_empty_character_pool():
    user = SimpleNamespace(id=uuid.uuid4(), jlpt_level=JlptLevel.N5)
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_result([]))

    with pytest.raises(KanaQuizStartServiceError) as exc_info:
        await start_kana_quiz_session(
            db,
            user,
            KanaQuizStartRequest(
                kana_type=KanaType.HIRAGANA,
                stage_number=None,
                quiz_mode="recognition",
                count=10,
            ),
        )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "가나 문자를 찾을 수 없습니다"
