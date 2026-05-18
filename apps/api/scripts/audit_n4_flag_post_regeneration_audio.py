from __future__ import annotations

import argparse
import asyncio
import csv
import re
import shlex
import tempfile
from dataclasses import dataclass
from pathlib import Path

import httpx

from app.services.tts_target_resolver import (
    LESSON_QUESTION_PROMPT_TTS_FIELD,
    LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE,
    LESSON_SCRIPT_LINE_TTS_FIELD,
    LESSON_SCRIPT_LINE_TTS_TARGET_TYPE,
)
from scripts.audit_n4_pilot_tts_audio_quality import (
    AudioQaReport,
    AudioQaResult,
    AudioTranscriber,
    TtsSourceTarget,
    TtsStoredRecord,
    _build_report,
    _download_audio,
    _probe_file,
    build_transcription_probe,
    evaluate_audio_quality,
)

DEFAULT_REVIEW_CSV = Path("docs/operations/plans/n4-human-audio-qa-flag-post-regeneration-review-2026-05-14.csv")
DEFAULT_REGENERATION_RESULTS_CSV = Path("docs/operations/plans/n4-human-audio-qa-flag-regeneration-results-2026-05-14.csv")
TARGET_KEY_RE = re.compile(r"^(HN(?P<level>\d)-(?P<lesson_no>\d{3}))\s+(?P<kind>script|question):(?P<order>\d+)$")
APPLY_CSV_COLUMNS = [
    "target_key",
    "packet",
    "priority",
    "review_signals",
    "japanese_text",
    "korean_context",
    "audio_url",
    "current_verdict",
    "current_notes",
    "new_verdict",
    "new_notes",
]
REVIEW_CSV_REQUIRED_COLUMNS = set(APPLY_CSV_COLUMNS)
REGENERATION_RESULT_REQUIRED_COLUMNS = {
    "target_key",
    "target_id",
    "source_text",
    "status",
    "new_audio_url",
    "provider",
    "model",
}


@dataclass(frozen=True)
class RegenerationMetadata:
    target_key: str
    target_id: str
    source_text: str
    new_audio_url: str
    provider: str
    model: str


@dataclass(frozen=True)
class ReviewTarget:
    target_key: str
    packet: str
    priority: str
    review_signals: str
    japanese_text: str
    korean_context: str
    audio_url: str
    current_verdict: str
    current_notes: str
    target_id: str
    provider: str
    model: str

    def to_source_target(self) -> TtsSourceTarget:
        parsed = _parse_target_key(self.target_key)
        kind = parsed["kind"]
        target_type = LESSON_SCRIPT_LINE_TTS_TARGET_TYPE
        field = LESSON_SCRIPT_LINE_TTS_FIELD
        if kind == "question":
            target_type = LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE
            field = LESSON_QUESTION_PROMPT_TTS_FIELD

        return TtsSourceTarget(
            lesson_no=int(parsed["lesson_no"]),
            label=parsed["label"],
            lesson_id=self.target_id.split(":", 1)[0],
            title=self.korean_context,
            kind=kind,  # type: ignore[arg-type]
            order=int(parsed["order"]),
            target_type=target_type,
            target_id=self.target_id,
            field=field,
            source_text=self.japanese_text,
        )

    def to_stored_record(self) -> TtsStoredRecord:
        return TtsStoredRecord(
            target_id=self.target_id,
            text=self.japanese_text,
            provider=self.provider,
            model=self.model,
            audio_url=self.audio_url,
        )


@dataclass(frozen=True)
class PostRegenerationAuditRow:
    item: ReviewTarget
    result: AudioQaResult
    recommended_verdict: str
    recommended_notes: str


@dataclass(frozen=True)
class PostRegenerationAuditReport:
    audio_report: AudioQaReport
    rows: list[PostRegenerationAuditRow]
    recommended_pass_count: int
    recommended_flag_count: int
    unresolved_count: int


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _resolve_path(path: Path) -> Path:
    if path.is_absolute():
        return path
    if path.exists():
        return path
    return _repo_root() / path


