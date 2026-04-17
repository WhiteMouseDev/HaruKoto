from __future__ import annotations

import contextlib
import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, QuizSession, SentenceArrangeQuestion, StudyStage, Vocabulary
from app.models.user import User
from app.schemas.quiz import MatchingPair, QuizOption, QuizQuestion
from app.services.gamification import calculate_level
from app.utils.constants import REWARDS


def extract_questions_data(raw_data: Any) -> list[dict[str, Any]]:
    """Normalize session question payloads into the canonical question list."""
    raw_questions = raw_data.get("questions", []) if isinstance(raw_data, dict) else raw_data or []
    return list(raw_questions)


def build_response_questions(questions: list[dict[str, Any]]) -> list[QuizQuestion]:
    """Convert stored quiz question payloads into API response schemas."""
    response_questions: list[QuizQuestion] = []
    for question in questions:
        response_questions.append(
            QuizQuestion(
                question_id=question["id"],
                question_text=question["question"],
                question_sub_text=question.get("questionSubText"),
                hint=question.get("hint"),
                options=[QuizOption(**option) for option in question["options"]],
                correct_option_id=question.get("correctOptionId"),
                tokens=question.get("tokens"),
                japanese_sentence=question.get("japaneseSentence"),
                explanation=question.get("explanation"),
            )
        )
    return response_questions


def build_session_questions_data(
    questions: list[dict[str, Any]],
    *,
    stage_id: uuid.UUID | None = None,
    mode: str | None = None,
) -> dict[str, Any] | list[dict[str, Any]]:
    """Persist question payloads in the existing shape while attaching metadata when needed."""
    metadata: dict[str, Any] = {}
    if stage_id is not None:
        metadata["stage_id"] = str(stage_id)
    if mode is not None:
        metadata["mode"] = mode

    if not metadata:
        return questions

    return {**metadata, "questions": questions}


async def auto_complete_sessions(db: AsyncSession, user: User) -> int:
    """Auto-complete unfinished sessions and award pending XP to the user."""
    result = await db.execute(
        select(QuizSession).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.is_(None),
        )
    )
    incomplete = result.scalars().all()
    total_xp = 0

    for session in incomplete:
        session.completed_at = datetime.now(UTC)
        xp = session.correct_count * REWARDS.QUIZ_XP_PER_CORRECT
        total_xp += xp

    if total_xp > 0:
        user.experience_points += total_xp
        level_info = calculate_level(user.experience_points)
        user.level = level_info["level"]

    await db.flush()
    return total_xp


async def fetch_stage_content_ids(db: AsyncSession, stage_id: uuid.UUID) -> tuple[StudyStage | None, list[uuid.UUID]]:
    """Fetch a stage and coerce its content ids into UUID values."""
    stage = await db.get(StudyStage, stage_id)
    if not stage:
        return None, []

    raw_ids = stage.content_ids if isinstance(stage.content_ids, list) else []
    content_uuids: list[uuid.UUID] = []
    for content_id in raw_ids:
        with contextlib.suppress(ValueError):
            content_uuids.append(uuid.UUID(str(content_id)))
    return stage, content_uuids


async def generate_matching_pairs(
    db: AsyncSession,
    stage: StudyStage,
    content_uuids: list[uuid.UUID],
    count: int,
) -> tuple[list[dict[str, Any]], list[MatchingPair]]:
    """Generate question payloads and pair data for matching mode."""
    questions: list[dict[str, Any]] = []
    matching_pairs: list[MatchingPair] = []

    if stage.category == "VOCABULARY":
        result = await db.execute(select(Vocabulary).where(Vocabulary.id.in_(content_uuids)).order_by(func.random()).limit(count))
        items = result.scalars().all()
        for vocab in items:
            pair_id = str(uuid.uuid4())
            matching_pairs.append(MatchingPair(id=pair_id, word=vocab.word, meaning=vocab.meaning_ko))
            questions.append(
                {
                    "id": str(vocab.id),
                    "type": "VOCABULARY",
                    "question": vocab.word,
                    "questionSubText": vocab.reading,
                    "options": [],
                    "correctOptionId": pair_id,
                    "word": vocab.word,
                    "meaningKo": vocab.meaning_ko,
                }
            )
    elif stage.category == "GRAMMAR":
        result = await db.execute(select(Grammar).where(Grammar.id.in_(content_uuids)).order_by(func.random()).limit(count))
        items = result.scalars().all()
        for grammar in items:
            pair_id = str(uuid.uuid4())
            matching_pairs.append(MatchingPair(id=pair_id, word=grammar.pattern, meaning=grammar.meaning_ko))
            questions.append(
                {
                    "id": str(grammar.id),
                    "type": "GRAMMAR",
                    "question": grammar.pattern,
                    "options": [],
                    "correctOptionId": pair_id,
                    "pattern": grammar.pattern,
                    "meaningKo": grammar.meaning_ko,
                }
            )
    elif stage.category == "SENTENCE":
        result = await db.execute(
            select(SentenceArrangeQuestion).where(SentenceArrangeQuestion.id.in_(content_uuids)).order_by(func.random()).limit(count)
        )
        items = result.scalars().all()
        for item in items:
            pair_id = str(uuid.uuid4())
            matching_pairs.append(MatchingPair(id=pair_id, word=item.korean_sentence, meaning=item.japanese_sentence))
            questions.append(
                {
                    "id": str(item.id),
                    "type": "SENTENCE_ARRANGE",
                    "question": item.korean_sentence,
                    "options": [],
                    "correctOptionId": pair_id,
                }
            )

    return questions, matching_pairs
