from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.services.ai_client import create_google_live_token_client

_LIVE_WS_URI = (
    "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContentConstrained"
)
_LIVE_MODEL = "models/gemini-2.5-flash-native-audio-preview-12-2025"


async def generate_live_token() -> dict[str, str]:
    """Generate an ephemeral token for the Gemini Live API."""
    alpha_client = create_google_live_token_client()

    expire_time = datetime.now(UTC) + timedelta(minutes=5)
    new_session_expire_time = datetime.now(UTC) + timedelta(minutes=1)

    token_response = alpha_client.auth_tokens.create(
        config={
            "uses": 5,
            "expire_time": expire_time.isoformat(),
            "new_session_expire_time": new_session_expire_time.isoformat(),
            "http_options": {"api_version": "v1alpha"},
        },
    )

    return {
        "token": token_response.name or "",
        "wsUri": _LIVE_WS_URI,
        "model": _LIVE_MODEL,
    }
