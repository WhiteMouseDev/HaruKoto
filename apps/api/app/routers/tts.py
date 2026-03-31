from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.dependencies import get_current_user
from app.middleware.rate_limit import rate_limit
from app.models import Vocabulary
from app.models.tts import TtsAudio
from app.models.user import User
from app.services.ai import generate_tts
from app.utils.constants import RATE_LIMITS

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/vocab", tags=["tts"])

# In-memory set to prevent duplicate concurrent TTS generation
_generating: set[str] = set()


class VocabTTSRequest(BaseModel):
    id: str


@router.post("/tts", status_code=200)
async def vocab_tts(
    body: VocabTTSRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    rl = await rate_limit(f"tts:{user.id}", RATE_LIMITS.AI.max_requests, RATE_LIMITS.AI.window_seconds)
    if not rl.success:
        raise HTTPException(status_code=429, detail="요청이 너무 많습니다")

    # Find vocabulary
    result = await db.execute(select(Vocabulary).where(Vocabulary.id == body.id))
    vocab = result.scalar_one_or_none()
    if not vocab:
        raise HTTPException(status_code=404, detail="단어를 찾을 수 없습니다")

    vocab_id_str = str(vocab.id)

    # Check tts_audio table for cached entry
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
        return {"audioUrl": tts_record.audio_url}

    # Legacy fallback: check vocab.audio_url (기존 데이터 호환)
    if vocab.audio_url:
        return {"audioUrl": vocab.audio_url}

    # Prevent duplicate generation
    if vocab_id_str in _generating:
        raise HTTPException(status_code=409, detail="TTS 생성 중입니다. 잠시 후 다시 시도해주세요.")
    _generating.add(vocab_id_str)

    try:
        # Generate TTS
        text = vocab.word
        if vocab.reading and vocab.reading != vocab.word:
            text = vocab.reading  # Use reading for pronunciation

        try:
            tts_result = await generate_tts(text)
        except RuntimeError:
            logger.exception("TTS generation failed for vocab %s, text=%r", vocab_id_str, text)
            raise HTTPException(status_code=502, detail="TTS 음성 생성에 실패했습니다") from None

        # Upload to GCS
        audio_url = await _upload_to_gcs(f"tts/vocab/{vocab_id_str}.mp3", tts_result.audio)

        # Save to tts_audio table
        tts_audio = TtsAudio(
            target_type="vocabulary",
            target_id=vocab_id_str,
            text=text,
            speed=1.0,
            provider=tts_result.provider,
            model=tts_result.model,
            audio_url=audio_url,
            field="reading",
        )
        db.add(tts_audio)

        # Also update legacy column for backward compatibility
        vocab.audio_url = audio_url
        await db.commit()

        return {"audioUrl": audio_url}
    finally:
        _generating.discard(vocab_id_str)


async def _upload_to_gcs(gcs_path: str, mp3_bytes: bytes) -> str:
    """Upload MP3 to Google Cloud Storage and return CDN URL."""
    try:
        from google.cloud import storage

        client = storage.Client()
        bucket = client.bucket(settings.GCS_BUCKET_NAME)
        blob = bucket.blob(gcs_path)
        blob.upload_from_string(mp3_bytes, content_type="audio/mpeg")

        return f"{settings.GCS_CDN_BASE_URL}/{gcs_path}"
    except Exception:
        logger.exception("Failed to upload TTS to GCS for %s", gcs_path)
        raise HTTPException(status_code=500, detail="TTS 파일 업로드에 실패했습니다") from None
