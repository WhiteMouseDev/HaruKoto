from __future__ import annotations

import json
from dataclasses import replace
from unittest.mock import MagicMock, patch

import pytest
from httpx import Client, MockTransport, Request, Response

from app.config import Settings
from app.services import ai_speech, lesson_voice_tts


@pytest.fixture(autouse=True)
def configured_voices(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_API_KEY", "test-api-key")
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_MODEL_ID", "eleven_multilingual_v2")
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_VOICE_ID", "legacy-default")
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_FEMALE_VOICE_ID", "female-voice")
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_MALE_VOICE_ID", "male-voice")


def test_settings_keep_lesson_voices_optional() -> None:
    config = Settings(_env_file=None, DATABASE_URL="postgresql+asyncpg://test:test@localhost/test")
    assert config.ELEVENLABS_LESSON_FEMALE_VOICE_ID == ""
    assert config.ELEVENLABS_LESSON_MALE_VOICE_ID == ""


@pytest.mark.parametrize(
    ("female", "male", "enabled"),
    [("", "", False), ("  ", " ", False), ("female", "", True), ("", "male", True), ("female", "male", True)],
)
def test_activation_detects_partial_settings(monkeypatch: pytest.MonkeyPatch, female: str, male: str, enabled: bool) -> None:
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_FEMALE_VOICE_ID", female)
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_MALE_VOICE_ID", male)
    assert lesson_voice_tts.lesson_voice_routing_enabled() is enabled


@pytest.mark.parametrize(("alias", "voice_id"), [("japanese_female_1", "female-voice"), ("japanese_male_1", "male-voice")])
def test_profile_resolves_role_and_exact_short_text_request(alias: str, voice_id: str) -> None:
    profile = lesson_voice_tts.build_lesson_voice_profile("学生", alias)
    payload = json.loads(profile.request_json)
    assert profile.original_text == "学生"
    assert payload == {
        "text": "学生。",
        "voice_id": voice_id,
        "model_id": "eleven_multilingual_v2",
        "language_code": "ja",
        "output_format": "mp3_44100_128",
        "voice_settings": {"stability": 0.85, "similarity_boost": 0.85, "style": 0.0, "speed": 1.0, "use_speaker_boost": True},
    }
    assert profile.fingerprint == lesson_voice_tts.build_lesson_voice_profile("学生", alias).fingerprint


def test_profile_preserves_existing_short_input_punctuation_behavior() -> None:
    profile = lesson_voice_tts.build_lesson_voice_profile("学生です。", "japanese_male_1")
    assert profile.original_text == "学生です。"
    assert json.loads(profile.request_json)["text"] == "学生です。。"


@pytest.mark.parametrize("alias", [None, "", "Kore", "japanese_male_2"])
def test_unknown_role_cannot_use_default_voice(alias: str | None) -> None:
    with pytest.raises(RuntimeError, match="alias"):
        lesson_voice_tts.build_lesson_voice_profile("こんにちは。", alias)


@pytest.mark.parametrize(("female", "male"), [("female", ""), ("", "male"), ("same", "same"), ("same ", " same")])
def test_invalid_role_configuration_fails_closed(monkeypatch: pytest.MonkeyPatch, female: str, male: str) -> None:
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_FEMALE_VOICE_ID", female)
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_MALE_VOICE_ID", male)
    with pytest.raises(RuntimeError, match="distinct"):
        lesson_voice_tts.build_lesson_voice_profile("こんにちは。", "japanese_male_1")


def test_missing_api_key_does_not_fall_back(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_API_KEY", " ")
    with pytest.raises(RuntimeError, match="API key"):
        lesson_voice_tts.build_lesson_voice_profile("こんにちは。", "japanese_male_1")


@pytest.mark.parametrize(
    ("model", "voice_settings"),
    [("eleven_v3", {"stability": 0.5}), ("eleven_v4", {"stability": 0.5, "similarity_boost": 0.75})],
)
def test_model_override_uses_model_specific_speech_settings(model: str, voice_settings: dict[str, float]) -> None:
    profile = lesson_voice_tts.build_lesson_voice_profile("私は映画が好きです。", "japanese_male_1", model_id=model)
    payload = json.loads(profile.request_json)
    assert payload["voice_settings"] == voice_settings
    assert payload["text"] == "私は映画が好きです。"
    assert payload["model_id"] == model
    assert "inputs" not in payload and "settings" not in payload
    assert lesson_voice_tts.settings.ELEVENLABS_MODEL_ID == "eleven_multilingual_v2"


def test_unknown_model_requires_explicit_support() -> None:
    with pytest.raises(RuntimeError, match="model"):
        lesson_voice_tts.build_lesson_voice_profile("こんにちは。", "japanese_male_1", model_id="unsupported-model")


def test_fingerprint_covers_role_voice_model_raw_and_sent_text_policy_and_speed(monkeypatch: pytest.MonkeyPatch) -> None:
    original = lesson_voice_tts.build_lesson_voice_profile("学生", "japanese_male_1")
    variants = [
        lesson_voice_tts.build_lesson_voice_profile("学生", "japanese_female_1"),
        lesson_voice_tts.build_lesson_voice_profile("学生", "japanese_male_1", model_id="eleven_v4"),
        replace(original, original_text="another original"),
        replace(original, request_json=original.request_json.replace("学生。", "学生")),
        replace(original, policy_version="another-policy"),
        replace(original, speed=0.9),
    ]
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_MALE_VOICE_ID", "another-male")
    variants.append(lesson_voice_tts.build_lesson_voice_profile("学生", "japanese_male_1"))
    assert all(profile.fingerprint != original.fingerprint for profile in variants)
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_API_KEY", "another-api-key")
    assert lesson_voice_tts.build_lesson_voice_profile("学生", "japanese_male_1").fingerprint == variants[-1].fingerprint


@pytest.mark.asyncio
@pytest.mark.parametrize("model", ["eleven_multilingual_v2", "eleven_flash_v2_5", "eleven_turbo_v2_5", "eleven_v3", "eleven_v4"])
async def test_generated_sdk_request_is_exact_fingerprinted_payload(model: str) -> None:
    profile = lesson_voice_tts.build_lesson_voice_profile("学生", "japanese_male_1", model_id=model)
    client = MagicMock()
    client.text_to_speech.convert.return_value = iter([b"first", b"second"])
    with (
        patch("elevenlabs.client.ElevenLabs", return_value=client) as factory,
        patch.object(ai_speech, "_generate_tts_gemini", side_effect=AssertionError("no fallback")),
    ):
        result = await lesson_voice_tts.generate_lesson_voice_tts(profile)
    factory.assert_called_once_with(api_key="test-api-key")
    client.text_to_speech.convert.assert_called_once_with(**json.loads(profile.request_json))
    client.text_to_dialogue.convert.assert_not_called()
    assert result.audio == b"firstsecond" and result.provider == "elevenlabs" and result.model == model


@pytest.mark.asyncio
@pytest.mark.parametrize("model", ["eleven_multilingual_v2", "eleven_flash_v2_5", "eleven_turbo_v2_5", "eleven_v3", "eleven_v4"])
async def test_locked_sdk_serializes_profile_without_changing_payload(model: str) -> None:
    from elevenlabs.client import ElevenLabs

    profile = lesson_voice_tts.build_lesson_voice_profile("学生", "japanese_male_1", model_id=model)
    payload = json.loads(profile.request_json)
    requests: list[Request] = []

    def handle(request: Request) -> Response:
        requests.append(request)
        return Response(200, headers={"content-type": "audio/mpeg"}, content=b"synthetic-mp3")

    # Exercise the real locked SDK's path/query/body serialization with a local
    # in-memory transport. No provider request or generated audio is involved.
    with Client(transport=MockTransport(handle)) as http_client:
        sdk = ElevenLabs(api_key="test-api-key", httpx_client=http_client)
        with patch("elevenlabs.client.ElevenLabs", return_value=sdk):
            result = await lesson_voice_tts.generate_lesson_voice_tts(profile)
    assert result.audio == b"synthetic-mp3" and len(requests) == 1
    request = requests[0]
    assert request.method == "POST" and request.url.path == f"/v1/text-to-speech/{payload['voice_id']}"
    assert request.url.params["output_format"] == payload["output_format"]
    assert json.loads(request.content) == {key: value for key, value in payload.items() if key not in {"voice_id", "output_format"}}


@pytest.mark.asyncio
@pytest.mark.parametrize("empty_audio", [False, True])
async def test_generation_failure_never_falls_back_or_returns_empty_audio(empty_audio: bool) -> None:
    profile = lesson_voice_tts.build_lesson_voice_profile("こんにちは。", "japanese_male_1")
    client = MagicMock()
    if empty_audio:
        client.text_to_speech.convert.return_value = iter([])
    else:
        client.text_to_speech.convert.side_effect = RuntimeError("provider down")
    with (
        patch("elevenlabs.client.ElevenLabs", return_value=client),
        patch.object(ai_speech, "_generate_tts_gemini", side_effect=AssertionError("no fallback")) as fallback,
        pytest.raises(RuntimeError, match="Lesson speaker TTS"),
    ):
        await lesson_voice_tts.generate_lesson_voice_tts(profile)
    fallback.assert_not_called()
