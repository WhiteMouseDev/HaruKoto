from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services import ai, ai_speech
from app.services.ai_json import parse_json_response
from app.services.ai_live import generate_live_token


def test_parse_json_response_strips_markdown_fence():
    result = parse_json_response('```json\n{"messageJa": "こんにちは", "hint": "挨拶"}\n```')

    assert result == {"messageJa": "こんにちは", "hint": "挨拶"}


def test_parse_json_response_returns_chat_fallback_for_plain_text():
    result = parse_json_response("こんにちは")

    assert result == {
        "messageJa": "こんにちは",
        "messageKo": "",
        "feedback": [],
        "hint": "",
        "newVocabulary": [],
    }


@pytest.mark.asyncio
async def test_generate_tts_prefers_elevenlabs_when_configured(monkeypatch):
    monkeypatch.setattr(ai_speech.settings, "ELEVENLABS_API_KEY", "test-key")
    monkeypatch.setattr(ai_speech.settings, "ELEVENLABS_VOICE_ID", "voice-id")
    monkeypatch.setattr(ai_speech.settings, "ELEVENLABS_MODEL_ID", "eleven-model")

    with (
        patch("app.services.ai_speech._generate_tts_elevenlabs", return_value=b"eleven-audio") as elevenlabs,
        patch("app.services.ai_speech._generate_tts_gemini", new_callable=AsyncMock) as gemini,
    ):
        result = await ai_speech.generate_tts("こんにちは")

    assert result.audio == b"eleven-audio"
    assert result.provider == "elevenlabs"
    assert result.model == "eleven-model"
    elevenlabs.assert_called_once_with("こんにちは")
    gemini.assert_not_awaited()


@pytest.mark.asyncio
async def test_generate_tts_falls_back_to_gemini_when_elevenlabs_fails(monkeypatch):
    monkeypatch.setattr(ai_speech.settings, "ELEVENLABS_API_KEY", "test-key")
    monkeypatch.setattr(ai_speech.settings, "ELEVENLABS_VOICE_ID", "voice-id")

    with (
        patch("app.services.ai_speech._generate_tts_elevenlabs", side_effect=RuntimeError("provider down")),
        patch("app.services.ai_speech._generate_tts_gemini", new_callable=AsyncMock, return_value=b"gemini-audio") as gemini,
    ):
        result = await ai_speech.generate_tts("こんにちは", voice="Aoede")

    assert result.audio == b"gemini-audio"
    assert result.provider == "gemini"
    assert result.model == "gemini-2.5-flash-preview-tts"
    gemini.assert_awaited_once_with("こんにちは", voice="Aoede")


@pytest.mark.asyncio
async def test_generate_tts_gemini_wraps_transcript_in_audio_only_instruction():
    fake_client = MagicMock()
    fake_client.aio.models.generate_content = AsyncMock(
        return_value=SimpleNamespace(
            candidates=[SimpleNamespace(content=SimpleNamespace(parts=[SimpleNamespace(inline_data=SimpleNamespace(data=b"pcm-audio"))]))]
        )
    )

    with (
        patch("app.services.ai_speech.ensure_google_client", return_value=fake_client),
        patch("app.services.ai_speech._pcm_to_mp3", return_value=b"mp3-audio"),
    ):
        result = await ai_speech._generate_tts_gemini("空欄に入る表現は何ですか？", voice="Aoede", _max_retries=1)

    assert result == b"mp3-audio"
    call_kwargs = fake_client.aio.models.generate_content.await_args.kwargs
    assert call_kwargs["model"] == "gemini-2.5-flash-preview-tts"
    assert call_kwargs["contents"] != "空欄に入る表現は何ですか？"
    assert "Read aloud the transcript below exactly as written." in call_kwargs["contents"]
    assert "Do not answer, translate, explain, fill blanks" in call_kwargs["contents"]
    assert "Transcript:\n空欄に入る表現は何ですか？" in call_kwargs["contents"]


@pytest.mark.asyncio
async def test_generate_live_token_uses_live_token_client():
    fake_client = MagicMock()
    token_response = MagicMock()
    token_response.name = "live-token"
    fake_client.auth_tokens.create.return_value = token_response

    with patch("app.services.ai_live.create_google_live_token_client", return_value=fake_client):
        result = await generate_live_token()

    assert result == {
        "token": "live-token",
        "wsUri": "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContentConstrained",
        "model": "models/gemini-3.1-flash-live-preview",
    }
    fake_client.auth_tokens.create.assert_called_once()
    assert fake_client.auth_tokens.create.call_args.kwargs["config"]["uses"] == 5


def test_ai_facade_keeps_public_import_surface():
    assert ai.generate_tts is ai_speech.generate_tts
    assert "generate_tts" in ai.__all__
    assert "generate_live_token" in ai.__all__
