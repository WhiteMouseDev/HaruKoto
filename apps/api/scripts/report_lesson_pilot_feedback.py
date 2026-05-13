from __future__ import annotations

import argparse
import asyncio
import json
import logging
import uuid
from dataclasses import asdict, dataclass
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import String, select, text

from app.db.session import async_session_factory, engine
from app.models.lesson import Lesson
from app.models.tts import TtsAudio
from app.services.tts_target_resolver import (
    LESSON_QUESTION_PROMPT_TTS_FIELD,
    LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE,
    LESSON_SCRIPT_LINE_TTS_FIELD,
    LESSON_SCRIPT_LINE_TTS_TARGET_TYPE,
)


@dataclass(frozen=True)
class LessonTarget:
    jlpt_level: str
    lesson_no: int
    label: str


@dataclass(frozen=True)
class LessonSnapshot:
    lesson_id: str
    title: str
    topic: str
    is_published: bool
    script_line_count: int
    question_count: int


@dataclass(frozen=True)
class ProgressSnapshot:
    total_users: int
    completed_users: int
    in_progress_users: int
    not_started_users: int
    perfect_scores: int
    non_perfect_scores: int
    total_attempts: int
    max_attempts: int
    average_score_percent: float | None
    first_started_at: str | None
    last_completed_at: str | None
    last_updated_at: str | None


@dataclass(frozen=True)
class ReviewEventSnapshot:
    total_events: int
    correct_events: int
    incorrect_events: int
    average_response_ms: int | None
    first_event_at: str | None
    last_event_at: str | None
    item_type_counts: dict[str, int]


@dataclass(frozen=True)
class TtsSnapshot:
    expected_script_line_records: int
    generated_script_line_records: int
    missing_script_line_indices: list[int]
    provider_model_counts: dict[str, int]
    expected_question_prompt_targets: int
    generated_question_prompt_records: int
    missing_question_prompt_orders: list[int]


