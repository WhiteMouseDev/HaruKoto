from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Vocabulary
from app.models.tts import TtsAudio
from app.services.tts_generation import (
    TTS_GENERATION_FAILED_DETAIL,
    TtsGenerator,
    TtsServiceError,
    TtsUploader,
    tts_generation_lock,
)

logger = logging.getLogger(__name__)

_GENERATING: set[str] = set()


class VocabTtsServiceError(TtsServiceError):
    pass


@dataclass(frozen=True, slots=True)
class VocabTtsResult:
    audio_url: str


async def generate_vocabulary_tts(
    db: AsyncSession,
    *,
    vocabulary_id: str,
    tts_generator: TtsGenerator,
    upload_to_gcs: TtsUploader,
    generating: set[str] | None = None,
) -> VocabTtsResult:
    result = await db.execute(select(Vocabulary).where(Vocabulary.id == vocabulary_id))
    vocab = result.scalar_one_or_none()
    if not vocab:
        raise VocabTtsServiceError(status_code=404, detail="단어를 찾을 수 없습니다")

    vocab_id_str = str(vocab.id)

    cached = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == "vocabulary",
            TtsAudio.target_id == vocab_id_str,
            TtsAudio.speed == 1.0,
            TtsAudio.field == "reading",
        )
    )
    tts_record = cached.scalar_one_or_none()
    if tts_record:
        return VocabTtsResult(audio_url=tts_record.audio_url)

    if vocab.audio_url:
        return VocabTtsResult(audio_url=vocab.audio_url)

    active_generations = _GENERATING if generating is None else generating
    with tts_generation_lock(vocab_id_str, active_generations, error_cls=VocabTtsServiceError):
        text = _resolve_vocabulary_tts_text(vocab)

        try:
            tts_result = await tts_generator(text)
        except RuntimeError:
            logger.exception("TTS generation failed for vocab %s, text=%r", vocab_id_str, text)
            raise VocabTtsServiceError(status_code=502, detail=TTS_GENERATION_FAILED_DETAIL) from None

        audio_url = await upload_to_gcs(f"tts/vocab/{vocab_id_str}.mp3", tts_result.audio)

        db.add(
            TtsAudio(
                target_type="vocabulary",
                target_id=vocab_id_str,
                text=text,
                speed=1.0,
                provider=tts_result.provider,
                model=tts_result.model,
                audio_url=audio_url,
                field="reading",
            )
        )

        vocab.audio_url = audio_url
        await db.commit()

        return VocabTtsResult(audio_url=audio_url)


def _resolve_vocabulary_tts_text(vocab: Any) -> str:
    if vocab.reading and vocab.reading != vocab.word:
        return str(vocab.reading)
    return str(vocab.word)
