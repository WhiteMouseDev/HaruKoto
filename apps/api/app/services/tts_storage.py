from __future__ import annotations

import logging

from fastapi import HTTPException

from app.config import settings

logger = logging.getLogger(__name__)


async def upload_tts_to_gcs(gcs_path: str, mp3_bytes: bytes) -> str:
    """Upload MP3 bytes to GCS and return the configured CDN URL."""
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