@dataclass(frozen=True)
class PilotFeedbackReport:
    generated_at: str
    since: str
    target: LessonTarget
    lesson: LessonSnapshot
    progress: ProgressSnapshot
    review_events: ReviewEventSnapshot
    tts: TtsSnapshot
    signals: list[str]
    blockers: list[str]


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _iso(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


def _score_percent(correct: float | None, total: float | None) -> float | None:
    if correct is None or total in (None, 0):
        return None
    return round(correct / total * 100, 1)


def _script_lines(content: dict[str, Any]) -> list[dict[str, Any]]:
    reading = content.get("reading")
    if not isinstance(reading, dict):
        return []
    script = reading.get("script")
    if not isinstance(script, list):
        return []
    return [line for line in script if isinstance(line, dict)]


def _questions(content: dict[str, Any]) -> list[dict[str, Any]]:
    questions = content.get("questions")
    if not isinstance(questions, list):
        return []
    return [question for question in questions if isinstance(question, dict)]


async def _load_lesson(target: LessonTarget) -> tuple[Lesson, list[dict[str, Any]], list[dict[str, Any]]]:
    async with async_session_factory() as session:
        result = await session.execute(
            select(Lesson).where(
                Lesson.jlpt_level.cast(String) == target.jlpt_level,
                Lesson.lesson_no == target.lesson_no,
            )
        )
        lesson = result.scalar_one_or_none()
        if lesson is None:
            msg = f"lesson not found: level={target.jlpt_level} lesson_no={target.lesson_no}"
            raise RuntimeError(msg)
        content = lesson.content_jsonb or {}
        return lesson, _script_lines(content), _questions(content)


async def _progress_snapshot(lesson_id: uuid.UUID, since: datetime, *, include_smoke: bool) -> ProgressSnapshot:
    smoke_filter = "" if include_smoke else "AND users.email NOT LIKE 'codex-smoke-%@example.invalid'"
    async with async_session_factory() as session:
        result = await session.execute(
            text(f"""
                SELECT
                    COUNT(*) AS total_users,
                    COUNT(*) FILTER (WHERE ulp.status = 'COMPLETED') AS completed_users,
                    COUNT(*) FILTER (WHERE ulp.status = 'IN_PROGRESS') AS in_progress_users,
                    COUNT(*) FILTER (WHERE ulp.status = 'NOT_STARTED') AS not_started_users,
                    COUNT(*) FILTER (WHERE ulp.score_total > 0 AND ulp.score_correct = ulp.score_total) AS perfect_scores,
                    COUNT(*) FILTER (WHERE ulp.score_total > 0 AND ulp.score_correct < ulp.score_total) AS non_perfect_scores,
                    COALESCE(SUM(ulp.attempts), 0) AS total_attempts,
                    COALESCE(MAX(ulp.attempts), 0) AS max_attempts,
                    AVG(ulp.score_correct::float / NULLIF(ulp.score_total, 0)) AS average_score_ratio,
                    MIN(ulp.started_at) AS first_started_at,
                    MAX(ulp.completed_at) AS last_completed_at,
                    MAX(ulp.updated_at) AS last_updated_at
                FROM user_lesson_progress ulp
                JOIN users ON users.id = ulp.user_id
                WHERE ulp.lesson_id = :lesson_id
                  AND COALESCE(ulp.updated_at, ulp.completed_at, ulp.started_at, ulp.created_at) >= :since
                  {smoke_filter}
            """),
            {"lesson_id": lesson_id, "since": since},
        )
        row = result.one()

    average_ratio = row.average_score_ratio
    average_score_percent = None if average_ratio is None else round(float(average_ratio) * 100, 1)
    return ProgressSnapshot(
        total_users=int(row.total_users),
        completed_users=int(row.completed_users),
        in_progress_users=int(row.in_progress_users),
        not_started_users=int(row.not_started_users),
        perfect_scores=int(row.perfect_scores),
        non_perfect_scores=int(row.non_perfect_scores),
        total_attempts=int(row.total_attempts),
        max_attempts=int(row.max_attempts),
        average_score_percent=average_score_percent,
        first_started_at=_iso(row.first_started_at),
        last_completed_at=_iso(row.last_completed_at),
        last_updated_at=_iso(row.last_updated_at),
    )


async def _review_event_snapshot(lesson_id: uuid.UUID, since: datetime, *, include_smoke: bool) -> ReviewEventSnapshot:
    smoke_filter = "" if include_smoke else "AND users.email NOT LIKE 'codex-smoke-%@example.invalid'"
    async with async_session_factory() as session:
        result = await session.execute(
            text(f"""
                SELECT
                    COUNT(*) AS total_events,
                    COUNT(*) FILTER (WHERE re.is_correct IS TRUE) AS correct_events,
                    COUNT(*) FILTER (WHERE re.is_correct IS FALSE) AS incorrect_events,
                    AVG(re.response_ms) AS average_response_ms,
                    MIN(re.created_at) AS first_event_at,
                    MAX(re.created_at) AS last_event_at
                FROM review_events re
                JOIN users ON users.id = re.user_id
                WHERE re.lesson_id = :lesson_id
                  AND re.created_at >= :since
                  {smoke_filter}
            """),
            {"lesson_id": lesson_id, "since": since},
        )
        row = result.one()
        item_result = await session.execute(
            text(f"""
                SELECT re.item_type, COUNT(*) AS count
                FROM review_events re
                JOIN users ON users.id = re.user_id
                WHERE re.lesson_id = :lesson_id
                  AND re.created_at >= :since
                  {smoke_filter}
                GROUP BY re.item_type
                ORDER BY re.item_type
            """),
            {"lesson_id": lesson_id, "since": since},
        )
        item_type_counts = {str(item_row.item_type): int(item_row.count) for item_row in item_result}

    average_response_ms = None if row.average_response_ms is None else round(float(row.average_response_ms))
    return ReviewEventSnapshot(
        total_events=int(row.total_events),
        correct_events=int(row.correct_events),
        incorrect_events=int(row.incorrect_events),
        average_response_ms=average_response_ms,
        first_event_at=_iso(row.first_event_at),
        last_event_at=_iso(row.last_event_at),
        item_type_counts=item_type_counts,
    )


async def _tts_snapshot(lesson_id: uuid.UUID, script_line_count: int, question_count: int) -> TtsSnapshot:
    script_target_ids = [f"{lesson_id}:script:{index}" for index in range(script_line_count)]
    question_target_ids = [f"{lesson_id}:question:{order}" for order in range(1, question_count + 1)]
    async with async_session_factory() as session:
        generated_indices: set[int] = set()
        generated_question_orders: set[int] = set()
        provider_model_counts: dict[str, int] = {}
        if script_target_ids:
            result = await session.execute(
                select(TtsAudio.target_id, TtsAudio.provider, TtsAudio.model).where(
                    TtsAudio.target_type == LESSON_SCRIPT_LINE_TTS_TARGET_TYPE,
                    TtsAudio.target_id.in_(script_target_ids),
                    TtsAudio.field == LESSON_SCRIPT_LINE_TTS_FIELD,
                    TtsAudio.speed == 1.0,
                )
            )
            for target_id, provider, model in result:
                index = int(str(target_id).rsplit(":", maxsplit=1)[-1])
                generated_indices.add(index)
                key = f"{provider}/{model}"
                provider_model_counts[key] = provider_model_counts.get(key, 0) + 1

        if question_target_ids:
            prompt_result = await session.execute(
                select(TtsAudio.target_id, TtsAudio.provider, TtsAudio.model).where(
                    TtsAudio.target_type == LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE,
                    TtsAudio.target_id.in_(question_target_ids),
                    TtsAudio.field == LESSON_QUESTION_PROMPT_TTS_FIELD,
                    TtsAudio.speed == 1.0,
                )
            )
            for target_id, provider, model in prompt_result:
                order = int(str(target_id).rsplit(":", maxsplit=1)[-1])
                generated_question_orders.add(order)
                key = f"{provider}/{model}"
                provider_model_counts[key] = provider_model_counts.get(key, 0) + 1

    return TtsSnapshot(
        expected_script_line_records=script_line_count,
        generated_script_line_records=len(generated_indices),
        missing_script_line_indices=[index for index in range(script_line_count) if index not in generated_indices],
        provider_model_counts=provider_model_counts,
        expected_question_prompt_targets=question_count,
        generated_question_prompt_records=len(generated_question_orders),
        missing_question_prompt_orders=[order for order in range(1, question_count + 1) if order not in generated_question_orders],
    )


def _build_signals(
    progress: ProgressSnapshot,
    review_events: ReviewEventSnapshot,
    tts: TtsSnapshot,
) -> tuple[list[str], list[str]]:
    signals: list[str] = []
    blockers: list[str] = []

    if progress.total_users == 0:
        signals.append("WAITING_FOR_PILOT_TRAFFIC: no non-smoke learner progress rows in the selected window")
    else:
        signals.append(
            "PILOT_PROGRESS_OBSERVED: "
            f"{progress.total_users} learner row(s), {progress.completed_users} completed, "
            f"average score {_score_text(progress.average_score_percent)}"
        )

    if review_events.total_events == 0:
        signals.append("NO_REVIEW_EVENTS: no non-smoke review_events rows in the selected window")
    else:
        signals.append(
            "REVIEW_EVENTS_OBSERVED: "
            f"{review_events.total_events} events, {review_events.correct_events} correct, "
            f"{review_events.incorrect_events} incorrect"
        )

    if tts.generated_script_line_records == tts.expected_script_line_records:
        signals.append("SCRIPT_LINE_TTS_READY: all expected learner-facing script-line TTS records exist")
    else:
        blockers.append(
            "SCRIPT_LINE_TTS_MISSING: "
            f"{tts.generated_script_line_records}/{tts.expected_script_line_records} records exist; "
            f"missing indices={tts.missing_script_line_indices}"
        )

    if tts.generated_question_prompt_records < tts.expected_question_prompt_targets:
        blockers.append(
            "QUESTION_PROMPT_TTS_PENDING: "
            f"{tts.generated_question_prompt_records}/{tts.expected_question_prompt_targets} prompt records exist; "
            f"missing orders={tts.missing_question_prompt_orders}"
        )
    else:
        signals.append("QUESTION_PROMPT_TTS_READY: all expected lesson question prompt TTS records exist")

    return signals, blockers


def _score_text(value: float | None) -> str:
    if value is None:
        return "n/a"
    return f"{value:.1f}%"


async def build_report(target: LessonTarget, *, since_days: int, include_smoke: bool) -> PilotFeedbackReport:
    engine.echo = False
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

    now = _utc_now()
    since = now - timedelta(days=since_days)
    lesson, script_lines, questions = await _load_lesson(target)
    progress = await _progress_snapshot(lesson.id, since, include_smoke=include_smoke)
    review_events = await _review_event_snapshot(lesson.id, since, include_smoke=include_smoke)
    tts = await _tts_snapshot(lesson.id, len(script_lines), len(questions))
    signals, blockers = _build_signals(progress, review_events, tts)

    return PilotFeedbackReport(
        generated_at=now.isoformat(),
        since=since.isoformat(),
        target=target,
        lesson=LessonSnapshot(
            lesson_id=str(lesson.id),
            title=lesson.title,
            topic=lesson.topic,
            is_published=lesson.is_published,
            script_line_count=len(script_lines),
            question_count=len(questions),
        ),
        progress=progress,
        review_events=review_events,
        tts=tts,
        signals=signals,
        blockers=blockers,
    )


def _print_human(report: PilotFeedbackReport) -> None:
    print(f"generated_at {report.generated_at}")
    print(f"since {report.since}")
    print(f"target {report.target.label} {report.target.jlpt_level} lesson_no={report.target.lesson_no}")
    print(f"lesson_id {report.lesson.lesson_id}")
    print(f"title {report.lesson.title}")
    print(f"is_published {report.lesson.is_published}")
    print(f"script_lines {report.lesson.script_line_count}")
    print(f"questions {report.lesson.question_count}")
    print(f"progress {report.progress}")
    print(f"review_events {report.review_events}")
    print(f"tts {report.tts}")
    print("signals")
    for signal in report.signals:
        print(f"- {signal}")
    print("blockers")
    for blocker in report.blockers:
        print(f"- {blocker}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Report read-only learner pilot signals for one lesson.")
    parser.add_argument("--level", default="N4", help="JLPT level, for example N4")
    parser.add_argument("--lesson-no", type=int, default=11, help="Lesson number inside the JLPT level")
    parser.add_argument("--label", default="HN4-011", help="Human-readable lesson label")
    parser.add_argument("--since-days", type=int, default=14, help="Lookback window for progress/review-event rows")
    parser.add_argument("--include-smoke", action="store_true", help="Include codex smoke users in progress/review aggregates")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of the default line-oriented report")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    target = LessonTarget(
        jlpt_level=args.level.upper(),
        lesson_no=args.lesson_no,
        label=args.label,
    )
    report = await build_report(target, since_days=args.since_days, include_smoke=args.include_smoke)
    if args.json:
        print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
        return
    _print_human(report)


if __name__ == "__main__":
    asyncio.run(main())
