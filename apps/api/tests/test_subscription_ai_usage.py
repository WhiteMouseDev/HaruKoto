from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID

import pytest
from sqlalchemy.dialects import postgresql

from app.services.subscription_ai_usage import build_ai_usage_tracking_statement, check_ai_limit, get_daily_ai_usage


@pytest.mark.asyncio
async def test_get_daily_ai_usage_returns_zeroes_when_no_usage():
    db = MagicMock()
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    db.execute = AsyncMock(return_value=result)

    usage = await get_daily_ai_usage(db, MagicMock())

    assert usage == {
        "chat_count": 0,
        "chat_seconds": 0,
        "call_count": 0,
        "call_seconds": 0,
    }


@pytest.mark.asyncio
@patch("app.services.subscription_ai_usage.get_daily_ai_usage")
@patch("app.services.subscription_ai_usage.get_subscription_status")
async def test_check_ai_limit_blocks_free_chat_count(mock_get_status, mock_get_usage):
    mock_get_status.return_value = {"is_premium": False}
    mock_get_usage.return_value = {
        "chat_count": 3,
        "chat_seconds": 0,
        "call_count": 0,
        "call_seconds": 0,
    }

    result = await check_ai_limit(MagicMock(), MagicMock(), "chat")

    assert result == {"allowed": False, "reason": "오늘의 AI 채팅 횟수를 초과했습니다."}


@pytest.mark.asyncio
@patch("app.services.subscription_ai_usage.get_daily_ai_usage")
@patch("app.services.subscription_ai_usage.get_subscription_status")
async def test_check_ai_limit_allows_premium_call_under_limit(mock_get_status, mock_get_usage):
    mock_get_status.return_value = {"is_premium": True}
    mock_get_usage.return_value = {
        "chat_count": 50,
        "chat_seconds": 600,
        "call_count": 299,
        "call_seconds": 7199,
    }

    result = await check_ai_limit(MagicMock(), MagicMock(), "call")

    assert result == {"allowed": True}


@pytest.mark.asyncio
@patch("app.services.subscription_ai_usage.get_daily_ai_usage")
@patch("app.services.subscription_ai_usage.get_subscription_status")
async def test_check_ai_limit_blocks_call_seconds_before_call_count(mock_get_status, mock_get_usage):
    mock_get_status.return_value = {"is_premium": False}
    mock_get_usage.return_value = {
        "chat_count": 0,
        "chat_seconds": 0,
        "call_count": 30,
        "call_seconds": 900,
    }

    result = await check_ai_limit(MagicMock(), MagicMock(), "call")

    assert result == {"allowed": False, "reason": "오늘의 AI 통화 시간을 초과했습니다."}


def test_build_ai_usage_tracking_statement_sets_all_non_null_insert_columns():
    stmt = build_ai_usage_tracking_statement(
        user_id=UUID("00000000-0000-0000-0000-000000000001"),
        today=date(2026, 4, 24),
        usage_type="call",
        duration_seconds=120,
    )

    params = stmt.compile(dialect=postgresql.dialect()).params

    assert params["id"] is not None
    assert params["chat_count"] == 0
    assert params["chat_seconds"] == 0
    assert params["call_count"] == 1
    assert params["call_seconds"] == 120
    assert params["created_at"] is not None
    assert params["updated_at"] is not None
