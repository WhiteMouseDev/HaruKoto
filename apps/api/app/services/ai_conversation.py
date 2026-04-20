from __future__ import annotations

import asyncio
import logging

from google.genai import types

from app.services.ai_client import ensure_google_client
from app.services.ai_json import parse_json_response
from app.utils.prompts import SYSTEM_PROMPTS

logger = logging.getLogger(__name__)


async def generate_chat_response(
    system_prompt: str,
    messages: list[dict[str, str]],
    user_message: str,
) -> dict:
    """Generate an AI chat response."""
    client = ensure_google_client()

    history: list[types.Content] = []
    for message in messages:
        role = "user" if message.get("role") == "user" else "model"
        history.append(types.Content(role=role, parts=[types.Part.from_text(text=message["content"])]))

    chat = client.aio.chats.create(
        model="gemini-2.5-flash",
        config=types.GenerateContentConfig(system_instruction=system_prompt),
        history=history,
    )
    response = await chat.send_message(user_message)

    return parse_json_response(response.text)


async def generate_feedback_summary(messages: list[dict[str, str]]) -> dict:
    """Generate a structured evaluation of a completed conversation."""
    client = ensure_google_client()

    conversation_text = "\n".join(f"{message.get('role', 'user')}: {message.get('content', '')}" for message in messages)
    response = await client.aio.models.generate_content(
        model="gemini-2.5-flash",
        contents=f"以下の会話を評価してください：\n\n{conversation_text}",
        config=types.GenerateContentConfig(
            system_instruction=str(SYSTEM_PROMPTS["feedback_evaluation"]),
        ),
    )

    return parse_json_response(response.text)


async def transcribe_audio(audio_bytes: bytes, mime_type: str) -> str:
    """Transcribe audio to Japanese text."""
    client = ensure_google_client()

    response = await client.aio.models.generate_content(
        model="gemini-2.5-flash",
        contents=[
            types.Part.from_text(text=str(SYSTEM_PROMPTS["transcription_prompt"])),
            types.Part.from_bytes(data=audio_bytes, mime_type=mime_type),
        ],
    )
    return response.text.strip()


async def generate_live_feedback(
    transcript: list[dict[str, str]],
    scenario_info: str = "",
) -> dict:
    """Generate structured feedback from a voice conversation transcript."""
    client = ensure_google_client()

    transcript_text = "\n".join(f"{item.get('role', 'user')}: {item.get('text', '')}" for item in transcript)
    prompt = f"以下の音声会話を評価してください：\n\n{transcript_text}"
    if scenario_info:
        prompt += f"\n\nシナリオ情報: {scenario_info}"

    last_error: Exception | None = None
    for attempt in range(3):
        try:
            response = await client.aio.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=str(SYSTEM_PROMPTS["live_feedback"]),
                ),
            )
            return parse_json_response(response.text)
        except Exception as exc:
            last_error = exc
            logger.warning("Live feedback attempt %d/%d failed: %s", attempt + 1, 3, exc)
            if attempt < 2:
                await asyncio.sleep(1 << attempt)

    logger.error("Live feedback failed after 3 attempts")
    raise last_error or RuntimeError("Live feedback generation failed")
