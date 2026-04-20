from __future__ import annotations

import logging

from google import genai

from app.config import settings

logger = logging.getLogger(__name__)

_client: genai.Client | None = None

if settings.GOOGLE_API_KEY:
    _client = genai.Client(api_key=settings.GOOGLE_API_KEY)
else:
    logger.warning("GOOGLE_API_KEY is not set - AI features will be unavailable")


def ensure_google_client() -> genai.Client:
    if _client is None:
        raise RuntimeError("Google AI SDK is not configured. Set GOOGLE_API_KEY in environment.")
    return _client


def create_google_live_token_client() -> genai.Client:
    ensure_google_client()
    return genai.Client(
        api_key=settings.GOOGLE_API_KEY,
        http_options={"api_version": "v1alpha"},
    )
