from __future__ import annotations

import uuid

import jwt
import pytest

from app.config import settings
from app.services.auth_token import decode_supabase_token


def test_decode_supabase_token_uses_legacy_hs256_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    user_id = uuid.uuid4()
    secret = "test-secret-with-at-least-32-bytes"
    monkeypatch.setattr(settings, "SUPABASE_URL", "")
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", secret)
    token = jwt.encode(
        {"sub": str(user_id), "aud": "authenticated"},
        secret,
        algorithm="HS256",
    )

    payload = decode_supabase_token(token)

    assert payload["sub"] == str(user_id)


def test_decode_supabase_token_rejects_when_no_verification_method_configured(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "SUPABASE_URL", "")
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", "")

    with pytest.raises(jwt.InvalidTokenError):
        decode_supabase_token("token")
