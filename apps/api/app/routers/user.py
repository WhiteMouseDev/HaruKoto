from __future__ import annotations

import logging
from typing import Annotated, Any

import httpx
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import DailyProgress, QuizSession, UserAchievement, UserVocabProgress
from app.models.user import User
from app.schemas.common import CamelModel
from app.schemas.user import (
    AchievementItem,
    LevelProgressInfo,
    UserProfile,
    UserProfileUpdate,
    UserSummary,
)
from app.services.gamification import calculate_level

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/user", tags=["user"])

MAX_AVATAR_FILE_SIZE = 5 * 1024 * 1024  # 5MB


class UserProfileResponse(CamelModel):
    profile: UserProfile
    summary: UserSummary
    achievements: list[AchievementItem]


class AvatarUpdateRequest(BaseModel):
    avatar_url: str


class AccountUpdateRequest(CamelModel):
    nickname: str | None = None
    email: str | None = None


@router.get("/profile", response_model=UserProfileResponse, status_code=200)
async def get_profile(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    counts_query = select(
        select(func.count()).select_from(UserVocabProgress).where(UserVocabProgress.user_id == user.id).correlate(None).scalar_subquery().label("total_words"),
        select(func.count()).select_from(QuizSession).where(QuizSession.user_id == user.id, QuizSession.completed_at.isnot(None)).correlate(None).scalar_subquery().label("total_quizzes"),
        select(func.count()).select_from(DailyProgress).where(DailyProgress.user_id == user.id).correlate(None).scalar_subquery().label("total_study_days"),
    )
    counts = (await db.execute(counts_query)).one()
    total_words = counts.total_words
    total_quizzes = counts.total_quizzes
    total_study_days = counts.total_study_days

    achievement_rows = (await db.execute(select(UserAchievement).where(UserAchievement.user_id == user.id))).scalars().all()

    achievements = [
        AchievementItem(
            achievement_type=a.achievement_type,
            achieved_at=a.achieved_at,
        )
        for a in achievement_rows
    ]

    level_info = calculate_level(user.experience_points)
    profile = UserProfile.model_validate(user)
    profile.level_progress = LevelProgressInfo(
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
    )

    return UserProfileResponse(
        profile=profile,
        summary=UserSummary(
            total_words_studied=total_words,
            total_quizzes_completed=total_quizzes,
            total_study_days=total_study_days,
            total_xp_earned=user.experience_points,
        ),
        achievements=achievements,
    )


@router.patch("/profile", response_model=UserProfile, status_code=200)
async def update_profile(
    body: UserProfileUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    update_data = body.model_dump(exclude_unset=True)

    # Merge call_settings instead of overwriting
    if "call_settings" in update_data and update_data["call_settings"] is not None:
        existing = user.call_settings or {}
        existing.update(update_data["call_settings"])
        update_data["call_settings"] = existing

    # Validate and merge app_settings (flat dict only, no nested objects)
    if "app_settings" in update_data and update_data["app_settings"] is not None:
        new_settings = update_data["app_settings"]
        for key, value in new_settings.items():
            if isinstance(value, (dict, list)):
                raise HTTPException(
                    status_code=400,
                    detail=f"app_settings must be a flat dict. Nested value found for key '{key}'.",
                )
        existing_settings = user.app_settings or {}
        existing_settings.update(new_settings)
        update_data["app_settings"] = existing_settings

    for field, value in update_data.items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)

    level_info = calculate_level(user.experience_points)
    profile = UserProfile.model_validate(user)
    profile.level_progress = LevelProgressInfo(
        current_xp=level_info["current_xp"],
        xp_for_next=level_info["xp_for_next"],
    )
    return profile


@router.post("/avatar", status_code=200)
async def upload_avatar(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload avatar image to GCS and update user profile."""
    if file.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(status_code=400, detail="지원하지 않는 이미지 형식입니다. JPEG, PNG, WEBP만 가능합니다.")

    # Check Content-Length header first to reject early without reading
    if file.size and file.size > MAX_AVATAR_FILE_SIZE:
        raise HTTPException(status_code=400, detail="파일 크기는 5MB 이하여야 합니다.")

    content = await file.read()
    if len(content) > MAX_AVATAR_FILE_SIZE:
        raise HTTPException(status_code=400, detail="파일 크기는 5MB 이하여야 합니다.")

    ext = file.content_type.split("/")[-1]
    if ext == "jpeg":
        ext = "jpg"
    file_path = f"avatars/{user.id}.{ext}"

    try:
        from google.cloud import storage

        client = storage.Client()
        bucket = client.bucket(settings.GCS_BUCKET_NAME)
        blob = bucket.blob(file_path)
        blob.upload_from_string(content, content_type=file.content_type)
        blob.make_public()
        avatar_url = f"{settings.GCS_CDN_BASE_URL}/{file_path}"
    except Exception:
        logger.exception("Failed to upload avatar to GCS for user %s", user.id)
        raise HTTPException(status_code=500, detail="아바타 업로드에 실패했습니다") from None

    user.avatar_url = avatar_url
    await db.commit()
    await db.refresh(user)

    return {"avatarUrl": avatar_url}


@router.patch("/avatar", response_model=dict, status_code=200)
async def update_avatar(
    body: AvatarUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    user.avatar_url = body.avatar_url
    await db.commit()
    await db.refresh(user)
    return {"avatarUrl": user.avatar_url}


@router.delete("/account", status_code=200)
async def delete_account(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Delete user account: GCS avatar, DB cascade, Supabase Auth."""
    # 1. Delete GCS avatar (best-effort)
    if user.avatar_url:
        try:
            from google.cloud import storage

            client = storage.Client()
            bucket = client.bucket(settings.GCS_BUCKET_NAME)
            # Extract blob path from URL
            prefix = f"{settings.GCS_CDN_BASE_URL}/"
            if user.avatar_url.startswith(prefix):
                blob_path = user.avatar_url[len(prefix) :]
                blob = bucket.blob(blob_path)
                blob.delete()
        except Exception:
            logger.warning("Failed to delete GCS avatar for user %s", user.id, exc_info=True)

    # 2. Delete user from DB (CASCADE will remove related records)
    await db.delete(user)
    await db.commit()

    # 3. Delete from Supabase Auth (best-effort)
    if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
        try:
            async with httpx.AsyncClient() as client:
                await client.delete(
                    f"{settings.SUPABASE_URL}/auth/v1/admin/users/{user.id}",
                    headers={
                        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
                        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
                    },
                )
        except Exception:
            logger.warning("Failed to delete Supabase auth user %s", user.id, exc_info=True)

    return {"ok": True}


@router.patch("/account", response_model=dict, status_code=200)
async def update_account(
    body: AccountUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)

    result: dict[str, Any] = {}
    if "nickname" in update_data:
        result["nickname"] = user.nickname
    if "email" in update_data:
        result["email"] = user.email
    return result