def _resolve_output_path(path: Path) -> Path:
    if path.is_absolute():
        return path
    if path.parent != Path(".") and path.parent.exists():
        return path
    return _repo_root() / path


def _display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(_repo_root()))
    except ValueError:
        return str(path)


def _parse_target_key(target_key: str) -> dict[str, str]:
    match = TARGET_KEY_RE.match(target_key)
    if match is None:
        raise ValueError(f"unsupported target_key: {target_key!r}")
    return {
        "label": match.group(1),
        "level": f"N{match.group('level')}",
        "lesson_no": match.group("lesson_no"),
        "kind": match.group("kind"),
        "order": match.group("order"),
    }


def _compact_text(value: str, *, limit: int = 96) -> str:
    text = " ".join(value.split())
    if len(text) <= limit:
        return text
    return f"{text[: limit - 1]}..."


def _markdown_cell(value: str | int | float | None) -> str:
    text = "" if value is None else str(value)
    return " ".join(text.split()).replace("|", "\\|")


def _signal_text(values: list[str]) -> str:
    return ", ".join(values) if values else ""


def read_regeneration_metadata(csv_input: Path) -> dict[str, RegenerationMetadata]:
    resolved_input = _resolve_path(csv_input)
    metadata: dict[str, RegenerationMetadata] = {}
    with resolved_input.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        missing_columns = REGENERATION_RESULT_REQUIRED_COLUMNS - set(reader.fieldnames or [])
        if missing_columns:
            raise ValueError(f"regeneration results CSV is missing required columns: {', '.join(sorted(missing_columns))}")

        for row_number, row in enumerate(reader, start=2):
            target_key = (row.get("target_key") or "").strip()
            if not target_key:
                continue
            if target_key in metadata:
                raise ValueError(f"row {row_number}: duplicate regeneration target_key {target_key!r}")
            status = (row.get("status") or "").strip()
            if status != "regenerated":
                continue
            metadata[target_key] = RegenerationMetadata(
                target_key=target_key,
                target_id=(row.get("target_id") or "").strip(),
                source_text=(row.get("source_text") or "").strip(),
                new_audio_url=(row.get("new_audio_url") or "").strip(),
                provider=(row.get("provider") or "unknown").strip() or "unknown",
                model=(row.get("model") or "unknown").strip() or "unknown",
            )
    return metadata


def read_review_targets(csv_input: Path, *, regeneration_metadata: dict[str, RegenerationMetadata] | None = None) -> list[ReviewTarget]:
    resolved_input = _resolve_path(csv_input)
    targets: list[ReviewTarget] = []
    with resolved_input.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        missing_columns = REVIEW_CSV_REQUIRED_COLUMNS - set(reader.fieldnames or [])
        if missing_columns:
            raise ValueError(f"review CSV is missing required columns: {', '.join(sorted(missing_columns))}")

        for row_number, row in enumerate(reader, start=2):
            target_key = (row.get("target_key") or "").strip()
            if not target_key:
                continue
            _parse_target_key(target_key)
            current_verdict = (row.get("current_verdict") or "").strip().upper()
            if current_verdict != "FLAG":
                raise ValueError(f"row {row_number}: expected current_verdict FLAG for post-regeneration audit")
            japanese_text = (row.get("japanese_text") or "").strip()
            audio_url = (row.get("audio_url") or "").strip()
            if not japanese_text or not audio_url:
                raise ValueError(f"row {row_number}: japanese_text and audio_url are required")

            metadata = regeneration_metadata.get(target_key) if regeneration_metadata is not None else None
            target_id = target_key
            provider = "unknown"
            model = "unknown"
            if metadata is not None:
                if metadata.source_text != japanese_text:
                    raise ValueError(f"row {row_number}: japanese_text does not match regeneration source_text for {target_key}")
                if metadata.new_audio_url != audio_url:
                    raise ValueError(f"row {row_number}: audio_url does not match regeneration new_audio_url for {target_key}")
                target_id = metadata.target_id
                provider = metadata.provider
                model = metadata.model

            targets.append(
                ReviewTarget(
                    target_key=target_key,
                    packet=(row.get("packet") or "").strip(),
                    priority=(row.get("priority") or "").strip(),
                    review_signals=(row.get("review_signals") or "").strip(),
                    japanese_text=japanese_text,
                    korean_context=(row.get("korean_context") or "").strip(),
                    audio_url=audio_url,
                    current_verdict=current_verdict,
                    current_notes=(row.get("current_notes") or "").strip(),
                    target_id=target_id,
                    provider=provider,
                    model=model,
                )
            )
    return targets


