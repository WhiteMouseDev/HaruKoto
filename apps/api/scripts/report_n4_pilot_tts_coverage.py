from __future__ import annotations

import argparse
import asyncio
import json
import logging
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from typing import Any

import httpx
from sqlalchemy import String, select

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
class GeneratedTtsRecord:
    target_type: str
    target_id: str
    provider: str
    model: str
    audio_url: str


@dataclass(frozen=True)
class AudioUrlCheckSummary:
    checked_records: int
    ok_records: int
    failed_records: int
    failures: list[str]


@dataclass(frozen=True)
class LessonTtsCoverage:
    lesson_no: int
    label: str
    lesson_id: str
    title: str
    is_published: bool
    expected_script_line_records: int
    generated_script_line_records: int
    missing_script_line_indices: list[int]
    expected_question_prompt_records: int
    generated_question_prompt_records: int
    missing_question_prompt_orders: list[int]


@dataclass(frozen=True)
class PilotBatchTtsCoverageReport:
    generated_at: str
    level: str
    lesson_count: int
    expected_script_line_records: int
    generated_script_line_records: int
    expected_question_prompt_records: int
    generated_question_prompt_records: int
    expected_total_records: int
    generated_total_records: int
    provider_model_counts: dict[str, int]
    lessons: list[LessonTtsCoverage]
    audio_url_check: AudioUrlCheckSummary | None
    signals: list[str]
    blockers: list[str]


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _script_line_indices(content: dict[str, Any]) -> list[int]:
    reading = content.get("reading")
    if not isinstance(reading, dict):
        return []
    script = reading.get("script")
    if not isinstance(script, list):
        return []
    return [index for index, line in enumerate(script) if isinstance(line, dict)]


def _question_orders(content: dict[str, Any]) -> list[int]:
    questions = content.get("questions")
    if not isinstance(questions, list):
        return []

    orders: list[int] = []
    for fallback_order, question in enumerate(questions, start=1):
        if not isinstance(question, dict):
            continue
        raw_order = question.get("order")
        orders.append(raw_order if isinstance(raw_order, int) else fallback_order)
    return orders


def _lesson_label(level: str, lesson_no: int) -> str:
    return f"H{level}-{lesson_no:03d}"


async def _load_lessons(level: str, *, include_unpublished: bool) -> list[Lesson]:
    filters = [Lesson.jlpt_level.cast(String) == level]
    if not include_unpublished:
        filters.append(Lesson.is_published.is_(True))

    async with async_session_factory() as session:
        result = await session.execute(select(Lesson).where(*filters).order_by(Lesson.lesson_no))
        return list(result.scalars().all())


async def _load_generated_records(target_ids_by_type: dict[str, set[str]]) -> dict[tuple[str, str], GeneratedTtsRecord]:
    records: dict[tuple[str, str], GeneratedTtsRecord] = {}
    async with async_session_factory() as session:
        for target_type, target_ids in target_ids_by_type.items():
            if not target_ids:
                continue

            field = LESSON_SCRIPT_LINE_TTS_FIELD
            if target_type == LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE:
                field = LESSON_QUESTION_PROMPT_TTS_FIELD

            result = await session.execute(
                select(
                    TtsAudio.target_type,
                    TtsAudio.target_id,
                    TtsAudio.provider,
                    TtsAudio.model,
                    TtsAudio.audio_url,
                ).where(
                    TtsAudio.target_type == target_type,
                    TtsAudio.target_id.in_(target_ids),
                    TtsAudio.field == field,
                    TtsAudio.speed == 1.0,
                )
            )
            for target_type_value, target_id, provider, model, audio_url in result:
                key = (str(target_type_value), str(target_id))
                records.setdefault(
                    key,
                    GeneratedTtsRecord(
                        target_type=str(target_type_value),
                        target_id=str(target_id),
                        provider=str(provider),
                        model=str(model),
                        audio_url=str(audio_url),
                    ),
                )
    return records


