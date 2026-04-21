from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.middleware.rate_limit import rate_limit
from app.models.user import User
from app.services.ai import generate_tts
from app.services.tts_storage import upload_tts_to_gcs
from app.services.vocab_tts import VocabTtsServiceError, generate_vocabulary_tts
from app.utils.constants import RATE_LIMITS

router = APIRouter(prefix="/api/v1/vocab", tags=["tts"])


class VocabTTSRequest(BaseModel):
    id: str


@router.post("/tts", status_code=200)
async def vocab_tts(
    body: VocabTTSRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    rl = await rate_limit(f"tts:{user.id}", RATE_LIMITS.AI.max_requests, RATE_LIMITS.AI.window_seconds)
    if not rl.success:
        raise HTTPException(status_code=429, detail="요청이 너무 많습니다")

    try:
        result = await generate_vocabulary_tts(
            db,
            vocabulary_id=body.id,
            tts_generator=generate_tts,
            upload_to_gcs=upload_tts_to_gcs,
        )
    except VocabTtsServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return {"audioUrl": result.audio_url}
