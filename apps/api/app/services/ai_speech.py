from __future__ import annotations

import asyncio
import logging
import struct
from dataclasses import dataclass

import lameenc  # type: ignore[import-not-found]
from google.genai import types

from app.config import settings
from app.services.ai_client import ensure_google_client

logger = logging.getLogger(__name__)


@dataclass
class TtsResult:
    """TTS generation result with metadata."""

    audio: bytes
    provider: str
    model: str


async def generate_tts(text: str, voice: str = "Kore") -> TtsResult:
    """Generate TTS audio, trying ElevenLabs first with Gemini fallback."""
    if settings.ELEVENLABS_API_KEY and settings.ELEVENLABS_VOICE_ID:
        try:
            audio = await asyncio.to_thread(_generate_tts_elevenlabs, text)
            return TtsResult(audio=audio, provider="elevenlabs", model=settings.ELEVENLABS_MODEL_ID)
        except Exception:
            logger.warning("ElevenLabs TTS failed for text=%r, falling back to Gemini", text, exc_info=True)

    audio = await _generate_tts_gemini(text, voice=voice)
    return TtsResult(audio=audio, provider="gemini", model="gemini-2.5-flash-preview-tts")


def _is_short_text(text: str) -> bool:
    return len(text) <= 8


def _generate_tts_elevenlabs(text: str) -> bytes:
    from elevenlabs.client import ElevenLabs

    client = ElevenLabs(api_key=settings.ELEVENLABS_API_KEY)
    is_word = _is_short_text(text)
    tts_text = f"{text}。" if is_word else text

    voice_settings = {
        "stability": 0.85 if is_word else 0.5,
        "similarity_boost": 0.85 if is_word else 0.75,
        "style": 0.0 if is_word else 0.15,
        "speed": 1.0,
        "use_speaker_boost": True,
    }

    audio_iter = client.text_to_speech.convert(
        text=tts_text,
        voice_id=settings.ELEVENLABS_VOICE_ID,
        model_id=settings.ELEVENLABS_MODEL_ID,
        output_format="mp3_44100_128",
        language_code="ja",
        voice_settings=voice_settings,
    )
    return b"".join(audio_iter)


async def _generate_tts_gemini(text: str, voice: str = "Kore", _max_retries: int = 2) -> bytes:
    client = ensure_google_client()

    last_error: RuntimeError | None = None

    for attempt in range(_max_retries):
        response = await client.aio.models.generate_content(
            model="gemini-2.5-flash-preview-tts",
            contents=text,
            config=types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name=voice,
                        ),
                    ),
                ),
            ),
        )

        if not response.candidates:
            last_error = RuntimeError("TTS generation failed: no candidates returned")
            logger.warning("TTS attempt %d/%d: no candidates for text=%r", attempt + 1, _max_retries, text)
            continue

        candidate = response.candidates[0]
        if candidate.content is None or not candidate.content.parts:
            last_error = RuntimeError("TTS generation failed: empty content returned")
            logger.warning(
                "TTS attempt %d/%d: empty content for text=%r, finish_reason=%s",
                attempt + 1,
                _max_retries,
                text,
                getattr(candidate, "finish_reason", "unknown"),
            )
            continue

        part = candidate.content.parts[0]
        if not hasattr(part, "inline_data") or part.inline_data is None:
            last_error = RuntimeError("TTS generation failed: no audio data in response")
            logger.warning("TTS attempt %d/%d: no inline_data for text=%r", attempt + 1, _max_retries, text)
            continue

        pcm_data = part.inline_data.data
        if pcm_data is None:
            last_error = RuntimeError("TTS generation failed: empty audio data in response")
            logger.warning("TTS attempt %d/%d: empty inline_data for text=%r", attempt + 1, _max_retries, text)
            continue
        return _pcm_to_mp3(pcm_data, sample_rate=24000, channels=1, bitrate=128)

    logger.error("TTS failed after %d attempts for text=%r", _max_retries, text)
    raise last_error or RuntimeError("TTS generation failed")


def _pcm_to_mp3(
    pcm_data: bytes,
    sample_rate: int = 24000,
    channels: int = 1,
    bitrate: int = 128,
) -> bytes:
    encoder = lameenc.Encoder()
    encoder.set_bit_rate(bitrate)
    encoder.set_in_sample_rate(sample_rate)
    encoder.set_channels(channels)
    encoder.set_quality(2)
    mp3_data = encoder.encode(pcm_data)
    mp3_data += encoder.flush()
    return bytes(mp3_data)


def _pcm_to_wav(
    pcm_data: bytes,
    sample_rate: int = 24000,
    bits_per_sample: int = 16,
    channels: int = 1,
) -> bytes:
    data_size = len(pcm_data)
    byte_rate = sample_rate * channels * bits_per_sample // 8
    block_align = channels * bits_per_sample // 8

    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + data_size,
        b"WAVE",
        b"fmt ",
        16,
        1,
        channels,
        sample_rate,
        byte_rate,
        block_align,
        bits_per_sample,
        b"data",
        data_size,
    )
    return header + pcm_data
