from __future__ import annotations

import json
import logging
from typing import Any, cast

from pydantic import BaseModel

logger = logging.getLogger(__name__)


def parse_feedback_response(text: str, schema: type[BaseModel]) -> dict[str, Any]:
    """Reject missing or malformed scores instead of returning a chat fallback."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        cleaned = "\n".join(line for line in lines if not line.strip().startswith("```"))
    return schema.model_validate_json(cleaned).model_dump(by_alias=True)


def parse_json_response(text: str) -> dict[str, Any]:
    """Parse JSON from an AI response, handling markdown code fences."""
    cleaned = text.strip()

    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        lines = [line for line in lines if not line.strip().startswith("```")]
        cleaned = "\n".join(lines)

    try:
        return cast(dict[str, Any], json.loads(cleaned))
    except json.JSONDecodeError:
        logger.warning("Failed to parse AI response as JSON, returning fallback")
        return {
            "messageJa": cleaned,
            "messageKo": "",
            "feedback": [],
            "hint": "",
            "newVocabulary": [],
        }
