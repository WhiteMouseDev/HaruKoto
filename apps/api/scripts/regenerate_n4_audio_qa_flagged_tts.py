from __future__ import annotations

import argparse
import asyncio
import csv
from collections.abc import Awaitable, Callable
from contextlib import AbstractAsyncContextManager
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Literal, Protocol, cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import async_session_factory
from app.models.lesson import Lesson
from app.models.tts import TtsAudio
from app.services.ai import generate_tts
from app.services.tts_generation import GeneratedTtsAudio
from app.services.tts_storage import upload_tts_to_gcs
from app.services.tts_target_resolver import (
    LESSON_QUESTION_PROMPT_TTS_FIELD,
    LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE,
    LESSON_SCRIPT_LINE_TTS_FIELD,
    LESSON_SCRIPT_LINE_TTS_TARGET_TYPE,
    TtsTargetResolverError,
    resolve_lesson_question_prompt_tts_target,
    resolve_lesson_script_line_tts_target,
)

TargetKind = Literal["script", "question"]
RegenerationStatus = Literal["planned", "regenerated", "failed"]

DEFAULT_MANIFEST = Path("docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.csv")
POST_REGENERATION_COLUMNS = ("regeneration_status", "new_audio_url", "post_regen_verdict", "post_regen_notes")
RESULT_COLUMNS = [
    "target_key",
    "target_id",
    "source_text",
    "current_audio_url",
    "status",
    "gcs_path",
    "old_audio_url",
    "new_audio_url",
    "provider",
    "model",
    "error",
]


class SessionFactory(Protocol):
    def __call__(self) -> AbstractAsyncContextManager[AsyncSession]: ...


@dataclass(frozen=True)
class FlaggedTtsTask:
    target_key: str
    lesson_id: str
    target_kind: TargetKind
    target_order: int
    target_type: str
    field: str
    target_id: str
    source_text: str
    current_audio_url: str

    @property
    def display_name(self) -> str:
        return f"{self.target_key} target_id={self.target_id}"

    def gcs_path(self, run_id: str) -> str:
        if self.target_kind == "script":
            return f"tts/lesson/{self.lesson_id}/script-line-{self.target_order}-regen-{run_id}.mp3"
        return f"tts/lesson/{self.lesson_id}/question-{self.target_order}-regen-{run_id}.mp3"


@dataclass(frozen=True)
class RegenerationResult:
    task: FlaggedTtsTask
    status: RegenerationStatus
    gcs_path: str | None = None
    old_audio_url: str | None = None
    new_audio_url: str | None = None
    provider: str | None = None
    model: str | None = None
    error: str | None = None


class FlaggedTtsRegenerationError(Exception):
    pass


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _resolve_path(path: Path) -> Path:
    if path.is_absolute():
        return path
    if path.exists():
        return path
    return _repo_root() / path


def _target_kind(value: str, *, row_number: int) -> TargetKind:
    if value == "script" or value == "question":
        return cast(TargetKind, value)
    raise ValueError(f"row {row_number}: unsupported target_kind {value!r}")


def _expected_target_type(kind: TargetKind) -> str:
    if kind == "script":
        return LESSON_SCRIPT_LINE_TTS_TARGET_TYPE
    return LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE


def _expected_field(kind: TargetKind) -> str:
    if kind == "script":
        return LESSON_SCRIPT_LINE_TTS_FIELD
    return LESSON_QUESTION_PROMPT_TTS_FIELD


def _task_from_row(row: dict[str, str], *, row_number: int) -> FlaggedTtsTask | None:
    verdict = (row.get("current_verdict") or "").strip().upper()
    if verdict != "FLAG":
        return None

    target_key = (row.get("target_key") or "").strip()
    lesson_id = (row.get("lesson_id") or "").strip()
    target_kind = _target_kind((row.get("target_kind") or "").strip(), row_number=row_number)
    raw_order = (row.get("target_order") or "").strip()
    target_type = (row.get("target_type") or "").strip()
    field = (row.get("field") or "").strip()
    target_id = (row.get("target_id") or "").strip()
    source_text = (row.get("source_text") or "").strip()
    current_audio_url = (row.get("current_audio_url") or "").strip()

    missing = [
        name
        for name, value in {
            "target_key": target_key,
            "lesson_id": lesson_id,
            "target_order": raw_order,
            "target_type": target_type,
            "field": field,
            "target_id": target_id,
            "source_text": source_text,
            "current_audio_url": current_audio_url,
        }.items()
        if not value
    ]
    if missing:
        raise ValueError(f"row {row_number}: missing required FLAG columns: {', '.join(missing)}")

    try:
        UUID(lesson_id)
    except ValueError as exc:
        raise ValueError(f"row {row_number}: lesson_id must be a UUID") from exc

    expected_target_type = _expected_target_type(target_kind)
    if target_type != expected_target_type:
        raise ValueError(f"row {row_number}: target_type {target_type!r} does not match target_kind {target_kind!r}")

    expected_field = _expected_field(target_kind)
    if field != expected_field:
        raise ValueError(f"row {row_number}: field {field!r} does not match target_kind {target_kind!r}")

    expected_target_id = f"{lesson_id}:{target_kind}:{raw_order}"
    if target_id != expected_target_id:
        raise ValueError(f"row {row_number}: target_id {target_id!r} does not match {expected_target_id!r}")

    try:
        target_order = int(raw_order)
    except ValueError as exc:
        raise ValueError(f"row {row_number}: target_order must be an integer") from exc

    if target_kind == "script" and target_order < 0:
        raise ValueError(f"row {row_number}: script target_order must be >= 0")
    if target_kind == "question" and target_order < 1:
        raise ValueError(f"row {row_number}: question target_order must be >= 1")

    for column in POST_REGENERATION_COLUMNS:
        if (row.get(column) or "").strip():
            raise ValueError(f"row {row_number}: {column} must be blank before regeneration")

    return FlaggedTtsTask(
        target_key=target_key,
        lesson_id=lesson_id,
        target_kind=target_kind,
        target_order=target_order,
        target_type=target_type,
        field=field,
        target_id=target_id,
        source_text=source_text,
        current_audio_url=current_audio_url,
    )


