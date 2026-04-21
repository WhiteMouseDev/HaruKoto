from __future__ import annotations

import re

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.middleware.rate_limit import rate_limit
from app.models.user import User
from app.services.ai import generate_tts
from app.services.kana_tts import KanaTtsServiceError, generate_kana_tts
from app.services.tts_storage import upload_tts_to_gcs
from app.utils.constants import RATE_LIMITS

router = APIRouter(prefix="/api/v1/kana", tags=["tts"])

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

    try:
        result = await generate_kana_tts(
            db,
            text=body.text,
            tts_generator=generate_tts,
            upload_to_gcs=upload_tts_to_gcs,
        )
    except KanaTtsServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return {"audioUrl": result.audio_url}
