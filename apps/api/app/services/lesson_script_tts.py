from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Lesson
from app.models.tts import TtsAudio
from app.services.tts_generation import (
    TTS_GENERATION_FAILED_DETAIL,
    TtsGenerator,
    TtsServiceError,
    TtsUploader,
    tts_generation_lock,
)
from app.services.tts_target_resolver import TtsTargetResolverError, resolve_lesson_script_line_tts_target

logger = logging.getLogger(__name__)

_GENERATING: set[str] = set()


class LessonScriptTtsServiceError(TtsServiceError):
    pass


@dataclass(frozen=True, slots=True)
class LessonScriptTtsResult:
    audio_url: str


async def generate_lesson_script_line_tts(
    db: AsyncSession,
    *,
    lesson_id: UUID,
    line_index: int,
    tts_generator: TtsGenerator,
    upload_to_gcs: TtsUploader,
    generating: set[str] | None = None,
) -> LessonScriptTtsResult:
    result = await db.execute(select(Lesson).where(Lesson.id == lesson_id, Lesson.is_published.is_(True)))
    lesson = result.scalar_one_or_none()
    if lesson is None:
        raise LessonScriptTtsServiceError(status_code=404, detail="레슨을 찾을 수 없습니다")

    try:
        target = resolve_lesson_script_line_tts_target(
            lesson_id=lesson.id,
            content=lesson.content_jsonb or {},
            line_index=line_index,
        )
    except TtsTargetResolverError as exc:
        raise LessonScriptTtsServiceError(status_code=exc.status_code, detail=exc.detail) from exc

    cached = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == target.target_type,
            TtsAudio.target_id == target.target_id,
            TtsAudio.speed == 1.0,
            TtsAudio.field == target.field,
        )
    )
    tts_record = cached.scalar_one_or_none()
    if tts_record:
        return LessonScriptTtsResult(audio_url=tts_record.audio_url)

    active_generations = _GENERATING if generating is None else generating
    with tts_generation_lock(target.target_id, active_generations, error_cls=LessonScriptTtsServiceError):
        try:
            tts_result = await tts_generator(target.text)
        except RuntimeError:
            logger.exception("TTS generation failed for lesson script target=%s, text=%r", target.target_id, target.text)
            raise LessonScriptTtsServiceError(status_code=502, detail=TTS_GENERATION_FAILED_DETAIL) from None

        audio_url = await upload_to_gcs(f"tts/lesson/{lesson.id}/script-line-{line_index}.mp3", tts_result.audio)

        db.add(
            TtsAudio(
                target_type=target.target_type,
                target_id=target.target_id,
                text=target.text,
                speed=1.0,
                provider=tts_result.provider,
                model=tts_result.model,
                audio_url=audio_url,
                field=target.field,
            )
        )
        await db.commit()

        return LessonScriptTtsResult(audio_url=audio_url)
