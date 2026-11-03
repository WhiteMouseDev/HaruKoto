from __future__ import annotations

import re
from typing import Any


def _normalized(text: str) -> str:
    return "".join(text.split())


def ground_live_feedback(feedback: dict[str, Any], transcript: list[dict[str, str]]) -> dict[str, Any]:
    """Keep original speech authoritative; model rewrites are never evidence."""
    user_text = [_normalized(entry.get("text", "")) for entry in transcript if entry.get("role") == "user"]
    feedback["corrections"] = [
        correction
        for correction in feedback["corrections"]
        if (quote := _normalized(correction["original"]))
        and re.search(r"[ぁ-ゖァ-ヺ一-龯]", quote)
        and any(quote in text for text in user_text)
    ]
    originals = [entry for entry in transcript if entry.get("role") in {"user", "assistant"}]
    translations = feedback["translatedTranscript"]
    aligned = len(originals) == len(translations) and all(
        original["role"] == translated["role"] for original, translated in zip(originals, translations, strict=False)
    )
    feedback["translatedTranscript"] = [
        {
            "role": original["role"],
            "ja": original.get("text", ""),
            "ko": translations[index]["ko"]
            if aligned and _normalized(translations[index]["ja"]) == _normalized(original.get("text", ""))
            else "",
        }
        for index, original in enumerate(originals)
    ]
    return feedback