async def _check_audio_urls(records: list[GeneratedTtsRecord], *, timeout_seconds: float) -> AudioUrlCheckSummary:
    failures: list[str] = []
    ok_records = 0

    async with httpx.AsyncClient(timeout=timeout_seconds, follow_redirects=True) as client:
        for record in records:
            try:
                response = await client.get(record.audio_url, headers={"Range": "bytes=0-4095"})
            except httpx.HTTPError as exc:
                failures.append(f"{record.target_type}:{record.target_id} request_error={exc.__class__.__name__}")
                continue

            content_type = response.headers.get("content-type", "")
            if response.status_code not in (200, 206):
                failures.append(f"{record.target_type}:{record.target_id} status={response.status_code}")
                continue
            if "audio" not in content_type and "mpeg" not in content_type:
                failures.append(f"{record.target_type}:{record.target_id} content_type={content_type or 'missing'}")
                continue
            if not response.content:
                failures.append(f"{record.target_type}:{record.target_id} empty_body")
                continue
            ok_records += 1

    return AudioUrlCheckSummary(
        checked_records=len(records),
        ok_records=ok_records,
        failed_records=len(failures),
        failures=failures,
    )


def _build_signals(
    *,
    lessons: list[LessonTtsCoverage],
    audio_url_check: AudioUrlCheckSummary | None,
) -> tuple[list[str], list[str]]:
    signals: list[str] = []
    blockers: list[str] = []

    expected_script = sum(lesson.expected_script_line_records for lesson in lessons)
    generated_script = sum(lesson.generated_script_line_records for lesson in lessons)
    expected_prompts = sum(lesson.expected_question_prompt_records for lesson in lessons)
    generated_prompts = sum(lesson.generated_question_prompt_records for lesson in lessons)

    if generated_script == expected_script:
        signals.append(f"SCRIPT_LINE_TTS_RECORDS_READY: {generated_script}/{expected_script} records exist")
    else:
        blockers.append(f"SCRIPT_LINE_TTS_RECORDS_MISSING: {generated_script}/{expected_script} records exist")

    if generated_prompts == expected_prompts:
        signals.append(f"QUESTION_PROMPT_TTS_RECORDS_READY: {generated_prompts}/{expected_prompts} records exist")
    else:
        blockers.append(f"QUESTION_PROMPT_TTS_RECORDS_MISSING: {generated_prompts}/{expected_prompts} records exist")

    missing_lessons = [lesson.label for lesson in lessons if lesson.missing_script_line_indices or lesson.missing_question_prompt_orders]
    if missing_lessons:
        blockers.append(f"LESSONS_WITH_TTS_GAPS: {', '.join(missing_lessons)}")
    else:
        signals.append("PILOT_BATCH_TTS_RECORDS_READY: all expected script-line and question-prompt records exist")

    if audio_url_check is None:
        signals.append("AUDIO_URL_CHECK_SKIPPED: run with --check-audio-urls for read-only HTTP validation")
    elif audio_url_check.failed_records == 0:
        signals.append(f"AUDIO_URLS_READY: {audio_url_check.ok_records}/{audio_url_check.checked_records} checked URLs passed")
    else:
        blockers.append(f"AUDIO_URL_CHECK_FAILED: {audio_url_check.failed_records}/{audio_url_check.checked_records} checked URLs failed")

    return signals, blockers


