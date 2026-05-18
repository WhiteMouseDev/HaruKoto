from __future__ import annotations

import argparse
import csv
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from scripts.build_n4_audio_qa_review_queue import _display_path, _markdown_cell, default_machine_report_paths, default_packet_paths
from scripts.build_n4_audio_qa_stt_reconciliation import SttReconciliationItem, build_reconciliation_report

PASS_BUCKET = "MIXED_PROMPT_STT_UNRELIABLE"
PASS_PRIORITY = "P1 STT mismatch"
PASS_NOTE = (
    "Delegated AI-assisted PASS: machine preflight passed and STT mismatch is attributable "
    "to mixed Japanese/Korean/cloze prompt; not native-speaker review."
)
CSV_COLUMNS = [
    "target_key",
    "packet",
    "priority",
    "bucket",
    "similarity",
    "review_signals",
    "japanese_text",
    "korean_context",
    "stt_transcript",
    "audio_url",
    "decision_basis",
    "new_verdict",
    "new_notes",
]


@dataclass(frozen=True)
class DelegatedPendingClearanceReport:
    total_review_items: int
    pending_review_signal_items: int
    approved_count: int
    held_count: int
    held_bucket_counts: dict[str, int]
    approved_items: list[SttReconciliationItem]
    held_items: list[SttReconciliationItem]


def is_delegated_pass_item(item: SttReconciliationItem) -> bool:
    return item.bucket == PASS_BUCKET and item.priority == PASS_PRIORITY


def build_clearance_report(
    *,
    packet_paths: list[Path],
    machine_report_paths: list[Path],
) -> DelegatedPendingClearanceReport:
    reconciliation = build_reconciliation_report(packet_paths=packet_paths, machine_report_paths=machine_report_paths)
    approved_items = [item for item in reconciliation.items if is_delegated_pass_item(item)]
    held_items = [item for item in reconciliation.items if not is_delegated_pass_item(item)]
    held_bucket_counts = Counter(item.bucket for item in held_items)
    return DelegatedPendingClearanceReport(
        total_review_items=reconciliation.total_review_items,
        pending_review_signal_items=reconciliation.pending_review_signal_items,
        approved_count=len(approved_items),
        held_count=len(held_items),
        held_bucket_counts=dict(held_bucket_counts),
        approved_items=approved_items,
        held_items=held_items,
    )


def _render_items(items: list[SttReconciliationItem], *, include_verdict: bool) -> list[str]:
    if not items:
        return ["- None"]

    lines = [
        "| Target | Bucket | Source text | STT transcript | Similarity | Decision | Audio | Packet |",
        "|---|---|---|---|---:|---|---|---|",
    ]
    for item in items:
        audio = f"[audio]({item.audio_url})" if item.audio_url else ""
        decision = "PASS" if include_verdict else "HOLD"
        lines.append(
            "| "
            f"{_markdown_cell(item.target_key)} | "
            f"{_markdown_cell(item.bucket)} | "
            f"{_markdown_cell(item.source_text)} | "
            f"{_markdown_cell(item.transcript)} | "
            f"{item.similarity:.3f} | "
            f"{decision} | "
            f"{audio} | "
            f"`{_markdown_cell(item.packet)}` |"
        )
    return lines


