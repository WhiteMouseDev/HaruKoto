import logging
import time
from collections.abc import Awaitable
from dataclasses import dataclass
from typing import cast

import redis.asyncio as redis

from app.config import settings

logger = logging.getLogger(__name__)

_redis_client: redis.Redis | None = None


async def _get_redis() -> redis.Redis | None:
    global _redis_client
    if _redis_client is None:
        try:
            _redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
            await cast(Awaitable[bool], _redis_client.ping())
        except Exception:
            logger.warning("Redis unavailable, rate limiting disabled")
            _redis_client = None
    return _redis_client


@dataclass
class RateLimitResult:
    success: bool
    remaining: int
    reset: float


async def rate_limit(key: str, max_requests: int, window_seconds: int) -> RateLimitResult:
    client = await _get_redis()
    if client is None:
        return RateLimitResult(success=True, remaining=max_requests, reset=0)

    now = time.time()
    window_start = now - window_seconds

    try:
        pipe = client.pipeline()
        pipe.zremrangebyscore(key, 0, window_start)
        pipe.zadd(key, {str(now): now})
        pipe.zcard(key)
        pipe.expire(key, window_seconds)
        results = await pipe.execute()

        current_count: int = results[2]
        remaining = max(0, max_requests - current_count)
        reset = now + window_seconds

        if current_count > max_requests:
            await client.zrem(key, str(now))
            return RateLimitResult(success=False, remaining=0, reset=reset)

        return RateLimitResult(success=True, remaining=remaining, reset=reset)
    except Exception:
        logger.warning("Redis error during rate limiting, allowing request")
        return RateLimitResult(success=True, remaining=max_requests, reset=0)