def recommend_verdict(result: AudioQaResult, *, transcribe: bool) -> tuple[str, str]:
    if result.blockers:
        signals = _compact_text(_signal_text(result.blockers))
        return (
            "FLAG",
            "Delegated AI-assisted FLAG: regenerated audio has blocker(s) "
            f"{signals}; direct-listen or regenerate before rollout; not native-speaker review.",
        )
    if result.warnings:
        signals = _compact_text(_signal_text(result.warnings))
        return (
            "FLAG",
            "Delegated AI-assisted FLAG: regenerated audio still has review signal(s) "
            f"{signals}; direct-listen or regenerate before rollout; not native-speaker review.",
        )
    if transcribe:
        return (
            "PASS",
            "Delegated AI-assisted post-regeneration PASS: MP3 probe passed and STT matched source exactly; not native-speaker review.",
        )
    return "", ""


async def audit_targets(
    targets: list[ReviewTarget],
    *,
    check_silence: bool,
    timeout_seconds: float,
    run_transcription: bool,
    transcriber: AudioTranscriber | None = None,
) -> PostRegenerationAuditReport:
    if run_transcription and transcriber is None:
        from app.services.ai import transcribe_audio as default_transcribe_audio

        transcriber = default_transcribe_audio

    rows: list[PostRegenerationAuditRow] = []
    with tempfile.TemporaryDirectory(prefix="harukoto-n4-flag-post-regen-") as tmpdir:
        tmpdir_path = Path(tmpdir)
        async with httpx.AsyncClient(timeout=timeout_seconds, follow_redirects=True) as client:
            for index, item in enumerate(targets, start=1):
                source_target = item.to_source_target()
                record = item.to_stored_record()
                output_path = tmpdir_path / f"{index:03d}.mp3"
                probe = None
                transcription = None
                error = None
                transcription_error = None
                audio_bytes = None
                content_type = ""
                try:
                    content_type, byte_size, audio_bytes = await _download_audio(record, client=client, output_path=output_path)
                    probe = _probe_file(output_path, content_type=content_type, byte_size=byte_size, check_silence=check_silence)
                except Exception as exc:
                    error = f"{exc.__class__.__name__}: {exc}"
                if error is None and run_transcription and transcriber is not None and audio_bytes is not None:
                    try:
                        transcript = await transcriber(audio_bytes, content_type or "audio/mpeg")
                        transcription = build_transcription_probe(target=source_target, transcript=transcript)
                    except Exception as exc:
                        transcription_error = f"{exc.__class__.__name__}: {exc}"

                result = evaluate_audio_quality(
                    target=source_target,
                    record=record,
                    probe=probe,
                    transcription=transcription,
                    error=error,
                    transcription_error=transcription_error,
                    block_on_transcription_mismatch=False,
                )
                recommended_verdict, recommended_notes = recommend_verdict(result, transcribe=run_transcription)
                rows.append(
                    PostRegenerationAuditRow(
                        item=item,
                        result=result,
                        recommended_verdict=recommended_verdict,
                        recommended_notes=recommended_notes,
                    )
                )
    return build_post_regeneration_report(rows)


def build_post_regeneration_report(rows: list[PostRegenerationAuditRow]) -> PostRegenerationAuditReport:
    audio_report = _build_report(level="N4", results=[row.result for row in rows])
    return PostRegenerationAuditReport(
        audio_report=audio_report,
        rows=rows,
        recommended_pass_count=sum(1 for row in rows if row.recommended_verdict == "PASS"),
        recommended_flag_count=sum(1 for row in rows if row.recommended_verdict == "FLAG"),
        unresolved_count=sum(1 for row in rows if not row.recommended_verdict),
    )


