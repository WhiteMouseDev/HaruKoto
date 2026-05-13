from __future__ import annotations

import argparse
import asyncio
import logging
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from httpx import ASGITransport, AsyncClient
from sqlalchemy import String, delete, select, text

from app.db.session import async_session_factory
from app.dependencies import get_current_user
from app.main import app
from app.models.enums import JlptLevel
from app.models.lesson import Lesson, UserLessonProgress
from app.models.user import User

SMOKE_NAMESPACE = uuid.UUID("2dd88964-0b4f-4956-a30c-3f81125b9870")


@dataclass(frozen=True)
class LessonTarget:
    jlpt_level: str
    lesson_no: int
    label: str


@dataclass(frozen=True)
class FlowResult:
    start_status_code: int
    start_status: str | None
    submit_status_code: int
    score_correct: int | None
    score_total: int | None
    status: str | None
    result_count: int
    srs_items_registered: int | None


def _smoke_user_id(target: LessonTarget, mode: str) -> uuid.UUID:
    return uuid.uuid5(
        SMOKE_NAMESPACE,
        f"{target.jlpt_level}:{target.lesson_no}:{target.label}:{mode}",
    )


def _smoke_email(target: LessonTarget, mode: str) -> str:
    safe_label = target.label.lower().replace("_", "-")
    return f"codex-smoke-{safe_label}-{mode}@example.invalid"


def _answer_for(question: dict[str, Any], *, correct: bool) -> dict[str, Any]:
    if question.get("type") == "SENTENCE_REORDER":
        correct_order = list(question["correct_order"])
        submitted_order = correct_order if correct else list(reversed(correct_order))
        if not correct and submitted_order == correct_order:
            submitted_order = ["__wrong__", *correct_order]
        return {
            "order": question["order"],
            "submittedOrder": submitted_order,
            "responseMs": 900,
        }

    correct_answer = question["correct_answer"]
    selected_answer = correct_answer
    if not correct:
        selected_answer = "__wrong__"
        for option in question.get("options", []):
            option_id = option.get("id")
            if option_id and option_id != correct_answer:
                selected_answer = option_id
                break

    return {
        "order": question["order"],
        "selectedAnswer": selected_answer,
        "responseMs": 900,
    }


async def _cleanup_smoke_users(user_ids: list[uuid.UUID]) -> None:
    async with async_session_factory() as session:
        await session.execute(
            text("DELETE FROM review_events WHERE user_id = ANY(:user_ids)"),
            {"user_ids": user_ids},
        )
        await session.execute(delete(User).where(User.id.in_(user_ids)))
        await session.commit()


async def _create_smoke_user(user_id: uuid.UUID, email: str, jlpt_level: str) -> User:
    now = datetime.now(UTC)
    async with async_session_factory() as session:
        user = User(
            id=user_id,
            email=email,
            nickname="Codex Lesson API Smoke",
            jlpt_level=JlptLevel(jlpt_level),
            created_at=now,
            updated_at=now,
        )
        session.add(user)
        await session.commit()
        return user


async def _load_lesson(target: LessonTarget) -> tuple[uuid.UUID, list[dict[str, Any]], bool]:
    async with async_session_factory() as session:
        result = await session.execute(
            select(Lesson.id, Lesson.content_jsonb, Lesson.is_published).where(
                Lesson.jlpt_level.cast(String) == target.jlpt_level,
                Lesson.lesson_no == target.lesson_no,
            )
        )
        lesson_id, content, is_published = result.one()
        return lesson_id, content["questions"], is_published


async def _schema_probe() -> tuple[str, str | None]:
    async with async_session_factory() as session:
        result = await session.execute(
            text("""
                SELECT is_nullable, column_default
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'users'
                  AND column_name = 'updated_at'
            """)
        )
        row = result.one()
    return row.is_nullable, row.column_default


