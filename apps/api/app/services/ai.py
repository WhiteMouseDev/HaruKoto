"""AI service layer using Google GenAI (Gemini) SDK + ElevenLabs TTS."""

from __future__ import annotations

import asyncio
import json
import logging
import struct
from datetime import UTC, datetime, timedelta

import lameenc
from google import genai
from google.genai import types

from app.config import settings
from app.utils.prompts import SYSTEM_PROMPTS, build_system_prompt

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# SDK configuration
# ---------------------------------------------------------------------------

_client: genai.Client | None = None

if settings.GOOGLE_API_KEY:
    _client = genai.Client(api_key=settings.GOOGLE_API_KEY)
else:
    logger.warning("GOOGLE_API_KEY is not set — AI features will be unavailable")


def _ensure_configured() -> genai.Client:
    """Raise early if the SDK was never configured."""
    if _client is None:
        raise RuntimeError("Google AI SDK is not configured. Set GOOGLE_API_KEY in environment.")
    return _client


# ---------------------------------------------------------------------------
# Chat
# ---------------------------------------------------------------------------


async def generate_chat_response(
    system_prompt: str,
    messages: list[dict[str, str]],
    user_message: str,
) -> dict:
    """Generate an AI chat response.

    Args:
        system_prompt: Full system prompt (use ``build_system_prompt`` to build).
        messages: Prior conversation history as ``[{"role": "user"|"assistant", "content": "..."}]``.
        user_message: The latest user message to respond to.

    Returns:
        Parsed JSON dict from the model's response.
    """
    client = _ensure_configured()

    # Convert conversation history into SDK format
    history: list[types.Content] = []
    for msg in messages:
        role = "user" if msg.get("role") == "user" else "model"
        history.append(types.Content(role=role, parts=[types.Part.from_text(text=msg["content"])]))

    chat = client.aio.chats.create(
        model="gemini-2.5-flash",
        config=types.GenerateContentConfig(system_instruction=system_prompt),
        history=history,
    )
    response = await chat.send_message(user_message)

    return _parse_json_response(response.text)


# ---------------------------------------------------------------------------
# Feedback summary
# ---------------------------------------------------------------------------


async def generate_feedback_summary(messages: list[dict[str, str]]) -> dict:
    """Generate a structured evaluation of a completed conversation.

    Args:
        messages: Full conversation history.

    Returns:
        Parsed evaluation dict (scores, strengths, improvements, etc.).
    """
    client = _ensure_configured()

    conversation_text = "\n".join(f"{m.get('role', 'user')}: {m.get('content', '')}" for m in messages)
    response = await client.aio.models.generate_content(
        model="gemini-2.5-flash",
        contents=f"以下の会話を評価してください：\n\n{conversation_text}",
        config=types.GenerateContentConfig(
            system_instruction=str(SYSTEM_PROMPTS["feedback_evaluation"]),
        ),
    )

    return _parse_json_response(response.text)


# ---------------------------------------------------------------------------
# TTS
# ---------------------------------------------------------------------------


async def generate_tts(text: str) -> bytes:
    """Generate TTS audio, trying ElevenLabs first with Gemini fallback.

    Args:
        text: Japanese text to synthesise.

    Returns:
        MP3 file bytes.
    """
    # Try ElevenLabs first if configured
    if settings.ELEVENLABS_API_KEY and settings.ELEVENLABS_VOICE_ID:
        try:
            return await asyncio.to_thread(_generate_tts_elevenlabs, text)
        except Exception:
            logger.warning("ElevenLabs TTS failed for text=%r, falling back to Gemini", text, exc_info=True)

    # Fallback to Gemini
    return await _generate_tts_gemini(text)


def _generate_tts_elevenlabs(text: str) -> bytes:
    """Generate TTS via ElevenLabs SDK. Returns MP3 bytes directly.

    Voice settings (일본어 단어/가나 TTS 최적화):
    - stability=0.6: 약간 높게 → 단어 발음 일관성 확보
    - similarity_boost=0.8: 높게 → 선택한 음성 톤 유지
    - style=0.0: 꺼둠 → 단어 TTS에 감정 표현 불필요
    - speed=0.9: 약간 느리게 → 학습용이므로 또렷한 발음
    - speaker_boost=True: 화자 특성 강화
    """
    from elevenlabs.client import ElevenLabs

    client = ElevenLabs(api_key=settings.ELEVENLABS_API_KEY)

    audio_iter = client.text_to_speech.convert(
        text=text,
        voice_id=settings.ELEVENLABS_VOICE_ID,
        model_id=settings.ELEVENLABS_MODEL_ID,
        output_format="mp3_44100_128",
        language_code="ja",
        voice_settings={
            "stability": 0.6,
            "similarity_boost": 0.8,
            "style": 0.0,
            "speed": 0.9,
            "use_speaker_boost": True,
        },
    )

    # SDK returns an iterator of chunks
    return b"".join(audio_iter)


async def _generate_tts_gemini(text: str, voice: str = "Kore") -> bytes:
    """Generate TTS via Gemini. Returns MP3 bytes (PCM → MP3 conversion)."""
    client = _ensure_configured()

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

    # Extract PCM audio from response
    if not response.candidates:
        logger.error("TTS returned no candidates for text=%r", text)
        raise RuntimeError("TTS generation failed: no candidates returned")

    candidate = response.candidates[0]
    if candidate.content is None or not candidate.content.parts:
        logger.error(
            "TTS returned empty content for text=%r, finish_reason=%s, candidate=%s",
            text,
            getattr(candidate, "finish_reason", "unknown"),
            candidate,
        )
        raise RuntimeError("TTS generation failed: empty content returned")

    part = candidate.content.parts[0]
    if not hasattr(part, "inline_data") or part.inline_data is None:
        logger.error("TTS response part has no inline_data for text=%r, part=%s", text, part)
        raise RuntimeError("TTS generation failed: no audio data in response")

    pcm_data: bytes = part.inline_data.data

    return _pcm_to_mp3(pcm_data, sample_rate=24000, channels=1, bitrate=128)


