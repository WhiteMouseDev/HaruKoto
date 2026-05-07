from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.middleware.rate_limit import rate_limit
from app.models.user import User
from app.services.ai import generate_tts
from app.services.kana_tts import KanaTtsServiceError, generate_kana_tts
from app.services.tts_storage import upload_tts_to_gcs
from app.services.tts_target_resolver import TtsTargetResolverError, resolve_kana_tts_text
from app.utils.constants import RATE_LIMITS

router = APIRouter(prefix="/api/v1/kana", tags=["tts"])


class KanaTTSRequest(BaseModel):
    text: str


@router.post("/tts", status_code=200)
async def kana_tts(
    body: KanaTTSRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    try:
        text = resolve_kana_tts_text(body.text)
    except TtsTargetResolverError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    rl = await rate_limit(f"tts:{user.id}", RATE_LIMITS.AI.max_requests, RATE_LIMITS.AI.window_seconds)
    if not rl.success:
        raise HTTPException(status_code=429, detail="요청이 너무 많습니다")

    try:
        result = await generate_kana_tts(
            db,
            text=text,
            tts_generator=generate_tts,
            upload_to_gcs=upload_tts_to_gcs,
        )
    except KanaTtsServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return {"audioUrl": result.audio_url}
