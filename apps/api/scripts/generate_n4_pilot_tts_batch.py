from __future__ import annotations

import argparse
import asyncio
from dataclasses import dataclass
from typing import Literal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.db.session import async_session_factory
from app.models.tts import TtsAudio
from app.services.ai import generate_tts
from app.services.lesson_script_tts import generate_lesson_question_prompt_tts, generate_lesson_script_line_tts
from app.services.tts_storage import upload_tts_to_gcs
from scripts.report_n4_pilot_tts_coverage import PilotBatchTtsCoverageReport, build_report

TaskKind = Literal["script", "question"]
TargetKindFilter = Literal["all", "script", "question"]
GenerationStatus = Literal["generated", "skipped_existing", "failed"]


@dataclass(frozen=True)
class GenerationTask:
    lesson_no: int
    label: str
    lesson_id: str
    kind: TaskKind
    order: int

    @property
    def target_id(self) -> str:
        target_kind = "script" if self.kind == "script" else "question"
        return f"{self.lesson_id}:{target_kind}:{self.order}"

    @property
    def display_name(self) -> str:
        return f"{self.label} {self.kind}:{self.order}"


@dataclass(frozen=True)
class GenerationResult:
    task: GenerationTask
    status: GenerationStatus
    audio_url: str | None = None
    error: str | None = None


def _target_type_for_task(task: GenerationTask) -> str:
    if task.kind == "script":
        return "lesson_script_line"
    return "lesson_question_prompt"


def _field_for_task(task: GenerationTask) -> str:
    if task.kind == "script":
        return "script_line"
    return "question_prompt"


async def _load_existing_audio_url(task: GenerationTask) -> str | None:
    async with async_session_factory() as session:
        result = await session.execute(
            select(TtsAudio.audio_url).where(
                TtsAudio.target_type == _target_type_for_task(task),
                TtsAudio.target_id == task.target_id,
                TtsAudio.speed == 1.0,
                TtsAudio.field == _field_for_task(task),
            )
        )
        return result.scalar_one_or_none()


def collect_missing_tasks(
    report: PilotBatchTtsCoverageReport,
    *,
    lesson_numbers: set[int] | None,
    target_kind: TargetKindFilter,
    limit: int | None,
) -> list[GenerationTask]:
    tasks: list[GenerationTask] = []

    for lesson in report.lessons:
        if lesson_numbers is not None and lesson.lesson_no not in lesson_numbers:
            continue

        if target_kind in ("all", "script"):
            tasks.extend(
                GenerationTask(
                    lesson_no=lesson.lesson_no,
                    label=lesson.label,
                    lesson_id=lesson.lesson_id,
                    kind="script",
                    order=index,
                )
                for index in lesson.missing_script_line_indices
            )

        if target_kind in ("all", "question"):
            tasks.extend(
                GenerationTask(
                    lesson_no=lesson.lesson_no,
                    label=lesson.label,
                    lesson_id=lesson.lesson_id,
                    kind="question",
                    order=order,
                )
                for order in lesson.missing_question_prompt_orders
            )

    tasks.sort(key=lambda task: (task.lesson_no, 0 if task.kind == "script" else 1, task.order))
    if limit is not None:
        return tasks[:limit]
    return tasks


async def execute_task(task: GenerationTask) -> GenerationResult:
    async with async_session_factory() as session:
        try:
            if task.kind == "script":
                result = await generate_lesson_script_line_tts(
                    session,
                    lesson_id=UUID(task.lesson_id),
                    line_index=task.order,
                    tts_generator=generate_tts,
                    upload_to_gcs=upload_tts_to_gcs,
                )
            else:
                result = await generate_lesson_question_prompt_tts(
                    session,
                    lesson_id=UUID(task.lesson_id),
                    question_order=task.order,
                    tts_generator=generate_tts,
                    upload_to_gcs=upload_tts_to_gcs,
                )
        except IntegrityError:
            await session.rollback()
            existing_audio_url = await _load_existing_audio_url(task)
            if existing_audio_url:
                return GenerationResult(
                    task=task,
                    status="skipped_existing",
                    audio_url=existing_audio_url,
                )
            return GenerationResult(
                task=task,
                status="failed",
                error="IntegrityError: target already exists but could not be reloaded",
            )
        except Exception as exc:
            await session.rollback()
            return GenerationResult(task=task, status="failed", error=f"{exc.__class__.__name__}: {exc}")

    return GenerationResult(task=task, status="generated", audio_url=result.audio_url)


async def run_generation(
    *,
    level: str,
    lesson_numbers: set[int] | None,
    target_kind: TargetKindFilter,
    limit: int | None,
    execute: bool,
    continue_on_error: bool,
    sleep_seconds: float,
) -> list[GenerationResult]:
    report = await build_report(
        level=level,
        include_unpublished=False,
        check_audio_urls=False,
        timeout_seconds=10.0,
    )
    tasks = collect_missing_tasks(
        report,
        lesson_numbers=lesson_numbers,
        target_kind=target_kind,
        limit=limit,
    )

    print(f"level {level}")
    print(f"planned_missing_tasks {len(tasks)}")
    for task in tasks:
        print(f"- {task.display_name} target_id={task.target_id}")

    if not execute:
        print("dry_run true")
        return []

    print("dry_run false")
    results: list[GenerationResult] = []
    for task in tasks:
        result = await execute_task(task)
        results.append(result)
        if result.status == "generated":
            print(f"generated {task.display_name}")
        elif result.status == "skipped_existing":
            print(f"skipped_existing {task.display_name}")
        else:
            print(f"failed {task.display_name} error={result.error}")
            if not continue_on_error:
                break
        if sleep_seconds > 0:
            await asyncio.sleep(sleep_seconds)

    generated_count = sum(1 for result in results if result.status == "generated")
    skipped_count = sum(1 for result in results if result.status == "skipped_existing")
    failed_count = sum(1 for result in results if result.status == "failed")
    print(f"summary generated={generated_count} skipped_existing={skipped_count} failed={failed_count}")
    return results


def _lesson_numbers(values: list[int] | None) -> set[int] | None:
    if not values:
        return None
    return set(values)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate missing N4 pilot lesson TTS through approved service paths.")
    parser.add_argument("--level", default="N4", help="JLPT level, for example N4")
    parser.add_argument("--lesson-no", type=int, action="append", help="Limit generation to one lesson number; repeatable")
    parser.add_argument("--target-kind", choices=["all", "script", "question"], default="all", help="Target kind to generate")
    parser.add_argument("--limit", type=int, default=None, help="Maximum missing targets to generate")
    parser.add_argument("--execute", action="store_true", help="Actually call TTS provider, upload audio, and write tts_audio")
    parser.add_argument("--continue-on-error", action="store_true", help="Continue after a failed target")
    parser.add_argument("--sleep-seconds", type=float, default=0.5, help="Delay between generated targets")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    results = await run_generation(
        level=args.level.upper(),
        lesson_numbers=_lesson_numbers(args.lesson_no),
        target_kind=args.target_kind,
        limit=args.limit,
        execute=args.execute,
        continue_on_error=args.continue_on_error,
        sleep_seconds=args.sleep_seconds,
    )
    if args.execute and any(result.status == "failed" for result in results):
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
