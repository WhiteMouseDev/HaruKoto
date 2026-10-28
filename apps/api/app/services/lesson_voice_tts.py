"""Opt-in N5 dialogue voices; existing cached audio and generic TTS stay unchanged."""

from __future__ import annotations

import asyncio
import hashlib
import json
from dataclasses import dataclass
from typing import Any

from app.config import settings
from app.services.ai_speech import TtsResult

_POLICY_VERSION = "n5-speaker-voices-v2"
_N5_DIALOGUE_MODEL_ID = "eleven_v4"
_SPEECH_MODELS = frozenset({"eleven_multilingual_v2", "eleven_flash_v2_5", "eleven_turbo_v2_5"})
_EXPRESSIVE_MODELS = frozenset({"eleven_v3", "eleven_v4"})


@dataclass(frozen=True, slots=True)
class LessonVoiceProfile:
    original_text: str
    voice_alias: str
    voice_id: str
    model_id: str
    # JSON freezes the exact request used for both the fingerprint and generation.
    request_json: str
    speed: float = 1.0
    policy_version: str = _POLICY_VERSION

    @property
    def fingerprint(self) -> str:
        identity = {
            "original_text": self.original_text,
            "voice_alias": self.voice_alias,
            "voice_id": self.voice_id,
            "provider": "elevenlabs",
            "model_id": self.model_id,
            "endpoint": "text_to_speech",
            "request": json.loads(self.request_json),
            "speed": self.speed,
            "policy_version": self.policy_version,
        }
        return hashlib.sha256(_canonical_json(identity).encode("utf-8")).hexdigest()


def lesson_voice_routing_enabled() -> bool:
    return bool(settings.ELEVENLABS_LESSON_FEMALE_VOICE_ID.strip() or settings.ELEVENLABS_LESSON_MALE_VOICE_ID.strip())


def build_lesson_voice_profile(text: str, voice_alias: str | None, *, model_id: str | None = None) -> LessonVoiceProfile:
    """Resolve the selected N5 policy; model overrides are for explicit review jobs."""
    female = settings.ELEVENLABS_LESSON_FEMALE_VOICE_ID.strip()
    male = settings.ELEVENLABS_LESSON_MALE_VOICE_ID.strip()
    if not female or not male or female == male:
        raise RuntimeError("Lesson voices require two distinct configured voice IDs")
    if not settings.ELEVENLABS_API_KEY.strip():
        raise RuntimeError("Lesson voices require an ElevenLabs API key")

    voices = {"japanese_female_1": female, "japanese_male_1": male}
    if voice_alias not in voices:
        raise RuntimeError("Lesson speaker voice alias is missing or unsupported")
    assert voice_alias is not None
    voice_id = voices[voice_alias]
    # Dialogue adoption is independent of the global word/kana/question model.
    model = (_N5_DIALOGUE_MODEL_ID if model_id is None else model_id).strip()
    if model not in _SPEECH_MODELS | _EXPRESSIVE_MODELS:
        raise RuntimeError("Lesson TTS model is unsupported")

    is_short = len(text) <= 8
    # The selected v4 samples used the exact source, including short punctuation.
    # Preserve historical formatting only for explicit older-model review jobs.
    actual_text = f"{text}。" if is_short and model != "eleven_v4" else text
    payload: dict[str, Any] = {
        "text": actual_text,
        "voice_id": voice_id,
        "model_id": model,
        "language_code": "ja",
        "output_format": "mp3_44100_128",
    }
    if model in _EXPRESSIVE_MODELS:
        voice_settings = {"stability": 0.5}
        if model == "eleven_v4":
            if voice_alias == "japanese_female_1":
                voice_settings["stability"] = 0.8
            voice_settings["similarity_boost"] = 0.75
        payload["voice_settings"] = voice_settings
    else:
        payload.update(
            voice_settings={
                "stability": 0.85 if is_short else 0.5,
                "similarity_boost": 0.85 if is_short else 0.75,
                "style": 0.0 if is_short else 0.15,
                "speed": 1.0,
                "use_speaker_boost": True,
            },
        )
    return LessonVoiceProfile(
        original_text=text,
        voice_alias=voice_alias,
        voice_id=voice_id,
        model_id=model,
        request_json=_canonical_json(payload),
    )


async def generate_lesson_voice_tts(profile: LessonVoiceProfile) -> TtsResult:
    """Generate one role-specific clip. No unapproved default-voice/Gemini fallback."""
    try:
        audio = await asyncio.to_thread(_generate_lesson_audio, profile)
    except Exception:
        # The caller logs this exception. Provider errors may contain request or
        # response bodies, so do not chain them into the public service traceback.
        raise RuntimeError("Lesson speaker TTS generation failed") from None
    if not audio:
        raise RuntimeError("Lesson speaker TTS returned empty audio")
    return TtsResult(audio=audio, provider="elevenlabs", model=profile.model_id)


def _generate_lesson_audio(profile: LessonVoiceProfile) -> bytes:
    from elevenlabs.client import ElevenLabs

    client = ElevenLabs(api_key=settings.ELEVENLABS_API_KEY)
    payload = json.loads(profile.request_json)
    return b"".join(client.text_to_speech.convert(**payload))


def _canonical_json(value: dict[str, Any]) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