def read_manifest(csv_input: Path, *, target_keys: set[str] | None = None, limit: int | None = None) -> list[FlaggedTtsTask]:
    resolved_input = _resolve_path(csv_input)
    tasks: list[FlaggedTtsTask] = []

    with resolved_input.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        required_columns = {
            "target_key",
            "lesson_id",
            "target_kind",
            "target_order",
            "target_type",
            "field",
            "target_id",
            "source_text",
            "current_audio_url",
            "current_verdict",
            *POST_REGENERATION_COLUMNS,
        }
        missing_columns = required_columns - set(reader.fieldnames or [])
        if missing_columns:
            raise ValueError(f"manifest is missing required columns: {', '.join(sorted(missing_columns))}")

        for row_number, row in enumerate(reader, start=2):
            task = _task_from_row(row, row_number=row_number)
            if task is None:
                continue
            if target_keys is not None and task.target_key not in target_keys:
                continue
            tasks.append(task)
            if limit is not None and len(tasks) >= limit:
                break

    if target_keys is not None:
        found_keys = {task.target_key for task in tasks}
        missing_keys = target_keys - found_keys
        if missing_keys:
            raise ValueError(f"manifest target(s) not found or not FLAG: {', '.join(sorted(missing_keys))}")

    return tasks


def _resolve_target_from_lesson(task: FlaggedTtsTask, lesson: Lesson) -> tuple[str, str, str, str]:
    content = lesson.content_jsonb or {}
    try:
        if task.target_kind == "script":
            target = resolve_lesson_script_line_tts_target(
                lesson_id=lesson.id,
                content=content,
                line_index=task.target_order,
            )
        else:
            target = resolve_lesson_question_prompt_tts_target(
                lesson_id=lesson.id,
                content=content,
                question_order=task.target_order,
            )
    except TtsTargetResolverError as exc:
        raise FlaggedTtsRegenerationError(exc.detail) from exc

    mismatches: list[str] = []
    if target.target_type != task.target_type:
        mismatches.append(f"target_type {target.target_type!r} != manifest {task.target_type!r}")
    if target.target_id != task.target_id:
        mismatches.append(f"target_id {target.target_id!r} != manifest {task.target_id!r}")
    if target.field != task.field:
        mismatches.append(f"field {target.field!r} != manifest {task.field!r}")
    if target.text != task.source_text:
        mismatches.append(f"source_text {target.text!r} != manifest {task.source_text!r}")
    if mismatches:
        raise FlaggedTtsRegenerationError("; ".join(mismatches))

    return target.target_type, target.target_id, target.field, target.text


async def execute_task(
    task: FlaggedTtsTask,
    *,
    run_id: str,
    tts_generator: Callable[[str], Awaitable[GeneratedTtsAudio]],
    uploader: Callable[[str, bytes], Awaitable[str]],
    session_factory: SessionFactory,
) -> RegenerationResult:
    try:
        async with session_factory() as session:
            lesson_result = await session.execute(select(Lesson).where(Lesson.id == UUID(task.lesson_id), Lesson.is_published.is_(True)))
            lesson = lesson_result.scalar_one_or_none()
            if lesson is None:
                raise FlaggedTtsRegenerationError(f"published lesson not found: {task.lesson_id}")

            target_type, target_id, field, text = _resolve_target_from_lesson(task, lesson)

            existing_result = await session.execute(
                select(TtsAudio).where(
                    TtsAudio.target_type == target_type,
                    TtsAudio.target_id == target_id,
                    TtsAudio.speed == 1.0,
                    TtsAudio.field == field,
                )
            )
            existing = existing_result.scalar_one_or_none()
            if existing is None:
                raise FlaggedTtsRegenerationError(f"existing tts_audio row not found: {target_type}:{target_id}:{field}")
            if existing.audio_url != task.current_audio_url:
                raise FlaggedTtsRegenerationError(
                    f"current audio URL drift for {task.target_key}: db={existing.audio_url!r} manifest={task.current_audio_url!r}"
                )

            tts_result = await tts_generator(text)
            gcs_path = task.gcs_path(run_id)
            new_audio_url = await uploader(gcs_path, tts_result.audio)

            old_audio_url = existing.audio_url
            existing.text = text
            existing.provider = tts_result.provider
            existing.model = tts_result.model
            existing.audio_url = new_audio_url
            existing.field = field
            await session.commit()

            return RegenerationResult(
                task=task,
                status="regenerated",
                gcs_path=gcs_path,
                old_audio_url=old_audio_url,
                new_audio_url=new_audio_url,
                provider=tts_result.provider,
                model=tts_result.model,
            )
    except Exception as exc:
        return RegenerationResult(task=task, status="failed", error=f"{exc.__class__.__name__}: {exc}")