async def build_report(
    *,
    level: str,
    include_unpublished: bool,
    check_audio_urls: bool,
    timeout_seconds: float,
) -> PilotBatchTtsCoverageReport:
    engine.echo = False
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

    lessons = await _load_lessons(level, include_unpublished=include_unpublished)
    expected_script_by_lesson: dict[str, list[int]] = {}
    expected_question_by_lesson: dict[str, list[int]] = {}
    target_ids_by_type: dict[str, set[str]] = {
        LESSON_SCRIPT_LINE_TTS_TARGET_TYPE: set(),
        LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE: set(),
    }

    for lesson in lessons:
        lesson_id = str(lesson.id)
        content = lesson.content_jsonb or {}
        script_indices = _script_line_indices(content)
        question_orders = _question_orders(content)
        expected_script_by_lesson[lesson_id] = script_indices
        expected_question_by_lesson[lesson_id] = question_orders
        target_ids_by_type[LESSON_SCRIPT_LINE_TTS_TARGET_TYPE].update(f"{lesson_id}:script:{index}" for index in script_indices)
        target_ids_by_type[LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE].update(f"{lesson_id}:question:{order}" for order in question_orders)

    generated_records = await _load_generated_records(target_ids_by_type)
    lesson_reports: list[LessonTtsCoverage] = []
    provider_model_counts: dict[str, int] = {}

    for record in generated_records.values():
        key = f"{record.provider}/{record.model}"
        provider_model_counts[key] = provider_model_counts.get(key, 0) + 1

    for lesson in lessons:
        lesson_id = str(lesson.id)
        script_indices = expected_script_by_lesson[lesson_id]
        question_orders = expected_question_by_lesson[lesson_id]
        generated_script_indices = {
            index for index in script_indices if (LESSON_SCRIPT_LINE_TTS_TARGET_TYPE, f"{lesson_id}:script:{index}") in generated_records
        }
        generated_question_orders = {
            order
            for order in question_orders
            if (LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE, f"{lesson_id}:question:{order}") in generated_records
        }

        lesson_reports.append(
            LessonTtsCoverage(
                lesson_no=lesson.lesson_no,
                label=_lesson_label(level, lesson.lesson_no),
                lesson_id=lesson_id,
                title=lesson.title,
                is_published=lesson.is_published,
                expected_script_line_records=len(script_indices),
                generated_script_line_records=len(generated_script_indices),
                missing_script_line_indices=[index for index in script_indices if index not in generated_script_indices],
                expected_question_prompt_records=len(question_orders),
                generated_question_prompt_records=len(generated_question_orders),
                missing_question_prompt_orders=[order for order in question_orders if order not in generated_question_orders],
            )
        )

    audio_url_check = None
    if check_audio_urls:
        audio_url_check = await _check_audio_urls(list(generated_records.values()), timeout_seconds=timeout_seconds)

    signals, blockers = _build_signals(lessons=lesson_reports, audio_url_check=audio_url_check)
    expected_script = sum(lesson.expected_script_line_records for lesson in lesson_reports)
    generated_script = sum(lesson.generated_script_line_records for lesson in lesson_reports)
    expected_prompts = sum(lesson.expected_question_prompt_records for lesson in lesson_reports)
    generated_prompts = sum(lesson.generated_question_prompt_records for lesson in lesson_reports)

    return PilotBatchTtsCoverageReport(
        generated_at=_utc_now().isoformat(),
        level=level,
        lesson_count=len(lesson_reports),
        expected_script_line_records=expected_script,
        generated_script_line_records=generated_script,
        expected_question_prompt_records=expected_prompts,
        generated_question_prompt_records=generated_prompts,
        expected_total_records=expected_script + expected_prompts,
        generated_total_records=generated_script + generated_prompts,
        provider_model_counts=dict(sorted(provider_model_counts.items())),
        lessons=lesson_reports,
        audio_url_check=audio_url_check,
        signals=signals,
        blockers=blockers,
    )


def _print_human(report: PilotBatchTtsCoverageReport) -> None:
    print(f"generated_at {report.generated_at}")
    print(f"level {report.level}")
    print(f"lessons {report.lesson_count}")
    print(f"script_line_records {report.generated_script_line_records}/{report.expected_script_line_records}")
    print(f"question_prompt_records {report.generated_question_prompt_records}/{report.expected_question_prompt_records}")
    print(f"total_records {report.generated_total_records}/{report.expected_total_records}")
    print(f"provider_model_counts {report.provider_model_counts}")
    if report.audio_url_check is not None:
        print(f"audio_url_check {report.audio_url_check}")
    print("lessons")
    for lesson in report.lessons:
        print(
            f"- {lesson.label}: script={lesson.generated_script_line_records}/{lesson.expected_script_line_records} "
            f"missing_script={lesson.missing_script_line_indices} "
            f"questions={lesson.generated_question_prompt_records}/{lesson.expected_question_prompt_records} "
            f"missing_questions={lesson.missing_question_prompt_orders}"
        )
    print("signals")
    for signal in report.signals:
        print(f"- {signal}")
    print("blockers")
    for blocker in report.blockers:
        print(f"- {blocker}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Report read-only TTS coverage for a JLPT lesson pilot batch.")
    parser.add_argument("--level", default="N4", help="JLPT level, for example N4")
    parser.add_argument("--include-unpublished", action="store_true", help="Include unpublished lessons in the audit")
    parser.add_argument("--check-audio-urls", action="store_true", help="Read-only HTTP check for generated audio URLs")
    parser.add_argument("--timeout-seconds", type=float, default=10.0, help="Timeout for each audio URL HTTP check")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of the default line-oriented report")
    parser.add_argument("--fail-on-missing", action="store_true", help="Exit with status 1 when expected TTS records are missing")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    report = await build_report(
        level=args.level.upper(),
        include_unpublished=args.include_unpublished,
        check_audio_urls=args.check_audio_urls,
        timeout_seconds=args.timeout_seconds,
    )
    if args.json:
        print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    else:
        _print_human(report)
    if args.fail_on_missing and report.generated_total_records < report.expected_total_records:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
