from __future__ import annotations

import hashlib
import logging
import re

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.dependencies import get_current_user
from app.middleware.rate_limit import rate_limit
from app.models.tts import TtsAudio
from app.models.user import User
from app.services.ai import generate_tts
from app.utils.constants import RATE_LIMITS

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/kana", tags=["tts"])

# In-memory set to prevent duplicate concurrent TTS generation
_generating: set[str] = set()

# Regex for Japanese text (hiragana, katakana, kanji, punctuation marks)
_JAPANESE_RE = re.compile(r"^[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\u3000-\u303F\uFF00-\uFFEF]+$")


class KanaTTSRequest(BaseModel):
    text: str

    @field_validator("text")
    @classmethod
    def validate_text(cls, v: str) -> str:
        v = v.strip()
        if not 1 <= len(v) <= 10:
            raise ValueError("텍스트는 1~10자여야 합니다")
        if not _JAPANESE_RE.match(v):
            raise ValueError("일본어 텍스트만 입력 가능합니다")
        return v


@router.post("/tts", status_code=200)
async def kana_tts(
    body: KanaTTSRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    rl = await rate_limit(f"tts:{user.id}", RATE_LIMITS.AI.max_requests, RATE_LIMITS.AI.window_seconds)
    if not rl.success:
        raise HTTPException(status_code=429, detail="요청이 너무 많습니다")

    text_hash = hashlib.md5(body.text.encode()).hexdigest()  # noqa: S324

    # Check tts_audio table for cached entry
    cached = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == "kana",
            TtsAudio.target_id == text_hash,
            TtsAudio.speed == 1.0,
        )
    )
    tts_record = cached.scalar_one_or_none()
    if tts_record:
        return {"audioUrl": tts_record.audio_url}

    # Prevent duplicate generation
    if text_hash in _generating:
        raise HTTPException(status_code=409, detail="TTS 생성 중입니다. 잠시 후 다시 시도해주세요.")
    _generating.add(text_hash)

    try:
        try:
            tts_result = await generate_tts(body.text)
        except RuntimeError:
            logger.exception("TTS generation failed for text=%r", body.text)
            raise HTTPException(status_code=502, detail="TTS 음성 생성에 실패했습니다") from None

        # Upload to GCS
        gcs_path = f"tts/kana/{text_hash}.mp3"
        audio_url = await _upload_to_gcs(gcs_path, tts_result.audio)

        # Save to tts_audio table
        tts_audio = TtsAudio(
            target_type="kana",
            target_id=text_hash,
            text=body.text,
            speed=1.0,
            provider=tts_result.provider,
            model=tts_result.model,
            audio_url=audio_url,
        )
        db.add(tts_audio)
        await db.commit()

        return {"audioUrl": audio_url}
    finally:
        _generating.discard(text_hash)


async def _upload_to_gcs(gcs_path: str, mp3_bytes: bytes) -> str:
    """Upload MP3 to Google Cloud Storage and return CDN URL."""
    try:
        from google.cloud import storage  # type: ignore[import-untyped]

        client = storage.Client()
        bucket = client.bucket(settings.GCS_BUCKET_NAME)
        blob = bucket.blob(gcs_path)
        blob.upload_from_string(mp3_bytes, content_type="audio/mpeg")

        return f"{settings.GCS_CDN_BASE_URL}/{gcs_path}"
    except Exception:
        logger.exception("Failed to upload TTS to GCS for %s", gcs_path)
        raise HTTPException(status_code=500, detail="TTS 파일 업로드에 실패했습니다") from None
