from __future__ import annotations

import logging
import time
from typing import Any

import jwt
from jwt import PyJWKClient, PyJWKClientError

from app.config import settings

logger = logging.getLogger(__name__)

_jwks_client: PyJWKClient | None = None
_jwks_cache_time: float = 0
_JWKS_CACHE_TTL = 3600


def get_jwks_client() -> PyJWKClient:
    """Return a cached Supabase JWKS client, refreshing it after the TTL."""
    global _jwks_client, _jwks_cache_time  # noqa: PLW0603

    now = time.time()
    if _jwks_client is None or (now - _jwks_cache_time) > _JWKS_CACHE_TTL:
        _jwks_client = PyJWKClient(settings.supabase_jwks_url)
        _jwks_cache_time = now
        logger.info("JWKS client initialized from %s", settings.supabase_jwks_url)

    return _jwks_client


def decode_supabase_token(token: str) -> dict[str, Any]:
    """Verify Supabase JWT. Prefer JWKS/ES256 and fall back to legacy HS256 when configured."""
    if settings.SUPABASE_URL:
        try:
            client = get_jwks_client()
            signing_key = client.get_signing_key_from_jwt(token)
            return jwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256"],
                audience="authenticated",
            )
        except (jwt.InvalidTokenError, jwt.ExpiredSignatureError, jwt.DecodeError, jwt.InvalidKeyError, PyJWKClientError) as exc:
            logger.debug("JWKS verification failed (%s), trying HS256 fallback", type(exc).__name__)

    if settings.SUPABASE_JWT_SECRET:
        return jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )

    raise jwt.InvalidTokenError("No JWT verification method configured")