def write_recommendation_csv(csv_output: Path, report: PostRegenerationAuditReport) -> int:
    resolved_output = _resolve_output_path(csv_output)
    resolved_output.parent.mkdir(parents=True, exist_ok=True)
    with resolved_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=APPLY_CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for row in report.rows:
            item = row.item
            writer.writerow(
                {
                    "target_key": item.target_key,
                    "packet": item.packet,
                    "priority": item.priority,
                    "review_signals": item.review_signals,
                    "japanese_text": item.japanese_text,
                    "korean_context": item.korean_context,
                    "audio_url": item.audio_url,
                    "current_verdict": item.current_verdict,
                    "current_notes": item.current_notes,
                    "new_verdict": row.recommended_verdict,
                    "new_notes": row.recommended_notes,
                }
            )
    return len(report.rows)


def render_markdown(report: PostRegenerationAuditReport, *, command: str | None, review_csv: Path, regeneration_results_csv: Path) -> str:
    status = "PASS" if report.recommended_pass_count == report.audio_report.target_count and report.audio_report.target_count else "REVIEW"
    lines = [
        "# N4 FLAG Post-Regeneration Audio Audit",
        "",
        f"> Status: {status}",
        "> Scope: regenerated audio URLs for the 8 current N4 FLAG rows",
        "> Boundary: delegated AI/STT audio QA only; not native-speaker review",
        "",
        "ASSUMPTION: The project owner delegated this post-regeneration review because no human/native-speaker reviewer is "
        "currently available.",
        "",
        "## Command",
        "",
    ]
    if command:
        lines.extend(["```bash", command, "```", ""])
    else:
        lines.extend(["Command was not recorded.", ""])

    lines.extend(
        [
            "## Inputs",
            "",
            f"- Review CSV: `{_display_path(_resolve_path(review_csv))}`",
            f"- Regeneration results CSV: `{_display_path(_resolve_path(regeneration_results_csv))}`",
            "",
            "## Summary",
            "",
            "| Metric | Result |",
            "|---|---:|",
            f"| Total targets | {report.audio_report.target_count} |",
            f"| Machine pass | {report.audio_report.pass_count} |",
            f"| Blocked targets | {report.audio_report.blocked_count} |",
            f"| Warning count | {report.audio_report.warning_count} |",
            f"| Transcribed targets | {report.audio_report.transcribed_count} |",
            f"| STT exact matches | {report.audio_report.transcription_match_count} |",
            f"| STT mismatches | {report.audio_report.transcription_mismatch_count} |",
            f"| STT errors | {report.audio_report.transcription_error_count} |",
            f"| Recommended PASS | {report.recommended_pass_count} |",
            f"| Recommended FLAG | {report.recommended_flag_count} |",
            f"| Unresolved/no recommendation | {report.unresolved_count} |",
            "",
            "## Recommendations",
            "",
            "| Target | Japanese text | STT transcript | Signals | Recommendation | Audio |",
            "|---|---|---|---|---|---|",
        ]
    )

    for row in report.rows:
        transcription = row.result.transcription
        transcript = transcription.transcript if transcription is not None else ""
        signals = _signal_text([*row.result.blockers, *row.result.warnings])
        recommendation = row.recommended_verdict or "UNRESOLVED"
        lines.append(
            "| "
            f"{_markdown_cell(row.item.target_key)} | "
            f"{_markdown_cell(row.item.japanese_text)} | "
            f"{_markdown_cell(transcript)} | "
            f"{_markdown_cell(signals or 'none')} | "
            f"{_markdown_cell(recommendation)} | "
            f"[audio]({row.item.audio_url}) |"
        )

    lines.extend(["", "## Decision", ""])
    if report.recommended_flag_count:
        lines.append(
            "REVIEW: keep unresolved regenerated rows as `FLAG` until the remaining signals are resolved by another regeneration "
            "or direct listening review."
        )
    elif report.unresolved_count:
        lines.append("REVIEW: machine probe passed, but STT/listening evidence is missing; keep rows out of PASS application.")
    else:
        lines.append("PASS: all regenerated FLAG rows have clean machine probe evidence and exact STT/source matches.")
    lines.append("")
    return "\n".join(lines)


