from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path

from scripts.build_n4_audio_qa_review_queue import (
    ReviewQueueItem,
    _display_path,
    _markdown_cell,
    build_queue,
    default_machine_report_paths,
    default_packet_paths,
)

CANDIDATE_REASON = "machine pass + no parsed machine/STT review signal"
CANDIDATE_ACTION = "listen once; if complete and intelligible, set new_verdict=PASS"
CSV_COLUMNS = [
    "target_key",
    "packet",
    "priority",
    "japanese_text",
    "korean_context",
    "audio_url",
    "current_verdict",
    "candidate_reason",
    "recommended_action",
    "new_verdict",
    "new_notes",
]


@dataclass(frozen=True)
class PassCandidateReport:
    total_items: int
    pending_count: int
    candidate_count: int
    held_for_review_count: int
    machine_warning_count: int
    stt_mismatch_count: int
    candidates: list[ReviewQueueItem]
    held_for_review: list[ReviewQueueItem]


def is_pass_candidate(item: ReviewQueueItem) -> bool:
    return item.verdict == "PENDING" and item.priority == "P2 pending" and not item.review_signals


def build_candidate_report(packet_paths: list[Path], machine_report_paths: list[Path]) -> PassCandidateReport:
    queue = build_queue(packet_paths=packet_paths, machine_report_paths=machine_report_paths)
    candidates = [item for item in queue.items if is_pass_candidate(item)]
    held_for_review = [item for item in queue.items if item.verdict == "PENDING" and not is_pass_candidate(item)]
    return PassCandidateReport(
        total_items=queue.total_items,
        pending_count=queue.pending_count,
        candidate_count=len(candidates),
        held_for_review_count=len(held_for_review),
        machine_warning_count=queue.machine_warning_count,
        stt_mismatch_count=queue.stt_mismatch_count,
        candidates=candidates,
        held_for_review=held_for_review,
    )


def _render_candidate_items(items: list[ReviewQueueItem]) -> list[str]:
    if not items:
        return ["- None"]
    lines = [
        "| Target | Japanese text | Korean/context | Audio | Candidate reason | Recommended action | Packet |",
        "|---|---|---|---|---|---|---|",
    ]
    for item in items:
        audio = f"[audio]({item.audio_url})" if item.audio_url else ""
        lines.append(
            "| "
            f"{_markdown_cell(item.target_key)} | "
            f"{_markdown_cell(item.japanese_text)} | "
            f"{_markdown_cell(item.korean_context)} | "
            f"{audio} | "
            f"{_markdown_cell(CANDIDATE_REASON)} | "
            f"{_markdown_cell(CANDIDATE_ACTION)} | "
            f"`{_markdown_cell(item.packet)}` |"
        )
    return lines


def render_markdown(report: PassCandidateReport, *, packet_paths: list[Path], machine_report_paths: list[Path]) -> str:
    lines = [
        "# N4 Audio QA AI-Assisted PASS Candidates",
        "",
        "> Status: PASS CANDIDATES - no verdicts applied",
        "> Boundary: machine/STT-assisted triage only; does not approve rollout",
        "",
        "ASSUMPTION: A candidate means the target is still `PENDING`, has machine",
        "audio pass evidence, and has no parsed machine/STT review signal. It is",
        "not a final human audio-quality verdict.",
        "",
        "## Sources",
        "",
    ]
    lines.extend(f"- Packet: `{_display_path(path)}`" for path in packet_paths)
    lines.extend(f"- Quality signal report: `{_display_path(path)}`" for path in machine_report_paths)
    lines.extend(
        [
            "",
            "## Summary",
            "",
            "| Metric | Count |",
            "|---|---:|",
            f"| Total review items | {report.total_items} |",
            f"| Pending verdicts | {report.pending_count} |",
            f"| AI-assisted PASS candidates | {report.candidate_count} |",
            f"| Held for listening/regeneration review | {report.held_for_review_count} |",
            f"| Machine-warning items | {report.machine_warning_count} |",
            f"| STT-mismatch signal items | {report.stt_mismatch_count} |",
            "",
            "## Candidate Criteria",
            "",
            "- Current verdict is `PENDING`.",
            "- Priority is `P2 pending` in the review queue.",
            "- No parsed `HIGH_SILENCE_RATIO`, `TRANSCRIPTION_TEXT_MISMATCH`, or other machine/STT review signal is attached.",
            "- Candidate status only reduces review order; it does not replace listening.",
            "",
            "## Candidate CSV Contract",
            "",
            "The companion CSV leaves `new_verdict` and `new_notes` blank on purpose.",
            "After listening, set `new_verdict=PASS` only for rows that are complete,",
            "intelligible, and acceptable for learner playback. Keep uncertain rows",
            "`PENDING`, or mark `FLAG` / `FAIL` in the source verdict workflow.",
            "",
            "## Candidates",
            "",
        ]
    )
    lines.extend(_render_candidate_items(report.candidates))
    lines.extend(
        [
            "",
            "## Held Items",
            "",
            "P0 machine-warning and P1 STT-mismatch rows stay out of the candidate CSV.",
            "They should be listened to before waiver or regenerated if the signal is",
            "confirmed as a content, clipping, pacing, pronunciation, or prompt-shape issue.",
            "",
            "## Decision",
            "",
            "Use this file to batch the safest listen-once checks first. Broad/full N4",
            "rollout remains blocked until packet verdicts contain no `PENDING`,",
            "`FLAG`, `FAIL`, or invalid values.",
            "",
        ]
    )
    return "\n".join(lines)


def write_candidate_csv(csv_output: Path, report: PassCandidateReport) -> int:
    csv_output.parent.mkdir(parents=True, exist_ok=True)
    with csv_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for item in report.candidates:
            writer.writerow(
                {
                    "target_key": item.target_key,
                    "packet": item.packet,
                    "priority": item.priority,
                    "japanese_text": item.japanese_text,
                    "korean_context": item.korean_context,
                    "audio_url": item.audio_url,
                    "current_verdict": item.verdict,
                    "candidate_reason": CANDIDATE_REASON,
                    "recommended_action": CANDIDATE_ACTION,
                    "new_verdict": "",
                    "new_notes": "",
                }
            )
    return report.candidate_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build N4 audio QA AI-assisted PASS candidate artifacts.")
    parser.add_argument("--packet", action="append", type=Path, default=None, help="Packet markdown path.")
    parser.add_argument(
        "--machine-report",
        "--signal-report",
        action="append",
        dest="machine_report",
        type=Path,
        default=None,
        help="Quality signal report markdown path. Defaults to the latest machine and STT assist reports.",
    )
    parser.add_argument("--markdown-output", type=Path, required=True, help="Markdown candidate report output path.")
    parser.add_argument("--csv-output", type=Path, default=None, help="Optional candidate CSV output path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    packet_paths = args.packet or default_packet_paths()
    machine_report_paths = args.machine_report or default_machine_report_paths()
    report = build_candidate_report(packet_paths=packet_paths, machine_report_paths=machine_report_paths)

    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.write_text(
        render_markdown(report, packet_paths=packet_paths, machine_report_paths=machine_report_paths),
        encoding="utf-8",
    )
    print(f"pass_candidate_report {_display_path(args.markdown_output)}")
    if args.csv_output:
        write_candidate_csv(args.csv_output, report)
        print(f"pass_candidate_csv {_display_path(args.csv_output)}")
    print(f"items {report.total_items}")
    print(f"pending {report.pending_count}")
    print(f"pass_candidates {report.candidate_count}")
    print(f"held_for_review {report.held_for_review_count}")


if __name__ == "__main__":
    main()
