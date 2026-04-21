from __future__ import annotations

import hashlib
import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tts import TtsAudio

logger = logging.getLogger(__name__)

_GENERATING: set[str] = set()


class KanaTtsGeneratedAudio(Protocol):
    audio: bytes
    provider: str
    model: str


type KanaTtsGenerator = Callable[[str], Awaitable[KanaTtsGeneratedAudio]]
type KanaTtsUploader = Callable[[str, bytes], Awaitable[str]]


class KanaTtsServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(frozen=True, slots=True)
class KanaTtsResult:
    audio_url: str


async def generate_kana_tts(
    db: AsyncSession,
    *,
    text: str,
    tts_generator: KanaTtsGenerator,
    upload_to_gcs: KanaTtsUploader,
    generating: set[str] | None = None,
) -> KanaTtsResult:
    text_hash = _kana_text_hash(text)

    cached = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == "kana",
            TtsAudio.target_id == text_hash,
            TtsAudio.speed == 1.0,
        )
    )
    tts_record = cached.scalar_one_or_none()
    if tts_record:
        return KanaTtsResult(audio_url=tts_record.audio_url)

    active_generations = _GENERATING if generating is None else generating
    if text_hash in active_generations:
        raise KanaTtsServiceError(status_code=409, detail="TTS 생성 중입니다. 잠시 후 다시 시도해주세요.")
    active_generations.add(text_hash)

    try:
        try:
            tts_result = await tts_generator(text)
        except RuntimeError:
            logger.exception("TTS generation failed for text=%r", text)
            raise KanaTtsServiceError(status_code=502, detail="TTS 음성 생성에 실패했습니다") from None

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
            )
        )
        await db.commit()

        return KanaTtsResult(audio_url=audio_url)
    finally:
        active_generations.discard(text_hash)


def _kana_text_hash(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()  # noqa: S324
