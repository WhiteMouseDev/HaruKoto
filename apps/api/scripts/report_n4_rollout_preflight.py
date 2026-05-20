from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
API_DIR = SCRIPT_DIR.parent
REPO_ROOT = API_DIR.parent.parent


@dataclass(frozen=True)
class CommandCheck:
    name: str
    command: list[str]
    cwd: str
    exit_code: int
    stdout: str
    stderr: str

    @property
    def passed(self) -> bool:
        return self.exit_code == 0


@dataclass(frozen=True)
class TtsCoverageSummary:
    lesson_count: int
    expected_total_records: int
    generated_total_records: int
    audio_urls_checked: int | None
    audio_urls_failed: int | None
    blockers: list[str]
    signals: list[str]

    @property
    def passed(self) -> bool:
        return self.generated_total_records == self.expected_total_records and not self.blockers


@dataclass(frozen=True)
class AudioVerdictSummary:
    targets: int
    pass_count: int
    pending_count: int
    flag_count: int
    fail_count: int
    waived_count: int
    invalid_count: int
    blockers: list[str]

    @property
    def passed(self) -> bool:
        return not self.blockers


@dataclass(frozen=True)
class RolloutPreflightReport:
    generated_at: str
    level: str
    overall_status: str
    command_checks: list[CommandCheck]
    tts_coverage: TtsCoverageSummary
    audio_verdicts: AudioVerdictSummary
    blockers: list[str]
    assumptions: list[str]


def _utc_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def _run_command(name: str, command: list[str], *, cwd: Path) -> CommandCheck:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)
    return CommandCheck(
        name=name,
        command=command,
        cwd=str(cwd),
        exit_code=completed.returncode,
        stdout=completed.stdout.strip(),
        stderr=completed.stderr.strip(),
    )


def _run_json_command(name: str, command: list[str], *, cwd: Path) -> tuple[CommandCheck, dict[str, Any]]:
    check = _run_command(name, command, cwd=cwd)
    payload: dict[str, Any] = {}
    if check.stdout:
        try:
            payload = json.loads(check.stdout)
        except json.JSONDecodeError as error:
            payload = {"json_error": str(error)}
    return check, payload


def _summarize_tts_coverage(payload: dict[str, Any]) -> TtsCoverageSummary:
    audio_url_check = payload.get("audio_url_check")
    return TtsCoverageSummary(
        lesson_count=int(payload.get("lesson_count") or 0),
        expected_total_records=int(payload.get("expected_total_records") or 0),
        generated_total_records=int(payload.get("generated_total_records") or 0),
        audio_urls_checked=audio_url_check.get("checked_records") if isinstance(audio_url_check, dict) else None,
        audio_urls_failed=audio_url_check.get("failed_records") if isinstance(audio_url_check, dict) else None,
        blockers=list(payload.get("blockers") or []),
        signals=list(payload.get("signals") or []),
    )


def _summarize_audio_verdicts(payload: dict[str, Any]) -> AudioVerdictSummary:
    return AudioVerdictSummary(
        targets=int(payload.get("total_targets") or 0),
        pass_count=int(payload.get("pass_count") or 0),
        pending_count=int(payload.get("pending_count") or 0),
        flag_count=int(payload.get("flag_count") or 0),
        fail_count=int(payload.get("fail_count") or 0),
        waived_count=int(payload.get("waived_count") or 0),
        invalid_count=len(payload.get("invalid_verdicts") or []),
        blockers=list(payload.get("blockers") or []),
    )


def _build_report(args: argparse.Namespace) -> RolloutPreflightReport:
    level = args.level.upper()
    if level != "N4":
        raise SystemExit("Only N4 rollout preflight is currently supported.")

    command_checks: list[CommandCheck] = []

    command_checks.append(
        _run_command(
            "curriculum_validate",
            ["pnpm", "--filter", "@harukoto/database", "curriculum:validate"],
            cwd=REPO_ROOT,
        )
    )
    command_checks.append(
        _run_command(
            "lesson_seed_sync_check",
            [sys.executable, "-m", "app.seeds.lessons", "--check", "--level", level],
            cwd=API_DIR,
        )
    )

    tts_command = [
        sys.executable,
        "scripts/report_n4_pilot_tts_coverage.py",
        "--level",
        level,
        "--timeout-seconds",
        str(args.timeout_seconds),
        "--json",
    ]
    if not args.skip_audio_urls:
        tts_command.append("--check-audio-urls")
    tts_check, tts_payload = _run_json_command("tts_coverage", tts_command, cwd=API_DIR)
    command_checks.append(tts_check)

    verdict_check, verdict_payload = _run_json_command(
        "audio_qa_verdicts",
        [sys.executable, "scripts/report_n4_audio_qa_verdicts.py", "--json"],
        cwd=API_DIR,
    )
    command_checks.append(verdict_check)

    tts_coverage = _summarize_tts_coverage(tts_payload)
    audio_verdicts = _summarize_audio_verdicts(verdict_payload)
    blockers = [f"{check.name.upper()}_FAILED: exit {check.exit_code}" for check in command_checks if not check.passed]
    blockers.extend(f"TTS_COVERAGE: {blocker}" for blocker in tts_coverage.blockers)
    blockers.extend(f"AUDIO_QA: {blocker}" for blocker in audio_verdicts.blockers)

    return RolloutPreflightReport(
        generated_at=_utc_now(),
        level=level,
        overall_status="PASS" if not blockers and tts_coverage.passed and audio_verdicts.passed else "BLOCKED",
        command_checks=command_checks,
        tts_coverage=tts_coverage,
        audio_verdicts=audio_verdicts,
        blockers=blockers,
        assumptions=[
            "This preflight is read-only and does not seed DB rows, generate TTS, or change packet verdicts.",
            "Delegated AI/STT audio QA is not native-speaker approval.",
            "GOOGLE_API_KEY is only required by separate --transcribe STT-audit flows, not by this preflight.",
        ],
    )


