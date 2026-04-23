from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.quiz_stats_query import ContentQuizStatsResult, QuizStatsResult, get_quiz_stats_data


class _ScalarResult:
    def __init__(self, value: object) -> None:
        self._value = value

    def scalar(self) -> object:
        return self._value


class _OneResult:
    def __init__(self, row: tuple[object, object]) -> None:
        self._row = row

    def one(self) -> tuple[object, object]:
        return self._row


def _user() -> SimpleNamespace:
    return SimpleNamespace(id=uuid.UUID("00000000-0000-0000-0000-000000000001"))


@pytest.mark.asyncio
async def test_get_quiz_stats_data_returns_vocabulary_content_progress() -> None:
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _ScalarResult(12),
                _ScalarResult(5),
            ]
        )
    )

    result = await get_quiz_stats_data(
        db,
        _user(),
        level="N5",
        quiz_type="VOCABULARY",
    )

    assert isinstance(result, ContentQuizStatsResult)
    assert result.total_count == 12
    assert result.studied_count == 5
    assert result.progress == 42


@pytest.mark.asyncio
async def test_get_quiz_stats_data_returns_zero_progress_for_empty_grammar_content() -> None:
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _ScalarResult(0),
                _ScalarResult(3),
            ]
        )
    )

    result = await get_quiz_stats_data(
        db,
        _user(),
        level="N4",
        quiz_type="GRAMMAR",
    )

    assert isinstance(result, ContentQuizStatsResult)
    assert result.total_count == 0
    assert result.studied_count == 3
    assert result.progress == 0


@pytest.mark.asyncio
async def test_get_quiz_stats_data_returns_overall_completed_session_stats() -> None:
    db = SimpleNamespace(
        execute=AsyncMock(
            side_effect=[
                _ScalarResult(4),
                _OneResult((9, 12)),
            ]
        )
    )

    result = await get_quiz_stats_data(
        db,
        _user(),
        level=None,
        quiz_type=None,
    )

    assert isinstance(result, QuizStatsResult)
    assert result.total_quizzes == 4
    assert result.total_correct == 9
    assert result.total_questions == 12
    assert result.accuracy == 75
