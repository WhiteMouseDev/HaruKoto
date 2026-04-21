from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

from sqlalchemy import delete as sa_delete
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary
from app.models.tts import TtsAudio

TTS_FIELDS: dict[str, list[str]] = {
    "vocabulary": ["reading", "word", "example_sentence"],
    "grammar": ["pattern", "example_sentences"],
    "cloze": ["sentence"],
    "sentence_arrange": ["japanese_sentence"],
    "conversation": ["situation"],
}

_CONTENT_MODEL_MAP: dict[str, type] = {
    "vocabulary": Vocabulary,
    "grammar": Grammar,
    "cloze": ClozeQuestion,
    "sentence_arrange": SentenceArrangeQuestion,
    "conversation": ConversationScenario,
}


class AdminTtsGeneratedAudio(Protocol):
    audio: bytes
    provider: str
    model: str


type AdminTtsGenerator = Callable[[str], Awaitable[AdminTtsGeneratedAudio]]
type AdminTtsUploader = Callable[[str, bytes], Awaitable[str]]


class AdminTtsServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(frozen=True, slots=True)
class AdminTtsRegenerateResult:
    audio_url: str
    field: str
    provider: str


@dataclass(frozen=True, slots=True)
class AdminTtsAudioInfo:
    audio_url: str
    provider: str
    created_at: datetime


@dataclass(frozen=True, slots=True)
class AdminTtsMapResult:
    audios: dict[str, AdminTtsAudioInfo | None]


async def regenerate_admin_tts_audio(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: str,
    field: str,
    tts_generator: AdminTtsGenerator,
    upload_to_gcs: AdminTtsUploader,
) -> AdminTtsRegenerateResult:
    valid_fields = TTS_FIELDS.get(content_type, [])
    if field not in valid_fields:
        raise AdminTtsServiceError(status_code=422, detail=f"Invalid field '{field}' for {content_type}")

    model_cls = _CONTENT_MODEL_MAP.get(content_type)
    if not model_cls:
        raise AdminTtsServiceError(status_code=400, detail=f"Unknown content_type: {content_type}")

    result: Any = await db.execute(select(model_cls).where(model_cls.id == item_id))  # type: ignore[attr-defined]
    obj = result.scalar_one_or_none()
    if not obj:
        raise AdminTtsServiceError(status_code=404, detail="Content item not found")

    text = resolve_tts_text(content_type, field, obj)

    await db.execute(
        sa_delete(TtsAudio).where(
            TtsAudio.target_type == content_type,
            TtsAudio.target_id == item_id,
            TtsAudio.speed == 1.0,
            TtsAudio.field == field,
        )
    )

    try:
        tts_result = await tts_generator(text)
    except RuntimeError:
        raise AdminTtsServiceError(status_code=502, detail="TTS生成に失敗しました") from None

    gcs_path = f"tts/admin/{content_type}/{item_id}/{field}.mp3"
    audio_url = await upload_to_gcs(gcs_path, tts_result.audio)

    db.add(
        TtsAudio(
            target_type=content_type,
            target_id=item_id,
            text=text,
            speed=1.0,
            provider=tts_result.provider,
            model=tts_result.model,
            audio_url=audio_url,
            field=field,
        )
    )
    await db.commit()

    return AdminTtsRegenerateResult(
        audio_url=audio_url,
        field=field,
        provider=tts_result.provider,
    )


async def get_admin_tts_map(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: str,
) -> AdminTtsMapResult:
    fields = TTS_FIELDS.get(content_type)
    if fields is None:
        raise AdminTtsServiceError(status_code=400, detail=f"Unknown content_type: {content_type}")

    result = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == content_type,
            TtsAudio.target_id == item_id,
            TtsAudio.speed == 1.0,
        )
    )
    records = result.scalars().all()

    audios: dict[str, AdminTtsAudioInfo | None] = {field: None for field in fields}
    for record in records:
        if record.field in audios:
            audios[record.field] = AdminTtsAudioInfo(
                audio_url=record.audio_url,
                provider=record.provider,
                created_at=record.created_at,
            )

    return AdminTtsMapResult(audios=audios)


def resolve_tts_text(content_type: str, field: str, obj: object) -> str:
    """Extract text value for TTS from a content model instance by field name."""
    if content_type == "grammar" and field == "example_sentences":
        sentences = getattr(obj, "example_sentences", None) or []
        if sentences and isinstance(sentences[0], dict):
            return str(sentences[0].get("japanese") or sentences[0].get("sentence") or "")
        return getattr(obj, "pattern", "") or ""

    value = getattr(obj, field, None)
    if not value:
        raise AdminTtsServiceError(status_code=422, detail=f"Field '{field}' is empty or unavailable")
    return str(value)
