from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import QuizSession
from app.models.user import User
from app.schemas.quiz import MatchingPair, QuizStartRequest, SmartStartRequest
from app.services.quiz_mode_questions import (
    load_cloze_questions,
    load_normal_questions,
    load_review_questions,
    load_sentence_arrange_questions,
)
from app.services.quiz_policy import calculate_smart_distribution
from app.services.quiz_resume_snapshot import decode_quiz_resume_snapshot
from app.services.quiz_session import (
    auto_complete_sessions,
    build_session_questions_data,
    fetch_stage_content_ids,
    generate_matching_pairs,
)
from app.services.quiz_smart import load_smart_pool_stats
from app.services.quiz_smart_questions import load_smart_questions


class QuizStartServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class QuizStartResult:
    session: QuizSession
    questions: list[dict[str, Any]]
    matching_pairs: list[MatchingPair] | None = None
    mode: str | None = None


async def _create_quiz_session(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    quiz_type: Any,
    jlpt_level: Any,
    questions: list[dict[str, Any]],
    mode: str | None = None,
    stage_id: uuid.UUID | None = None,
    matching_pairs: list[MatchingPair] | None = None,
) -> QuizSession:
    session = QuizSession(
        user_id=user_id,
        quiz_type=quiz_type,
        jlpt_level=jlpt_level,
        total_questions=len(questions),
        questions_data=build_session_questions_data(questions, mode=mode, stage_id=stage_id, matching_pairs=matching_pairs),
    )
    try:
        db.add(session)
        await db.commit()
        await db.refresh(session)
    except Exception as exc:
        await db.rollback()
        raise QuizStartServiceError(status_code=500, detail="퀴즈 세션 생성에 실패했습니다") from exc
    return session


async def start_quiz_session(
    db: AsyncSession,
    user: User,
    body: QuizStartRequest,
) -> QuizStartResult:
    await auto_complete_sessions(db, user)

    mode = body.mode if body.mode in {"matching", "cloze", "arrange", "review"} else "normal"
    quiz_type = body.quiz_type.value
    jlpt_level = body.jlpt_level.value
    count = body.count

    questions: list[dict[str, Any]] = []
    matching_pairs: list[MatchingPair] | None = None
    stage_content_ids: list[uuid.UUID] = []
    stage = None

    if body.stage_id:
        stage, stage_content_ids = await fetch_stage_content_ids(db, body.stage_id)
        if not stage:
            raise QuizStartServiceError(status_code=404, detail="스테이지를 찾을 수 없습니다")
        if not stage_content_ids:
            raise QuizStartServiceError(status_code=400, detail="스테이지에 콘텐츠가 없습니다")

    if mode == "matching":
        if stage is None and quiz_type not in {"VOCABULARY", "GRAMMAR"}:
            raise QuizStartServiceError(status_code=400, detail="자유 매칭은 단어와 문법에서만 사용할 수 있습니다")
        questions, matching_pairs = await generate_matching_pairs(
            db, stage, stage_content_ids, count, quiz_type=quiz_type, jlpt_level=jlpt_level
        )
    elif mode == "cloze":
        questions = await load_cloze_questions(db, jlpt_level=jlpt_level, count=count, stage_content_ids=stage_content_ids)
    elif mode == "arrange":
        questions = await load_sentence_arrange_questions(db, jlpt_level=jlpt_level, count=count, stage_content_ids=stage_content_ids)
    elif mode == "review":
        questions = await load_review_questions(
            db,
            user_id=user.id,
            quiz_type=quiz_type,
            jlpt_level=jlpt_level,
            count=count,
            stage_content_ids=stage_content_ids,
        )
    else:
        questions = await load_normal_questions(
            db,
            quiz_type=quiz_type,
            jlpt_level=jlpt_level,
            count=count,
            stage_content_ids=stage_content_ids,
        )

    # New special sessions preserve the original rendering snapshot atomically.
    # Keep normal/review/cloze storage shapes compatible with existing readers.
    stored_mode = mode if mode in {"matching", "arrange"} else None
    if stored_mode is not None:
        payload = build_session_questions_data(questions, mode=stored_mode, stage_id=body.stage_id, matching_pairs=matching_pairs)
        if decode_quiz_resume_snapshot(payload, total_questions=len(questions), quiz_type=quiz_type).status != "available":
            raise QuizStartServiceError(status_code=400, detail="퀴즈의 표시 정보를 안전하게 준비할 수 없습니다")
    session = await _create_quiz_session(
        db,
        user_id=user.id,
        quiz_type=body.quiz_type,
        jlpt_level=body.jlpt_level,
        questions=questions,
        stage_id=body.stage_id,
        mode=stored_mode,
        matching_pairs=matching_pairs,
    )
    return QuizStartResult(session=session, questions=questions, matching_pairs=matching_pairs, mode=mode)


async def start_smart_quiz_session(
    db: AsyncSession,
    user: User,
    body: SmartStartRequest,
) -> QuizStartResult:
    await auto_complete_sessions(db, user)

    now = datetime.now(UTC)
    category = body.category
    jlpt_level = body.jlpt_level.value
    pool_stats = await load_smart_pool_stats(
        db,
        user_id=user.id,
        category=category,
        jlpt_level=jlpt_level,
        now=now,
    )
    distribution = calculate_smart_distribution(body.count, pool_stats.review_due, pool_stats.retry_due)
    questions = await load_smart_questions(
        db,
        user_id=user.id,
        category=category,
        jlpt_level=jlpt_level,
        distribution=distribution,
        now=now,
    )

    if not questions:
        raise QuizStartServiceError(status_code=400, detail="학습할 콘텐츠가 없습니다")

    session = await _create_quiz_session(
        db,
        user_id=user.id,
        quiz_type=body.category,
        jlpt_level=body.jlpt_level,
        questions=questions,
        mode="smart",
    )
    return QuizStartResult(session=session, questions=questions, matching_pairs=None, mode="smart")
