from __future__ import annotations

import asyncio
import logging
from typing import Any

from google.genai import errors, types

from app.schemas.ai_feedback import LiveFeedbackOutput, TextFeedbackOutput
from app.services.ai_client import ensure_google_client
from app.services.ai_json import parse_feedback_response, parse_json_response
from app.services.live_feedback_evidence import ground_live_feedback
from app.utils.prompts import SYSTEM_PROMPTS

logger = logging.getLogger(__name__)
LIVE_FEEDBACK_TIMEOUT_SECONDS = 20


def _require_response_text(text: str | None, context: str) -> str:
    if text is None:
        raise RuntimeError(f"{context} returned no text")
    return text


async def generate_chat_response(
    system_prompt: str,
    messages: list[dict[str, str]],
    user_message: str,
) -> dict[str, Any]:
    """Generate an AI chat response."""
    client = ensure_google_client()

    history: list[types.Content | types.ContentDict] = []
    for message in messages:
        role = "user" if message.get("role") == "user" else "model"
        history.append(types.Content(role=role, parts=[types.Part.from_text(text=message["content"])]))

    chat = client.aio.chats.create(
        model="gemini-2.5-flash",
        config=types.GenerateContentConfig(system_instruction=system_prompt),
        history=history,
    )
    response = await chat.send_message(user_message)

    return parse_json_response(_require_response_text(response.text, "Chat response"))


async def generate_feedback_summary(messages: list[dict[str, str]]) -> dict[str, Any]:
    """Generate a structured evaluation of a completed conversation."""
    client = ensure_google_client()

    conversation_text = "\n".join(f"{message.get('role', 'user')}: {message.get('content', '')}" for message in messages)
    response = await client.aio.models.generate_content(
        model="gemini-2.5-flash",
        contents=f"以下の会話を評価してください：\n\n{conversation_text}",
        config=types.GenerateContentConfig(
            system_instruction=str(SYSTEM_PROMPTS["feedback_evaluation"]),
            response_mime_type="application/json",
            response_json_schema=TextFeedbackOutput.model_json_schema(),
            http_options=types.HttpOptions(retry_options=types.HttpRetryOptions(attempts=1)),
        ),
    )

    return parse_feedback_response(_require_response_text(response.text, "Feedback summary"), TextFeedbackOutput)


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
    return _require_response_text(response.text, "Transcription").strip()


async def generate_live_feedback(
    transcript: list[dict[str, str]],
    scenario_info: str = "",
    *,
    jlpt_level: str = "",
) -> dict[str, Any]:
    """Generate structured feedback from a voice conversation transcript."""
    client = ensure_google_client()

    transcript_text = "\n".join(f"{item.get('role', 'user')}: {item.get('text', '')}" for item in transcript)
    prompt = f"以下の音声会話を評価してください：\n\n{transcript_text}"
    if scenario_info:
        prompt += f"\n\nシナリオ情報: {scenario_info}"
    if jlpt_level:
        prompt += f"\n\n学習者のJLPTレベル: {jlpt_level}"

    last_error: Exception | None = None
    async with asyncio.timeout(LIVE_FEEDBACK_TIMEOUT_SECONDS):
        for attempt in range(3):
            try:
                response = await client.aio.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=str(SYSTEM_PROMPTS["live_feedback"]),
                        response_mime_type="application/json",
                        response_json_schema=LiveFeedbackOutput.model_json_schema(),
                        thinking_config=types.ThinkingConfig(thinking_budget=0),
                        # This service owns retries and their total timeout.
                        http_options=types.HttpOptions(retry_options=types.HttpRetryOptions(attempts=1)),
                    ),
                )
                feedback = parse_feedback_response(_require_response_text(response.text, "Live feedback"), LiveFeedbackOutput)
                return ground_live_feedback(feedback, transcript)
            except Exception as exc:
                last_error = exc
                status_code = exc.code if isinstance(exc, errors.APIError) else None
                logger.warning(
                    "Live feedback attempt %d/%d failed (error_type=%s, status_code=%s)",
                    attempt + 1,
                    3,
                    type(exc).__name__,
                    status_code,
                )
                if status_code is not None and 400 <= status_code < 500 and status_code not in {408, 429}:
                    raise
                if attempt < 2:
                    await asyncio.sleep(1 << attempt)

    logger.error("Live feedback failed after 3 attempts")
    raise last_error or RuntimeError("Live feedback generation failed")