def _command_text(check: CommandCheck) -> str:
    return " ".join(check.command)


def _render_markdown(report: RolloutPreflightReport) -> str:
    lines = [
        f"# {report.level} Seed/TTS Rollout Preflight",
        "",
        f"> Generated: {report.generated_at}",
        f"> Status: {report.overall_status}",
        "> Boundary: read-only rollout readiness check; not native-speaker approval",
        "",
        "## Summary",
        "",
        "| Gate | Result | Evidence |",
        "|---|---|---|",
    ]

    for check in report.command_checks:
        result = "PASS" if check.passed else "FAIL"
        lines.append(f"| `{check.name}` | {result} | exit {check.exit_code} |")

    tts = report.tts_coverage
    lines.append(
        f"| `tts_coverage` | {'PASS' if tts.passed else 'FAIL'} | "
        f"{tts.generated_total_records}/{tts.expected_total_records} records; "
        f"audio URL failures={tts.audio_urls_failed if tts.audio_urls_failed is not None else 'not checked'} |"
    )
    verdicts = report.audio_verdicts
    lines.append(
        f"| `audio_qa_verdicts` | {'PASS' if verdicts.passed else 'FAIL'} | "
        f"{verdicts.pass_count}/{verdicts.targets} PASS; pending={verdicts.pending_count}; "
        f"flag={verdicts.flag_count}; fail={verdicts.fail_count}; invalid={verdicts.invalid_count} |"
    )

    lines.extend(["", "## Commands", ""])
    for check in report.command_checks:
        lines.extend(
            [
                f"### {check.name}",
                "",
                "```bash",
                f"cd {check.cwd}",
                _command_text(check),
                "```",
                "",
                f"- Exit: `{check.exit_code}`",
            ]
        )
        if check.stderr:
            lines.extend(["- Stderr:", "", "```text", check.stderr[-2000:], "```"])
        lines.append("")

    lines.extend(["## Signals", ""])
    for signal in report.tts_coverage.signals:
        lines.append(f"- {signal}")
    if not report.tts_coverage.signals:
        lines.append("- None")

    lines.extend(["", "## Blockers", ""])
    if report.blockers:
        lines.extend(f"- {blocker}" for blocker in report.blockers)
    else:
        lines.append("- None")

    lines.extend(["", "## Assumptions", ""])
    lines.extend(f"- ASSUMPTION: {assumption}" for assumption in report.assumptions)
    lines.append("")
    return "\n".join(lines)


def _print_human(report: RolloutPreflightReport) -> None:
    print(f"level {report.level}")
    print(f"status {report.overall_status}")
    print("commands")
    for check in report.command_checks:
        result = "PASS" if check.passed else "FAIL"
        print(f"- {check.name}: {result} exit={check.exit_code}")
    print(
        "tts_coverage "
        f"{report.tts_coverage.generated_total_records}/{report.tts_coverage.expected_total_records} "
        f"audio_url_failures={report.tts_coverage.audio_urls_failed}"
    )
    print(
        "audio_qa "
        f"targets={report.audio_verdicts.targets} pass={report.audio_verdicts.pass_count} "
        f"pending={report.audio_verdicts.pending_count} flag={report.audio_verdicts.flag_count} "
        f"fail={report.audio_verdicts.fail_count} invalid={report.audio_verdicts.invalid_count}"
    )
    print("blockers")
    if report.blockers:
        for blocker in report.blockers:
            print(f"- {blocker}")
    else:
        print("- none")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the read-only N4 seed/TTS rollout preflight.")
    parser.add_argument("--level", default="N4", help="JLPT level. Currently only N4 is supported.")
    parser.add_argument("--skip-audio-urls", action="store_true", help="Skip read-only HTTP validation of TTS URLs.")
    parser.add_argument("--timeout-seconds", type=float, default=10.0, help="Timeout for each audio URL HTTP check.")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of the default line-oriented report.")
    parser.add_argument("--markdown-output", type=Path, default=None, help="Write a markdown evidence report.")
    parser.add_argument("--fail-on-blocker", action="store_true", help="Exit 1 when any rollout blocker remains.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    report = _build_report(args)

    if args.markdown_output is not None:
        output_path = args.markdown_output
        if not output_path.is_absolute():
            output_path = (Path.cwd() / output_path).resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(_render_markdown(report), encoding="utf-8")
        print(f"markdown_report {output_path.relative_to(REPO_ROOT)}")

    if args.json:
        print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    else:
        _print_human(report)

    if args.fail_on_blocker and report.overall_status != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
