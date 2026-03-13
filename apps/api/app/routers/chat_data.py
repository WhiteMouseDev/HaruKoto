from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import (
    AiCharacter,
    Conversation,
    ConversationScenario,
    UserCharacterUnlock,
    UserFavoriteCharacter,
)
from app.models.user import User

router = APIRouter(prefix="/api/v1/chat", tags=["chat-data"])


@router.get("/scenarios")
async def get_scenarios(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ConversationScenario).where(ConversationScenario.is_active.is_(True)).order_by(ConversationScenario.order)
    )
    scenarios = result.scalars().all()
    return [
        {
            "id": str(s.id),
            "title": s.title,
            "titleJa": s.title_ja,
            "description": s.description,
            "category": s.category.value,
            "difficulty": s.difficulty.value,
            "estimatedMinutes": s.estimated_minutes,
            "keyExpressions": s.key_expressions,
            "situation": s.situation,
            "yourRole": s.your_role,
            "aiRole": s.ai_role,
            "order": s.order,
        }
        for s in scenarios
    ]


@router.get("/history")
async def get_history(
    cursor: str | None = None,
    limit: int = Query(default=20, le=30),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Conversation)
        .options(selectinload(Conversation.scenario), selectinload(Conversation.character))
        .where(Conversation.user_id == user.id)
        .order_by(Conversation.created_at.desc())
        .limit(limit + 1)
    )
    if cursor:
        from datetime import datetime

        query = query.where(Conversation.created_at < datetime.fromisoformat(cursor))

    result = await db.execute(query)
    conversations = list(result.scalars().all())

    has_more = len(conversations) > limit
    if has_more:
        conversations = conversations[:limit]

    history = []
    for c in conversations:
        scenario = c.scenario if c.scenario_id else None
        character = c.character if c.character_id else None

        feedback = c.feedback_summary or {}
        history.append(
            {
                "id": str(c.id),
                "type": c.type.value if c.type else "TEXT",
                "createdAt": c.created_at.isoformat(),
                "endedAt": c.ended_at.isoformat() if c.ended_at else None,
                "messageCount": c.message_count,
                "overallScore": feedback.get("overallScore") if isinstance(feedback, dict) else None,
                "scenario": {
                    "title": scenario.title,
                    "titleJa": scenario.title_ja,
                    "category": scenario.category.value,
                    "difficulty": scenario.difficulty.value,
                }
                if scenario
                else None,
                "character": {
                    "id": str(character.id),
                    "name": character.name,
                    "nameJa": character.name_ja,
                    "avatarEmoji": character.avatar_emoji,
                    "avatarUrl": character.avatar_url,
                }
                if character
                else None,
            }
        )

    next_cursor = conversations[-1].created_at.isoformat() if has_more and conversations else None
    return {"history": history, "nextCursor": next_cursor}


@router.get("/characters")
async def get_characters(
    character_id: str | None = Query(default=None, alias="id"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Single character detail
    if character_id:
        char = await db.get(AiCharacter, uuid.UUID(character_id))
        if not char or not char.is_active:
            raise HTTPException(status_code=404, detail="캐릭터를 찾을 수 없습니다")
        return {
            "character": {
                "id": str(char.id),
                "name": char.name,
                "nameJa": char.name_ja,
                "nameRomaji": char.name_romaji,
                "gender": char.gender,
                "ageDescription": char.age_description,
                "description": char.description,
                "relationship": char.relationship,
                "backgroundStory": char.background_story,
                "personality": char.personality,
                "speechStyle": char.speech_style,
                "targetLevel": char.target_level,
                "tier": char.tier,
                "unlockCondition": char.unlock_condition,
                "isDefault": char.is_default,
                "avatarEmoji": char.avatar_emoji,
                "avatarUrl": char.avatar_url,
                "gradient": char.gradient,
                "order": char.order,
                "voiceName": char.voice_name,
                "voiceBackup": char.voice_backup,
                "silenceMs": char.silence_ms,
            }
        }

    # Character list
    result = await db.execute(select(AiCharacter).where(AiCharacter.is_active.is_(True)).order_by(AiCharacter.order))
    characters = result.scalars().all()

    unlocks_result = await db.execute(select(UserCharacterUnlock.character_id).where(UserCharacterUnlock.user_id == user.id))
    unlocked_ids = set(str(uid) for uid in unlocks_result.scalars().all())

    return {
        "characters": [
            {
                "id": str(c.id),
                "name": c.name,
                "nameJa": c.name_ja,
                "nameRomaji": c.name_romaji,
                "gender": c.gender,
                "description": c.description,
                "relationship": c.relationship,
                "speechStyle": c.speech_style,
                "targetLevel": c.target_level,
                "tier": c.tier,
                "unlockCondition": c.unlock_condition,
                "isDefault": c.is_default,
                "avatarEmoji": c.avatar_emoji,
                "avatarUrl": c.avatar_url,
                "gradient": c.gradient,
                "order": c.order,
                "isUnlocked": c.is_default or str(c.id) in unlocked_ids,
            }
            for c in characters
        ]
    }


@router.get("/characters/stats")
async def get_character_stats(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation.character_id, func.count(Conversation.id))
        .where(Conversation.user_id == user.id, Conversation.character_id.isnot(None))
        .group_by(Conversation.character_id)
    )
    stats = {str(row[0]): row[1] for row in result.all()}
    return {"characterStats": stats}


@router.get("/characters/favorites")
async def get_favorite_characters(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(UserFavoriteCharacter.character_id).where(UserFavoriteCharacter.user_id == user.id))
    return {"favoriteIds": [str(cid) for cid in result.scalars().all()]}


@router.post("/characters/favorites")
async def toggle_favorite(
    body: dict,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    character_id = uuid.UUID(body["characterId"])
    existing = await db.execute(
        select(UserFavoriteCharacter).where(
            UserFavoriteCharacter.user_id == user.id,
            UserFavoriteCharacter.character_id == character_id,
        )
    )
    fav = existing.scalar_one_or_none()

    if fav:
        await db.delete(fav)
        await db.commit()
        return {"favorited": False}
    else:
        db.add(UserFavoriteCharacter(user_id=user.id, character_id=character_id))
        await db.commit()
        return {"favorited": True}


@router.get("/{conversation_id}")
async def get_conversation(
    conversation_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await db.get(Conversation, conversation_id)
    if not conv or conv.user_id != user.id:
        raise HTTPException(status_code=404, detail="대화를 찾을 수 없습니다")

    return {
        "id": str(conv.id),
        "messages": conv.messages,
        "feedbackSummary": conv.feedback_summary,
        "messageCount": conv.message_count,
        "type": conv.type.value,
        "createdAt": conv.created_at.isoformat(),
        "endedAt": conv.ended_at.isoformat() if conv.ended_at else None,
    }


@router.delete("/{conversation_id}")
async def delete_conversation(
    conversation_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await db.get(Conversation, conversation_id)
    if not conv or conv.user_id != user.id:
        raise HTTPException(status_code=404, detail="대화를 찾을 수 없습니다")

    await db.delete(conv)
    await db.commit()
    return {"success": True}