def planned_results(tasks: list[FlaggedTtsTask], *, run_id: str) -> list[RegenerationResult]:
    return [RegenerationResult(task=task, status="planned", gcs_path=task.gcs_path(run_id)) for task in tasks]


def write_result_csv(csv_output: Path, results: list[RegenerationResult]) -> int:
    output_path = csv_output if csv_output.is_absolute() else Path.cwd() / csv_output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=RESULT_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for result in results:
            writer.writerow(
                {
                    "target_key": result.task.target_key,
                    "target_id": result.task.target_id,
                    "source_text": result.task.source_text,
                    "current_audio_url": result.task.current_audio_url,
                    "status": result.status,
                    "gcs_path": result.gcs_path or "",
                    "old_audio_url": result.old_audio_url or "",
                    "new_audio_url": result.new_audio_url or "",
                    "provider": result.provider or "",
                    "model": result.model or "",
                    "error": result.error or "",
                }
            )
    return len(results)


async def run_regeneration(
    tasks: list[FlaggedTtsTask],
    *,
    execute: bool,
    continue_on_error: bool,
    sleep_seconds: float,
    run_id: str,
    result_output: Path | None = None,
    tts_generator: Callable[[str], Awaitable[GeneratedTtsAudio]] = generate_tts,
    uploader: Callable[[str, bytes], Awaitable[str]] = upload_tts_to_gcs,
    session_factory: SessionFactory = async_session_factory,
) -> list[RegenerationResult]:
    print(f"planned_flag_tasks {len(tasks)}")
    print(f"run_id {run_id}")
    for task in tasks:
        print(f"- {task.display_name} gcs_path={task.gcs_path(run_id)}")

    if not execute:
        print("dry_run true")
        results = planned_results(tasks, run_id=run_id)
        if result_output is not None:
            count = write_result_csv(result_output, results)
            print(f"result_csv {result_output} rows={count}")
        return results

    print("dry_run false")
    results: list[RegenerationResult] = []
    for task in tasks:
        result = await execute_task(
            task,
            run_id=run_id,
            tts_generator=tts_generator,
            uploader=uploader,
            session_factory=session_factory,
        )
        results.append(result)
        if result.status == "regenerated":
            print(f"regenerated {task.display_name} new_audio_url={result.new_audio_url}")
        else:
            print(f"failed {task.display_name} error={result.error}")
            if not continue_on_error:
                break
        if sleep_seconds > 0:
            await asyncio.sleep(sleep_seconds)

    regenerated_count = sum(1 for result in results if result.status == "regenerated")
    failed_count = sum(1 for result in results if result.status == "failed")
    if result_output is not None:
        count = write_result_csv(result_output, results)
        print(f"result_csv {result_output} rows={count}")
    print(f"summary regenerated={regenerated_count} failed={failed_count}")
    return results


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Regenerate N4 audio QA FLAG targets from the reviewed manifest.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST, help="FLAG regeneration manifest CSV path.")
    parser.add_argument("--target-key", action="append", default=None, help="Limit to one target key; repeatable.")
    parser.add_argument("--limit", type=int, default=None, help="Maximum FLAG targets to process.")
    parser.add_argument("--execute", action="store_true", help="Call TTS provider, upload audio, and update existing tts_audio rows.")
    parser.add_argument("--continue-on-error", action="store_true", help="Continue after a failed target.")
    parser.add_argument("--sleep-seconds", type=float, default=0.5, help="Delay between executed regenerations.")
    parser.add_argument("--run-id", default=None, help="Stable suffix for regenerated GCS object paths.")
    parser.add_argument("--result-output", type=Path, default=None, help="Optional CSV output for planned or executed results.")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    run_id = args.run_id or datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    tasks = read_manifest(
        args.manifest,
        target_keys=set(args.target_key) if args.target_key else None,
        limit=args.limit,
    )
    results = await run_regeneration(
        tasks,
        execute=args.execute,
        continue_on_error=args.continue_on_error,
        sleep_seconds=args.sleep_seconds,
        run_id=run_id,
        result_output=args.result_output,
    )
    if args.execute and any(result.status == "failed" for result in results):
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
