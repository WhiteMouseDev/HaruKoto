from __future__ import annotations

import argparse
import asyncio
import json
import logging
import re
import subprocess
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Literal

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

TargetKind = Literal["script", "question"]

_PUNCTUATION_RE = re.compile(r"[\s。、！？!?.,，・「」『』（）()\[\]【】…:：;；'\"`~〜-]+")


@dataclass(frozen=True)
class TtsSourceTarget:
    lesson_no: int
    label: str
    lesson_id: str
    title: str
    kind: TargetKind
    order: int
    target_type: str
    target_id: str
    field: str
    source_text: str

    @property
    def display_name(self) -> str:
        return f"{self.label} {self.kind}:{self.order}"


@dataclass(frozen=True)
class TtsStoredRecord:
    target_id: str
    text: str
    provider: str
    model: str
    audio_url: str


@dataclass(frozen=True)
class AudioProbe:
    content_type: str
    byte_size: int
    format_name: str
    codec_name: str
    duration_seconds: float
    bit_rate: int | None
    silence_seconds: float | None
    silence_ratio: float | None


@dataclass(frozen=True)
class AudioQaResult:
    target: TtsSourceTarget
    provider: str | None
    model: str | None
    audio_url: str | None
    status: str
    probe: AudioProbe | None
    blockers: list[str]
    warnings: list[str]


@dataclass(frozen=True)
class AudioQaReport:
    level: str
    target_count: int
    pass_count: int
    blocked_count: int
    warning_count: int
    provider_model_counts: dict[str, int]
    duration_min_seconds: float | None
    duration_max_seconds: float | None
    duration_average_seconds: float | None
    total_duration_seconds: float
    results: list[AudioQaResult]
    blockers: list[str]
    warnings: list[str]


def _lesson_label(level: str, lesson_no: int) -> str:
    return f"H{level}-{lesson_no:03d}"


def _normalized_text(text: str) -> str:
    return _PUNCTUATION_RE.sub("", text).strip()


def _question_order(question: dict[str, Any], fallback_order: int) -> int:
    raw_order = question.get("order")
    if isinstance(raw_order, int):
        return raw_order
    if isinstance(raw_order, str) and raw_order.isdigit():
        return int(raw_order)
    return fallback_order


def source_targets_from_lesson(*, level: str, lesson: Lesson) -> list[TtsSourceTarget]:
    content = lesson.content_jsonb or {}
    targets: list[TtsSourceTarget] = []
    lesson_id = str(lesson.id)
    label = _lesson_label(level, lesson.lesson_no)

    reading = content.get("reading")
    script = reading.get("script") if isinstance(reading, dict) else None
    if isinstance(script, list):
        for index, line in enumerate(script):
            if not isinstance(line, dict) or not isinstance(line.get("text"), str):
                continue
            targets.append(
                TtsSourceTarget(
                    lesson_no=lesson.lesson_no,
                    label=label,
                    lesson_id=lesson_id,
                    title=lesson.title,
                    kind="script",
                    order=index,
                    target_type=LESSON_SCRIPT_LINE_TTS_TARGET_TYPE,
                    target_id=f"{lesson_id}:script:{index}",
                    field=LESSON_SCRIPT_LINE_TTS_FIELD,
                    source_text=line["text"],
                )
            )

    questions = content.get("questions")
    if isinstance(questions, list):
        for fallback_order, question in enumerate(questions, start=1):
            if not isinstance(question, dict) or not isinstance(question.get("prompt"), str):
                continue
            order = _question_order(question, fallback_order)
            targets.append(
                TtsSourceTarget(
                    lesson_no=lesson.lesson_no,
                    label=label,
                    lesson_id=lesson_id,
                    title=lesson.title,
                    kind="question",
                    order=order,
                    target_type=LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE,
                    target_id=f"{lesson_id}:question:{order}",
                    field=LESSON_QUESTION_PROMPT_TTS_FIELD,
                    source_text=question["prompt"],
                )
            )

    return targets


async def _load_targets(level: str) -> list[TtsSourceTarget]:
    async with async_session_factory() as session:
        result = await session.execute(
            select(Lesson).where(Lesson.jlpt_level.cast(String) == level, Lesson.is_published.is_(True)).order_by(Lesson.lesson_no)
        )
        lessons = list(result.scalars().all())

    targets: list[TtsSourceTarget] = []
    for lesson in lessons:
        targets.extend(source_targets_from_lesson(level=level, lesson=lesson))
    return targets


