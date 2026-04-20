from __future__ import annotations

import json
import logging

logger = logging.getLogger(__name__)


def parse_json_response(text: str) -> dict:
    """Parse JSON from an AI response, handling markdown code fences."""
    cleaned = text.strip()

    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
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
