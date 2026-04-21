from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.subscription_ai_usage import check_ai_limit, get_daily_ai_usage


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
        "call_count": 19,
        "call_seconds": 599,
    }

    result = await check_ai_limit(MagicMock(), MagicMock(), "call")

    assert result == {"allowed": True}