# ---------------------------------------------------------------------------
# Transcription (STT)
# ---------------------------------------------------------------------------


async def transcribe_audio(audio_bytes: bytes, mime_type: str) -> str:
    """Transcribe audio to Japanese text.

    Args:
        audio_bytes: Raw audio data.
        mime_type: MIME type of the audio (e.g. ``"audio/webm"``).

    Returns:
        Transcribed Japanese text.
    """
    client = _ensure_configured()

    response = await client.aio.models.generate_content(
        model="gemini-2.5-flash",
        contents=[
            types.Part.from_text(text=str(SYSTEM_PROMPTS["transcription_prompt"])),
            types.Part.from_bytes(data=audio_bytes, mime_type=mime_type),
        ],
    )
    return response.text.strip()


# ---------------------------------------------------------------------------
# Live API (ephemeral token)
# ---------------------------------------------------------------------------

_LIVE_WS_URI = (
    "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContentConstrained"
)


async def generate_live_token() -> dict[str, str]:
    """Generate an ephemeral token for the Gemini Live API.

    Returns:
        ``{"token": "...", "wsUri": "wss://..."}``
    """
    _ensure_configured()

    alpha_client = genai.Client(
        api_key=settings.GOOGLE_API_KEY,
        http_options={"api_version": "v1alpha"},
    )

    expire_time = datetime.now(UTC) + timedelta(minutes=5)
    new_session_expire_time = datetime.now(UTC) + timedelta(minutes=1)

    token_response = alpha_client.auth_tokens.create(
        config={
            "uses": 1,
            "expire_time": expire_time.isoformat(),
            "new_session_expire_time": new_session_expire_time.isoformat(),
            "http_options": {"api_version": "v1alpha"},
        },
    )

    return {
        "token": token_response.name or "",
        "wsUri": _LIVE_WS_URI,
    }


# ---------------------------------------------------------------------------
# Live feedback
# ---------------------------------------------------------------------------


async def generate_live_feedback(
    transcript: list[dict[str, str]],
    scenario_info: str = "",
) -> dict:
    """Generate structured feedback from a voice conversation transcript.

    Args:
        transcript: List of ``{"role": "user"|"assistant", "text": "..."}`` entries.
        scenario_info: Optional scenario description for additional context.

    Returns:
        Parsed evaluation dict.
    """
    client = _ensure_configured()

    transcript_text = "\n".join(f"{t.get('role', 'user')}: {t.get('text', '')}" for t in transcript)
    prompt = f"以下の音声会話を評価してください：\n\n{transcript_text}"
    if scenario_info:
        prompt += f"\n\nシナリオ情報: {scenario_info}"

    response = await client.aio.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
        config=types.GenerateContentConfig(
            system_instruction=str(SYSTEM_PROMPTS["live_feedback"]),
        ),
    )
    return _parse_json_response(response.text)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _parse_json_response(text: str) -> dict:
    """Parse JSON from an AI response, handling markdown code fences.

    If parsing fails, returns a fallback dict with the raw text so callers
    always receive a dict.
    """
    cleaned = text.strip()

    # Strip ```json ... ``` or ``` ... ``` wrappers
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        # Remove first line (```json) and last line (```)
        lines = [line for line in lines if not line.strip().startswith("```")]
        cleaned = "\n".join(lines)

    try:
        return json.loads(cleaned)  # type: ignore[no-any-return]
    except json.JSONDecodeError:
        logger.warning("Failed to parse AI response as JSON, returning fallback")
        return {
            "messageJa": cleaned,
            "messageKo": "",
            "feedback": [],
            "hint": "",
            "newVocabulary": [],
        }


def _pcm_to_mp3(
    pcm_data: bytes,
    sample_rate: int = 24000,
    channels: int = 1,
    bitrate: int = 128,
) -> bytes:
    """Encode raw PCM data to MP3 using lameenc."""
    encoder = lameenc.Encoder()
    encoder.set_bit_rate(bitrate)
    encoder.set_in_sample_rate(sample_rate)
    encoder.set_channels(channels)
    encoder.set_quality(2)  # 2 = high quality
    mp3_data = encoder.encode(pcm_data)
    mp3_data += encoder.flush()
    return bytes(mp3_data)


def _pcm_to_wav(
    pcm_data: bytes,
    sample_rate: int = 24000,
    bits_per_sample: int = 16,
    channels: int = 1,
) -> bytes:
    """Create a WAV file from raw PCM data by prepending a RIFF/WAV header.

    .. note:: Currently unused — kept as a utility for debugging/testing.
    """
    data_size = len(pcm_data)
    byte_rate = sample_rate * channels * bits_per_sample // 8
    block_align = channels * bits_per_sample // 8

    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + data_size,  # file size - 8
        b"WAVE",
        b"fmt ",
        16,  # PCM format chunk size
        1,  # audio format (1 = PCM)
        channels,
        sample_rate,
        byte_rate,
        block_align,
        bits_per_sample,
        b"data",
        data_size,
    )
    return header + pcm_data


# Re-export build_system_prompt for convenience
__all__ = [
    "build_system_prompt",
    "generate_chat_response",
    "generate_feedback_summary",
    "generate_live_feedback",
    "generate_live_token",
    "generate_tts",
    "transcribe_audio",
]
