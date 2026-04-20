from __future__ import annotations

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import ClozeQuestion, SentenceArrangeQuestion
from app.services.quiz_question_builder import QuestionPayload, build_cloze_question, build_sentence_arrange_question


async def load_cloze_questions(
    db: AsyncSession,
    *,
    jlpt_level: str,
    count: int,
    stage_content_ids: list[uuid.UUID],
) -> list[QuestionPayload]:
    query = select(ClozeQuestion).where(ClozeQuestion.jlpt_level == jlpt_level)
    if stage_content_ids:
        query = query.where(ClozeQuestion.id.in_(stage_content_ids))
    result = await db.execute(query.order_by(func.random()).limit(count))
    return [build_cloze_question(item) for item in result.scalars().all()]


async def load_sentence_arrange_questions(
    db: AsyncSession,
    *,
    jlpt_level: str,
    count: int,
    stage_content_ids: list[uuid.UUID],
) -> list[QuestionPayload]:
    query = select(SentenceArrangeQuestion).where(SentenceArrangeQuestion.jlpt_level == jlpt_level)
    if stage_content_ids:
        query = query.where(SentenceArrangeQuestion.id.in_(stage_content_ids))
    result = await db.execute(query.order_by(func.random()).limit(count))
    return [build_sentence_arrange_question(item) for item in result.scalars().all()]