async def _load_records(targets: list[TtsSourceTarget]) -> dict[str, TtsStoredRecord]:
    records: dict[str, TtsStoredRecord] = {}
    target_ids_by_type: dict[str, set[str]] = {
        LESSON_SCRIPT_LINE_TTS_TARGET_TYPE: set(),
        LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE: set(),
    }
    for target in targets:
        target_ids_by_type[target.target_type].add(target.target_id)

    async with async_session_factory() as session:
        for target_type, target_ids in target_ids_by_type.items():
            if not target_ids:
                continue
            field = LESSON_SCRIPT_LINE_TTS_FIELD
            if target_type == LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE:
                field = LESSON_QUESTION_PROMPT_TTS_FIELD
            result = await session.execute(
                select(TtsAudio.target_id, TtsAudio.text, TtsAudio.provider, TtsAudio.model, TtsAudio.audio_url).where(
                    TtsAudio.target_type == target_type,
                    TtsAudio.target_id.in_(target_ids),
                    TtsAudio.field == field,
                    TtsAudio.speed == 1.0,
                )
            )
            for target_id, text, provider, model, audio_url in result:
                records.setdefault(
                    str(target_id),
                    TtsStoredRecord(
                        target_id=str(target_id),
                        text=str(text),
                        provider=str(provider),
                        model=str(model),
                        audio_url=str(audio_url),
                    ),
                )

    return records


def _run_json_command(command: list[str]) -> dict[str, Any]:
    completed = subprocess.run(command, capture_output=True, check=True, text=True)
    return json.loads(completed.stdout)


def _probe_file(path: Path, *, content_type: str, byte_size: int, check_silence: bool) -> AudioProbe:
    data = _run_json_command(
        [
            "ffprobe",
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_format",
            "-show_streams",
            str(path),
        ]
    )
    streams = [stream for stream in data.get("streams", []) if stream.get("codec_type") == "audio"]
    stream = streams[0] if streams else {}
    fmt = data.get("format", {})
    duration = _float_or_zero(fmt.get("duration") or stream.get("duration"))
    silence_seconds = _silence_seconds(path) if check_silence else None
    silence_ratio = None
    if silence_seconds is not None and duration > 0:
        silence_ratio = round(min(silence_seconds / duration, 1.0), 4)
    bit_rate = _int_or_none(fmt.get("bit_rate") or stream.get("bit_rate"))

    return AudioProbe(
        content_type=content_type,
        byte_size=byte_size,
        format_name=str(fmt.get("format_name", "")),
        codec_name=str(stream.get("codec_name", "")),
        duration_seconds=round(duration, 3),
        bit_rate=bit_rate,
        silence_seconds=None if silence_seconds is None else round(silence_seconds, 3),
        silence_ratio=silence_ratio,
    )


def _silence_seconds(path: Path) -> float:
    completed = subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-nostats",
            "-i",
            str(path),
            "-af",
            "silencedetect=noise=-45dB:d=0.35",
            "-f",
            "null",
            "-",
        ],
        capture_output=True,
        check=False,
        text=True,
    )
    total = 0.0
    for match in re.finditer(r"silence_duration:\s*([0-9.]+)", completed.stderr):
        total += float(match.group(1))
    return total


