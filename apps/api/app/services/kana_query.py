from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import KanaCharacter, KanaLearningStage, UserKanaProgress, UserKanaStage
from app.models.enums import KanaType
from app.schemas.kana import KanaProgressResponse, KanaStat

FIRST_STAGE_NUMBER = 1


async def get_kana_characters_data(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    kana_type: KanaType | None = None,
    category: str | None = None,
) -> list[dict[str, Any]]:
    query = select(KanaCharacter).order_by(KanaCharacter.order)
    if kana_type:
        query = query.where(KanaCharacter.kana_type == kana_type)
    if category:
        query = query.where(KanaCharacter.category == category)
    result = await db.execute(query)
    characters = result.scalars().all()

    progress_result = await db.execute(select(UserKanaProgress).where(UserKanaProgress.user_id == user_id))
    progress_map: dict[str, UserKanaProgress] = {str(progress.kana_id): progress for progress in progress_result.scalars().all()}

    return [build_kana_character_payload(character, progress_map.get(str(character.id))) for character in characters]


async def get_kana_stages_data(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    kana_type: KanaType | None = None,
) -> list[dict[str, Any]]:
    query = select(KanaLearningStage).order_by(KanaLearningStage.order)
    if kana_type:
        query = query.where(KanaLearningStage.kana_type == kana_type)
    result = await db.execute(query)
    stages = result.scalars().all()

    stage_progress_result = await db.execute(select(UserKanaStage).where(UserKanaStage.user_id == user_id))
    user_stages = {str(user_stage.stage_id): user_stage for user_stage in stage_progress_result.scalars().all()}

    return [build_kana_stage_payload(stage, user_stages.get(str(stage.id))) for stage in stages]


async def get_kana_progress_data(db: AsyncSession, *, user_id: uuid.UUID) -> KanaProgressResponse:
    total_result = await db.execute(select(KanaCharacter.kana_type, func.count(KanaCharacter.id)).group_by(KanaCharacter.kana_type))
    totals = {row[0]: row[1] for row in total_result.all()}

    learned_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter, KanaCharacter.id == UserKanaProgress.kana_id)
        .where(UserKanaProgress.user_id == user_id)
        .group_by(KanaCharacter.kana_type)
    )
    learned_map = {row[0]: row[1] for row in learned_result.all()}

    mastered_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter, KanaCharacter.id == UserKanaProgress.kana_id)
        .where(UserKanaProgress.user_id == user_id, UserKanaProgress.mastered.is_(True))
        .group_by(KanaCharacter.kana_type)
    )
    mastered_map = {row[0]: row[1] for row in mastered_result.all()}

    return build_kana_progress_response(totals=totals, learned_map=learned_map, mastered_map=mastered_map)


def build_kana_character_payload(character: KanaCharacter, progress: UserKanaProgress | None) -> dict[str, Any]:
    return {
        "id": str(character.id),
        "kanaType": character.kana_type.value,
        "character": character.character,
        "romaji": character.romaji,
        "pronunciation": character.pronunciation,
        "row": character.row,
        "column": character.column,
        "strokeCount": character.stroke_count,
        "strokeOrder": character.stroke_order,
        "audioUrl": character.audio_url,
        "exampleWord": character.example_word,
        "exampleReading": character.example_reading,
        "exampleMeaning": character.example_meaning,
        "category": character.category,
        "order": character.order,
        "progress": build_kana_character_progress_payload(progress),
    }


def build_kana_character_progress_payload(progress: UserKanaProgress | None) -> dict[str, Any] | None:
    if progress is None:
        return None

    return {
        "correctCount": progress.correct_count,
        "streak": progress.streak,
        "mastered": progress.mastered,
        "lastReviewedAt": progress.last_reviewed_at.isoformat() if progress.last_reviewed_at else None,
    }


def build_kana_stage_payload(stage: KanaLearningStage, user_stage: UserKanaStage | None) -> dict[str, Any]:
    return {
        "id": str(stage.id),
        "kanaType": stage.kana_type.value,
        "stageNumber": stage.stage_number,
        "title": stage.title,
        "description": stage.description,
        "characters": stage.characters,
        "isUnlocked": user_stage.is_unlocked if user_stage else (stage.stage_number == FIRST_STAGE_NUMBER),
        "isCompleted": user_stage.is_completed if user_stage else False,
        "quizScore": user_stage.quiz_score if user_stage else None,
    }


def build_kana_progress_response(
    *,
    totals: dict[KanaType, int],
    learned_map: dict[KanaType, int],
    mastered_map: dict[KanaType, int],
) -> KanaProgressResponse:
    return KanaProgressResponse(
        hiragana=build_kana_stat(KanaType.HIRAGANA, totals=totals, learned_map=learned_map, mastered_map=mastered_map),
        katakana=build_kana_stat(KanaType.KATAKANA, totals=totals, learned_map=learned_map, mastered_map=mastered_map),
    )


def build_kana_stat(
    kana_type: KanaType,
    *,
    totals: dict[KanaType, int],
    learned_map: dict[KanaType, int],
    mastered_map: dict[KanaType, int],
) -> KanaStat:
    return KanaStat(
        learned=learned_map.get(kana_type, 0),
        mastered=mastered_map.get(kana_type, 0),
        total=totals.get(kana_type, 0),
    )
