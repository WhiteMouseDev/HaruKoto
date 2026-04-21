from __future__ import annotations

import uuid
from collections.abc import Iterable
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import KanaCharacter, KanaLearningStage, QuizSession
from app.models.enums import KanaType, QuizType
from app.models.user import User
from app.schemas.kana import KanaQuizStartRequest
from app.services.kana_quiz_questions import QuestionPayload, build_kana_quiz_questions, strip_kana_quiz_answers


class KanaQuizStartServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class KanaQuizStartResult:
    session_id: uuid.UUID
    questions: list[dict[str, Any]]
    total_questions: int


async def start_kana_quiz_session(
    db: AsyncSession,
    user: User,
    body: KanaQuizStartRequest,
) -> KanaQuizStartResult:
    characters = await load_kana_quiz_characters(
        db,
        kana_type=body.kana_type,
        stage_number=body.stage_number,
    )
    if not characters:
        raise KanaQuizStartServiceError(status_code=400, detail="가나 문자를 찾을 수 없습니다")

    questions = build_kana_quiz_questions(
        characters,
        count=body.count,
        quiz_mode=body.quiz_mode,
    )
    session = await create_kana_quiz_session(db, user=user, questions=questions)

    return KanaQuizStartResult(
        session_id=session.id,
        questions=strip_kana_quiz_answers(questions),
        total_questions=len(questions),
    )


async def load_kana_quiz_characters(
    db: AsyncSession,
    *,
    kana_type: KanaType,
    stage_number: int | None,
) -> list[KanaCharacter]:
    if stage_number is None:
        chars_result = await db.execute(select(KanaCharacter).where(KanaCharacter.kana_type == kana_type))
        return list(chars_result.scalars().all())

    stages_result = await db.execute(
        select(KanaLearningStage).where(
            KanaLearningStage.kana_type == kana_type,
            KanaLearningStage.stage_number.in_(build_stage_window(stage_number)),
        )
    )
    all_chars_list = collect_stage_characters(stages_result.scalars().all())
    chars_result = await db.execute(
        select(KanaCharacter).where(
            KanaCharacter.kana_type == kana_type,
            KanaCharacter.character.in_(all_chars_list),
        )
    )
    return list(chars_result.scalars().all())


async def create_kana_quiz_session(
    db: AsyncSession,
    *,
    user: User,
    questions: list[QuestionPayload],
) -> QuizSession:
    session = QuizSession(
        user_id=user.id,
        quiz_type=QuizType.KANA,
        jlpt_level=user.jlpt_level,
        total_questions=len(questions),
        questions_data=questions,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session


def build_stage_window(stage_number: int) -> list[int]:
    return [candidate for candidate in [stage_number - 2, stage_number - 1, stage_number] if candidate >= 1]


def collect_stage_characters(stages: Iterable[KanaLearningStage]) -> list[str]:
    characters: list[str] = []
    for stage in stages:
        characters.extend(stage.characters)
    return characters