def _print_human(report: PostRegenerationAuditReport) -> None:
    print(f"targets {report.audio_report.target_count}")
    print(f"machine_pass {report.audio_report.pass_count}")
    print(f"blocked {report.audio_report.blocked_count}")
    print(f"warnings {report.audio_report.warning_count}")
    print(f"transcribed {report.audio_report.transcribed_count}")
    print(f"stt_exact_match {report.audio_report.transcription_match_count}")
    print(f"stt_mismatch {report.audio_report.transcription_mismatch_count}")
    print(f"recommended_pass {report.recommended_pass_count}")
    print(f"recommended_flag {report.recommended_flag_count}")
    print(f"unresolved {report.unresolved_count}")


def _command_string(args: argparse.Namespace) -> str:
    parts = [
        "uv",
        "run",
        "python",
        "scripts/audit_n4_flag_post_regeneration_audio.py",
        "--review-csv",
        str(args.review_csv),
        "--regeneration-results-csv",
        str(args.regeneration_results_csv),
    ]
    if args.skip_silence_check:
        parts.append("--skip-silence-check")
    if args.timeout_seconds != 15.0:
        parts.extend(["--timeout-seconds", str(args.timeout_seconds)])
    if args.transcribe:
        parts.append("--transcribe")
    if args.csv_output is not None:
        parts.extend(["--csv-output", str(args.csv_output)])
    if args.markdown_output is not None:
        parts.extend(["--markdown-output", str(args.markdown_output)])
    return " ".join(shlex.quote(part) for part in parts)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit regenerated audio for current N4 FLAG review rows.")
    parser.add_argument("--review-csv", type=Path, default=DEFAULT_REVIEW_CSV, help="Post-regeneration review CSV.")
    parser.add_argument(
        "--regeneration-results-csv",
        type=Path,
        default=DEFAULT_REGENERATION_RESULTS_CSV,
        help="Regeneration result CSV used to validate provider/model/source/url drift.",
    )
    parser.add_argument("--skip-silence-check", action="store_true", help="Skip ffmpeg silencedetect pass.")
    parser.add_argument("--timeout-seconds", type=float, default=15.0, help="HTTP download timeout.")
    parser.add_argument("--transcribe", action="store_true", help="Run AI STT and compare transcript with source text.")
    parser.add_argument("--csv-output", type=Path, default=None, help="Write apply-compatible recommendation CSV.")
    parser.add_argument("--markdown-output", type=Path, default=None, help="Write Markdown audit report.")
    parser.add_argument("--fail-on-flag", action="store_true", help="Exit with status 1 if any row is still recommended FLAG.")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    metadata = read_regeneration_metadata(args.regeneration_results_csv)
    targets = read_review_targets(args.review_csv, regeneration_metadata=metadata)
    report = await audit_targets(
        targets,
        check_silence=not args.skip_silence_check,
        timeout_seconds=args.timeout_seconds,
        run_transcription=args.transcribe,
    )
    _print_human(report)
    if args.csv_output is not None:
        row_count = write_recommendation_csv(args.csv_output, report)
        print(f"recommendation_csv {_display_path(_resolve_output_path(args.csv_output))} rows={row_count}")
    if args.markdown_output is not None:
        markdown_output = _resolve_output_path(args.markdown_output)
        markdown_output.parent.mkdir(parents=True, exist_ok=True)
        markdown_output.write_text(
            render_markdown(
                report,
                command=_command_string(args),
                review_csv=args.review_csv,
                regeneration_results_csv=args.regeneration_results_csv,
            ),
            encoding="utf-8",
        )
        print(f"markdown_report {_display_path(markdown_output)}")
    if args.fail_on_flag and report.recommended_flag_count:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
