"""Public AI service facade.

Keep this module as the stable import surface for routers/services while
provider-specific implementations live in focused modules.
"""

from __future__ import annotations

from app.services.ai_conversation import (
    generate_chat_response,
    generate_feedback_summary,
    generate_live_feedback,
    transcribe_audio,
)
from app.services.ai_live import generate_live_token
from app.services.ai_speech import TtsResult, generate_tts
from app.utils.prompts import build_system_prompt

__all__ = [
    "TtsResult",
    "build_system_prompt",
    "generate_chat_response",
    "generate_feedback_summary",
    "generate_live_feedback",
    "generate_live_token",
    "generate_tts",
    "transcribe_audio",
]