async def _run_flow(
    *,
    user: User,
    lesson_id: uuid.UUID,
    questions: list[dict[str, Any]],
    correct: bool,
) -> FlowResult:
    async def override_get_current_user() -> User:
        return user

    app.dependency_overrides[get_current_user] = override_get_current_user
    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            start_response = await client.post(f"/api/v1/lessons/{lesson_id}/start")
            submit_response = await client.post(
                f"/api/v1/lessons/{lesson_id}/submit",
                json={"answers": [_answer_for(question, correct=correct) for question in questions]},
            )
    finally:
        app.dependency_overrides.pop(get_current_user, None)

    start_json = start_response.json()
    submit_json = submit_response.json()
    if start_response.status_code != 200:
        msg = f"start failed: {start_response.status_code} {start_json}"
        raise RuntimeError(msg)
    if submit_response.status_code != 200:
        msg = f"submit failed: {submit_response.status_code} {submit_json}"
        raise RuntimeError(msg)

    return FlowResult(
        start_status_code=start_response.status_code,
        start_status=start_json.get("status"),
        submit_status_code=submit_response.status_code,
        score_correct=submit_json.get("scoreCorrect"),
        score_total=submit_json.get("scoreTotal"),
        status=submit_json.get("status"),
        result_count=len(submit_json.get("results", [])),
        srs_items_registered=submit_json.get("srsItemsRegistered"),
    )


async def _progress_summary(user_id: uuid.UUID, lesson_id: uuid.UUID) -> tuple[str, int, int, int, bool]:
    async with async_session_factory() as session:
        result = await session.execute(
            select(
                UserLessonProgress.status,
                UserLessonProgress.attempts,
                UserLessonProgress.score_correct,
                UserLessonProgress.score_total,
                UserLessonProgress.srs_registered_at.is_not(None),
            ).where(
                UserLessonProgress.user_id == user_id,
                UserLessonProgress.lesson_id == lesson_id,
            )
        )
        status, attempts, score_correct, score_total, has_srs_registered_at = result.one()
        return (
            status,
            attempts,
            score_correct,
            score_total,
            has_srs_registered_at,
        )


async def run_smoke(target: LessonTarget) -> None:
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

    correct_user_id = _smoke_user_id(target, "correct")
    wrong_user_id = _smoke_user_id(target, "wrong")
    user_ids = [correct_user_id, wrong_user_id]

    nullable, default = await _schema_probe()
    await _cleanup_smoke_users(user_ids)

    lesson_id, questions, is_published = await _load_lesson(target)
    correct_user = await _create_smoke_user(correct_user_id, _smoke_email(target, "correct"), target.jlpt_level)
    wrong_user = await _create_smoke_user(wrong_user_id, _smoke_email(target, "wrong"), target.jlpt_level)

    try:
        correct_result = await _run_flow(
            user=correct_user,
            lesson_id=lesson_id,
            questions=questions,
            correct=True,
        )
        wrong_result = await _run_flow(
            user=wrong_user,
            lesson_id=lesson_id,
            questions=questions,
            correct=False,
        )
        correct_progress = await _progress_summary(correct_user_id, lesson_id)
        wrong_progress = await _progress_summary(wrong_user_id, lesson_id)

        if correct_result.score_correct != correct_result.score_total:
            msg = "correct flow did not score 100%"
            raise RuntimeError(msg)
        if wrong_result.score_correct is None or wrong_result.score_total is None:
            msg = "wrong flow response omitted score fields"
            raise RuntimeError(msg)
        if wrong_result.score_correct >= wrong_result.score_total:
            msg = "wrong flow did not produce a lower-than-total score"
            raise RuntimeError(msg)

        print(f"target {target.label} {target.jlpt_level} lesson_no={target.lesson_no}")
        print(f"users.updated_at nullable={nullable} default={default}")
        print(f"lesson_published {is_published}")
        print(f"question_count {len(questions)}")
        print(f"correct_flow {correct_result}")
        print(f"wrong_flow {wrong_result}")
        print(f"correct_progress {correct_progress}")
        print(f"wrong_progress {wrong_progress}")
    finally:
        await _cleanup_smoke_users(user_ids)
        print("smoke_users_cleaned True")


def parse_args() -> LessonTarget:
    parser = argparse.ArgumentParser(description="Run a local ASGI lesson start/submit smoke against the configured DB.")
    parser.add_argument("--level", default="N4", help="JLPT level, for example N4")
    parser.add_argument("--lesson-no", type=int, default=11, help="Lesson number inside the JLPT level")
    parser.add_argument("--label", default="HN4-011", help="Human-readable lesson label for output and smoke user IDs")
    args = parser.parse_args()
    return LessonTarget(
        jlpt_level=args.level.upper(),
        lesson_no=args.lesson_no,
        label=args.label,
    )


if __name__ == "__main__":
    asyncio.run(run_smoke(parse_args()))
