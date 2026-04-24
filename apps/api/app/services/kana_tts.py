from __future__ import annotations

import logging
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tts import TtsAudio
from app.services.tts_generation import (
    TTS_GENERATION_FAILED_DETAIL,
    TtsGenerator,
    TtsServiceError,
    TtsUploader,
    stable_tts_key,
    tts_generation_lock,
)

logger = logging.getLogger(__name__)

_GENERATING: set[str] = set()
KANA_TTS_FIELD = "reading"


class KanaTtsServiceError(TtsServiceError):
    pass


@dataclass(frozen=True, slots=True)
class KanaTtsResult:
    audio_url: str


async def generate_kana_tts(
    db: AsyncSession,
    *,
    text: str,
    tts_generator: TtsGenerator,
    upload_to_gcs: TtsUploader,
    generating: set[str] | None = None,
) -> KanaTtsResult:
    text_hash = stable_tts_key(text)

    cached = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == "kana",
            TtsAudio.target_id == text_hash,
            TtsAudio.speed == 1.0,
            TtsAudio.field == KANA_TTS_FIELD,
        )
    )
    tts_record = cached.scalar_one_or_none()
    if tts_record:
        return KanaTtsResult(audio_url=tts_record.audio_url)

    active_generations = _GENERATING if generating is None else generating
    with tts_generation_lock(text_hash, active_generations, error_cls=KanaTtsServiceError):
        try:
            tts_result = await tts_generator(text)
        except RuntimeError:
            logger.exception("TTS generation failed for text=%r", text)
            raise KanaTtsServiceError(status_code=502, detail=TTS_GENERATION_FAILED_DETAIL) from None

        audio_url = await upload_to_gcs(f"tts/kana/{text_hash}.mp3", tts_result.audio)

        db.add(
            TtsAudio(
                target_type="kana",
                target_id=text_hash,
                text=text,
                speed=1.0,
                provider=tts_result.provider,
                model=tts_result.model,
                audio_url=audio_url,
                field=KANA_TTS_FIELD,
            )
        )
        await db.commit()

        return KanaTtsResult(audio_url=audio_url)