def render_markdown(
    report: DelegatedPendingClearanceReport,
    *,
    packet_paths: list[Path],
    machine_report_paths: list[Path],
) -> str:
    lines = [
        "# N4 Audio QA Delegated Pending Clearance",
        "",
        "> Status: MIXED-PROMPT PASS CSV GENERATED",
        "> Boundary: delegated AI-assisted verdicts only; not native-speaker approval",
        "",
        "ASSUMPTION: A `MIXED_PROMPT_STT_UNRELIABLE` row has Japanese/Korean,",
        "cloze blanks, or Korean arrangement instructions that make single-language",
        "STT mismatch weak evidence. Rows with `HIGH_SILENCE_RATIO` machine warnings",
        "or script-line near matches are intentionally held.",
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
            f"| Total review items | {report.total_review_items} |",
            f"| Pending review-signal items evaluated | {report.pending_review_signal_items} |",
            f"| Delegated PASS rows in CSV | {report.approved_count} |",
            f"| Held rows left pending | {report.held_count} |",
            "",
            "## Held Bucket Counts",
            "",
            "| Bucket | Count |",
            "|---|---:|",
        ]
    )
    for bucket, count in sorted(report.held_bucket_counts.items()):
        lines.append(f"| {_markdown_cell(bucket)} | {count} |")

    lines.extend(
        [
            "",
            "## CSV Apply Contract",
            "",
            "The companion CSV is compatible with",
            "`scripts/apply_n4_audio_qa_verdicts.py --csv-input`. Only rows that meet",
            "the mixed-prompt criteria receive `new_verdict=PASS`; held rows keep blank",
            "`new_verdict` and `new_notes` so the apply script ignores them.",
            "",
            "## Delegated PASS Rows",
            "",
        ]
    )
    lines.extend(_render_items(report.approved_items, include_verdict=True))
    lines.extend(
        [
            "",
            "## Held Rows",
            "",
            "These rows remain pending because they require listening or regeneration",
            "judgment beyond the mixed-prompt STT false-positive rule.",
            "",
        ]
    )
    lines.extend(_render_items(report.held_items, include_verdict=False))
    lines.extend(
        [
            "",
            "## Decision",
            "",
            "Apply the CSV to clear mixed-prompt STT false positives first.",
            "Broad/full N4 rollout remains blocked until the held rows are reviewed or regenerated.",
            "",
        ]
    )
    return "\n".join(lines)


def write_clearance_csv(csv_output: Path, report: DelegatedPendingClearanceReport) -> int:
    csv_output.parent.mkdir(parents=True, exist_ok=True)
    with csv_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for item in [*report.approved_items, *report.held_items]:
            approved = is_delegated_pass_item(item)
            writer.writerow(
                {
                    "target_key": item.target_key,
                    "packet": item.packet,
                    "priority": item.priority,
                    "bucket": item.bucket,
                    "similarity": f"{item.similarity:.3f}",
                    "review_signals": ", ".join(item.review_signals),
                    "japanese_text": item.source_text,
                    "korean_context": item.korean_context,
                    "stt_transcript": item.transcript,
                    "audio_url": item.audio_url,
                    "decision_basis": (
                        "mixed prompt STT false-positive lane" if approved else "held for direct listening/regeneration judgment"
                    ),
                    "new_verdict": "PASS" if approved else "",
                    "new_notes": PASS_NOTE if approved else "",
                }
            )
    return report.approved_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build an apply-ready N4 audio QA delegated pending-clearance CSV.")
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
    parser.add_argument("--markdown-output", type=Path, required=True, help="Markdown clearance report output path.")
    parser.add_argument("--csv-output", type=Path, required=True, help="Apply-ready CSV output path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    packet_paths = args.packet or default_packet_paths()
    machine_report_paths = args.machine_report or default_machine_report_paths()
    report = build_clearance_report(packet_paths=packet_paths, machine_report_paths=machine_report_paths)

    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.write_text(
        render_markdown(report, packet_paths=packet_paths, machine_report_paths=machine_report_paths),
        encoding="utf-8",
    )
    write_clearance_csv(args.csv_output, report)

    print(f"delegated_pending_clearance_report {_display_path(args.markdown_output)}")
    print(f"delegated_pending_clearance_csv {_display_path(args.csv_output)}")
    print(f"items {report.total_review_items}")
    print(f"pending_review_signal_items {report.pending_review_signal_items}")
    print(f"delegated_pass {report.approved_count}")
    print(f"held_pending {report.held_count}")


if __name__ == "__main__":
    main()
