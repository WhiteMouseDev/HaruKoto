from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import effective_jlpt_level
from app.models import StudyStage, UserStudyStageProgress
from app.models.user import User
from app.utils.helpers import enum_value


@dataclass(slots=True)
class StudyStageProgressData:
    best_score: int
    attempts: int
    completed: bool
    completed_at: str | None
    last_attempted_at: str | None


@dataclass(slots=True)
class StudyStageEntryData:
    id: str
    category: str
    jlpt_level: str
    stage_number: int
    title: str
    description: str | None
    content_count: int
    is_locked: bool
    user_progress: StudyStageProgressData | None


async def get_stages_data(
    db: AsyncSession,
    user: User,
    *,
    category: str,
    jlpt_level: str | None,
) -> list[StudyStageEntryData]:
    raw_level = jlpt_level or enum_value(user.jlpt_level)
    level = enum_value(effective_jlpt_level(user.jlpt_level)) if not jlpt_level else raw_level

    stages_result = await db.execute(
        select(StudyStage)
        .where(
            StudyStage.category == category.upper(),
            StudyStage.jlpt_level == level,
        )
        .order_by(StudyStage.order, StudyStage.stage_number)
    )
    stages = stages_result.scalars().all()

    if not stages:
        return []

    stage_ids = [stage.id for stage in stages]
    progress_result = await db.execute(
        select(UserStudyStageProgress).where(
            UserStudyStageProgress.user_id == user.id,
            UserStudyStageProgress.stage_id.in_(stage_ids),
        )
    )
    progress_rows = progress_result.scalars().all()
    progress_map = {str(progress.stage_id): progress for progress in progress_rows}
    completed_stage_ids = {str(progress.stage_id) for progress in progress_rows if progress.completed}

    return [
        StudyStageEntryData(
            id=str(stage.id),
            category=stage.category,
            jlpt_level=enum_value(stage.jlpt_level),
            stage_number=stage.stage_number,
            title=stage.title,
            description=stage.description,
            content_count=len(stage.content_ids) if isinstance(stage.content_ids, list) else 0,
            is_locked=False if stage.unlock_after is None else str(stage.unlock_after) not in completed_stage_ids,
            user_progress=(
                StudyStageProgressData(
                    best_score=progress.best_score or 0,
                    attempts=progress.attempts or 0,
                    completed=bool(progress.completed),
                    completed_at=progress.completed_at.isoformat() if progress.completed_at else None,
                    last_attempted_at=progress.last_attempted_at.isoformat() if progress.last_attempted_at else None,
                )
                if (progress := progress_map.get(str(stage.id)))
                else None
            ),
        )
        for stage in stages
    ]
