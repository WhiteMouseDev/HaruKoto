from __future__ import annotations

import re
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any

KANA_TTS_FIELD = "reading"
# /kana/tts is for standalone kana glyphs or kana-only practice text.
# Vocabulary words must resolve through vocabulary targets so TTS uses reading.
_KANA_TTS_TEXT_RE = re.compile(r"^[\u3040-\u309F\u30A0-\u30FF\u3000-\u303F\uFF66-\uFF9F]+$")
_KANJI_RE = re.compile(r"[\u4E00-\u9FFF]")
LESSON_SCRIPT_LINE_TTS_TARGET_TYPE = "lesson_script_line"
LESSON_SCRIPT_LINE_TTS_FIELD = "script_line"


class TtsTargetResolverError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(frozen=True, slots=True)
class ResolvedTtsTarget:
    target_type: str
    target_id: str
    field: str
    text: str


def resolve_vocabulary_reading_tts_target(vocab: Any) -> ResolvedTtsTarget:
    """Resolve the authoritative TTS text for a vocabulary reading target."""
    target_id = str(getattr(vocab, "id", ""))
    text = _resolve_vocabulary_reading_text(vocab)
    return ResolvedTtsTarget(
        target_type="vocabulary",
        target_id=target_id,
        field="reading",
        text=text,
    )


def resolve_content_tts_text(content_type: str, field: str, obj: object) -> str:
    """Resolve admin/content TTS text from the server-side content model."""
    if content_type == "grammar" and field == "example_sentences":
        sentences = getattr(obj, "example_sentences", None) or []
        if sentences and isinstance(sentences[0], dict):
            return _require_text(
                sentences[0].get("japanese") or sentences[0].get("sentence"),
                field=field,
            )
        return _require_text(getattr(obj, "pattern", None), field=field)

    return _require_text(getattr(obj, field, None), field=field)


def resolve_lesson_script_line_tts_target(
    *,
    lesson_id: Any,
    content: Any,
    line_index: int,
) -> ResolvedTtsTarget:
    """Resolve a lesson dialogue line from server-owned lesson content."""
    if line_index < 0:
        raise TtsTargetResolverError(status_code=404, detail="Script line not found")

    reading = _field_value(content, "reading")
    script = _field_value(reading, "script")
    if not _is_sequence(script) or line_index >= len(script):
        raise TtsTargetResolverError(status_code=404, detail="Script line not found")

    line = script[line_index]
    text = _require_text(_field_value(line, "text"), field=LESSON_SCRIPT_LINE_TTS_FIELD)
    return ResolvedTtsTarget(
        target_type=LESSON_SCRIPT_LINE_TTS_TARGET_TYPE,
        target_id=f"{lesson_id}:script:{line_index}",
        field=LESSON_SCRIPT_LINE_TTS_FIELD,
        text=text,
    )


def resolve_kana_tts_text(text: str) -> str:
    """Resolve text for kana-only TTS. Vocabulary words must use /vocab/tts."""
    normalized = text.strip()
    if not 1 <= len(normalized) <= 10:
        raise TtsTargetResolverError(status_code=422, detail="텍스트는 1~10자여야 합니다")
    if _KANJI_RE.search(normalized) or not _KANA_TTS_TEXT_RE.match(normalized):
        raise TtsTargetResolverError(
            status_code=422,
            detail="kana TTS는 히라가나/가타카나 텍스트만 입력 가능합니다",
        )
    return normalized


def _resolve_vocabulary_reading_text(vocab: Any) -> str:
    reading = _optional_text(getattr(vocab, "reading", None))
    word = _optional_text(getattr(vocab, "word", None))
    if reading and reading != word:
        return reading
    return _require_text(word, field="word")


def _require_text(value: Any, *, field: str) -> str:
    text = _optional_text(value)
    if not text:
        raise TtsTargetResolverError(status_code=422, detail=f"Field '{field}' is empty or unavailable")
    return text


def _optional_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _field_value(obj: Any, field: str) -> Any:
    if isinstance(obj, Mapping):
        return obj.get(field)
    return getattr(obj, field, None)


def _is_sequence(value: Any) -> bool:
    return isinstance(value, Sequence) and not isinstance(value, (bytes, str))