def _float_or_zero(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _int_or_none(value: Any) -> int | None:
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return None


def evaluate_audio_quality(
    *,
    target: TtsSourceTarget,
    record: TtsStoredRecord | None,
    probe: AudioProbe | None,
    error: str | None = None,
) -> AudioQaResult:
    blockers: list[str] = []
    warnings: list[str] = []

    if record is None:
        blockers.append("MISSING_TTS_RECORD")
        return AudioQaResult(
            target=target,
            provider=None,
            model=None,
            audio_url=None,
            status="BLOCK",
            probe=None,
            blockers=blockers,
            warnings=warnings,
        )

    if _normalized_text(record.text) != _normalized_text(target.source_text):
        blockers.append("TEXT_MISMATCH")

    if error is not None:
        blockers.append(f"AUDIO_DOWNLOAD_OR_PROBE_FAILED: {error}")
    elif probe is None:
        blockers.append("MISSING_AUDIO_PROBE")
    else:
        blockers.extend(_probe_blockers(probe))
        warnings.extend(_probe_warnings(target=target, probe=probe))

    return AudioQaResult(
        target=target,
        provider=record.provider,
        model=record.model,
        audio_url=record.audio_url,
        status="BLOCK" if blockers else "PASS",
        probe=probe,
        blockers=blockers,
        warnings=warnings,
    )


def _probe_blockers(probe: AudioProbe) -> list[str]:
    blockers: list[str] = []
    if "audio" not in probe.content_type and "mpeg" not in probe.content_type:
        blockers.append(f"INVALID_CONTENT_TYPE:{probe.content_type or 'missing'}")
    if probe.byte_size < 1024:
        blockers.append(f"AUDIO_TOO_SMALL:{probe.byte_size}")
    if probe.codec_name != "mp3":
        blockers.append(f"UNEXPECTED_CODEC:{probe.codec_name or 'missing'}")
    if probe.duration_seconds < 0.4:
        blockers.append(f"AUDIO_TOO_SHORT:{probe.duration_seconds}")
    if probe.duration_seconds > 30:
        blockers.append(f"AUDIO_TOO_LONG:{probe.duration_seconds}")
    if probe.silence_ratio is not None and probe.duration_seconds > 1 and probe.silence_ratio > 0.6:
        blockers.append(f"EXCESSIVE_SILENCE_RATIO:{probe.silence_ratio}")
    return blockers


def _probe_warnings(*, target: TtsSourceTarget, probe: AudioProbe) -> list[str]:
    warnings: list[str] = []
    normalized_length = len(_normalized_text(target.source_text))
    if normalized_length >= 8 and probe.duration_seconds > 0:
        seconds_per_char = probe.duration_seconds / normalized_length
        if seconds_per_char < 0.045:
            warnings.append(f"DURATION_FAST_FOR_TEXT:{seconds_per_char:.3f}")
        if seconds_per_char > 0.65:
            warnings.append(f"DURATION_SLOW_FOR_TEXT:{seconds_per_char:.3f}")
    if probe.silence_ratio is not None and 0.35 < probe.silence_ratio <= 0.6:
        warnings.append(f"HIGH_SILENCE_RATIO:{probe.silence_ratio}")
    return warnings


async def _download_audio(record: TtsStoredRecord, *, client: httpx.AsyncClient, output_path: Path) -> tuple[str, int]:
    response = await client.get(record.audio_url)
    response.raise_for_status()
    output_path.write_bytes(response.content)
    return response.headers.get("content-type", ""), len(response.content)


async def build_report(
    *,
    level: str,
    limit: int | None,
    check_silence: bool,
    timeout_seconds: float,
) -> AudioQaReport:
    engine.echo = False
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

    targets = await _load_targets(level)
    targets.sort(key=lambda target: (target.lesson_no, 0 if target.kind == "script" else 1, target.order))
    if limit is not None:
        targets = targets[:limit]
    records = await _load_records(targets)

    results: list[AudioQaResult] = []
    with tempfile.TemporaryDirectory(prefix="harukoto-tts-audio-qa-") as tmpdir:
        tmpdir_path = Path(tmpdir)
        async with httpx.AsyncClient(timeout=timeout_seconds, follow_redirects=True) as client:
            for index, target in enumerate(targets, start=1):
                record = records.get(target.target_id)
                probe = None
                error = None
                if record is not None:
                    output_path = tmpdir_path / f"{index:03d}.mp3"
                    try:
                        content_type, byte_size = await _download_audio(record, client=client, output_path=output_path)
                        probe = _probe_file(output_path, content_type=content_type, byte_size=byte_size, check_silence=check_silence)
                    except Exception as exc:
                        error = f"{exc.__class__.__name__}: {exc}"
                results.append(evaluate_audio_quality(target=target, record=record, probe=probe, error=error))

    return _build_report(level=level, results=results)


def _build_report(*, level: str, results: list[AudioQaResult]) -> AudioQaReport:
    durations = [result.probe.duration_seconds for result in results if result.probe is not None]
    provider_model_counts: dict[str, int] = {}
    blockers: list[str] = []
    warnings: list[str] = []

    for result in results:
        if result.provider and result.model:
            key = f"{result.provider}/{result.model}"
            provider_model_counts[key] = provider_model_counts.get(key, 0) + 1
        if result.blockers:
            blockers.append(f"{result.target.display_name}: {', '.join(result.blockers)}")
        if result.warnings:
            warnings.append(f"{result.target.display_name}: {', '.join(result.warnings)}")

    return AudioQaReport(
        level=level,
        target_count=len(results),
        pass_count=sum(1 for result in results if result.status == "PASS"),
        blocked_count=sum(1 for result in results if result.status == "BLOCK"),
        warning_count=sum(len(result.warnings) for result in results),
        provider_model_counts=dict(sorted(provider_model_counts.items())),
        duration_min_seconds=None if not durations else round(min(durations), 3),
        duration_max_seconds=None if not durations else round(max(durations), 3),
        duration_average_seconds=None if not durations else round(sum(durations) / len(durations), 3),
        total_duration_seconds=round(sum(durations), 3),
        results=results,
        blockers=blockers,
        warnings=warnings,
    )


def _print_human(report: AudioQaReport) -> None:
    print(f"level {report.level}")
    print(f"targets {report.pass_count}/{report.target_count} pass")
    print(f"blocked {report.blocked_count}")
    print(f"warnings {report.warning_count}")
    print(f"provider_model_counts {report.provider_model_counts}")
    print(
        "durations "
        f"min={report.duration_min_seconds} "
        f"max={report.duration_max_seconds} "
        f"avg={report.duration_average_seconds} "
        f"total={report.total_duration_seconds}"
    )
    print("blockers")
    for blocker in report.blockers:
        print(f"- {blocker}")
    print("warnings")
    for warning in report.warnings:
        print(f"- {warning}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run machine audio-quality checks for N4 pilot lesson TTS MP3s.")
    parser.add_argument("--level", default="N4", help="JLPT level, for example N4")
    parser.add_argument("--limit", type=int, default=None, help="Limit the number of targets checked")
    parser.add_argument("--skip-silence-check", action="store_true", help="Skip ffmpeg silencedetect pass")
    parser.add_argument("--timeout-seconds", type=float, default=15.0, help="HTTP download timeout")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of the default line-oriented report")
    parser.add_argument("--fail-on-blocker", action="store_true", help="Exit with status 1 if any blocker is found")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    report = await build_report(
        level=args.level.upper(),
        limit=args.limit,
        check_silence=not args.skip_silence_check,
        timeout_seconds=args.timeout_seconds,
    )
    if args.json:
        print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    else:
        _print_human(report)
    if args.fail_on_blocker and report.blocked_count:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
