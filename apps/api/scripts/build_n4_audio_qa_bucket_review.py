from __future__ import annotations

import argparse
import csv
from collections import Counter
from dataclasses import dataclass
from html import escape
from pathlib import Path
from typing import cast

from scripts.build_n4_audio_qa_review_queue import (
    _display_path,
    _html_text,
    _markdown_cell,
    default_machine_report_paths,
    default_packet_paths,
)
from scripts.build_n4_audio_qa_stt_reconciliation import (
    Bucket,
    SttReconciliationItem,
    build_reconciliation_report,
)

BUCKET_CHOICES: tuple[Bucket, ...] = (
    "P0_MACHINE_WARNING",
    "LEXICAL_RISK",
    "NEAR_JAPANESE_MATCH",
    "CANONICAL_MATCH",
    "MIXED_PROMPT_STT_UNRELIABLE",
    "NO_STT_TRANSCRIPT",
)
DEFAULT_BUCKETS: tuple[Bucket, ...] = ("LEXICAL_RISK",)
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
    "recommended_action",
    "new_verdict",
    "new_notes",
]


@dataclass(frozen=True)
class BucketReviewReport:
    total_review_items: int
    pending_review_signal_items: int
    selected_count: int
    buckets: tuple[Bucket, ...]
    selected_bucket_counts: dict[str, int]
    items: list[SttReconciliationItem]


def _normalize_buckets(raw_buckets: list[str] | None) -> tuple[Bucket, ...]:
    if not raw_buckets:
        return DEFAULT_BUCKETS

    normalized: list[Bucket] = []
    for raw_bucket in raw_buckets:
        bucket = cast(Bucket, raw_bucket)
        if bucket not in normalized:
            normalized.append(bucket)
    return tuple(normalized)


def build_bucket_review_report(
    *,
    packet_paths: list[Path],
    machine_report_paths: list[Path],
    buckets: tuple[Bucket, ...] = DEFAULT_BUCKETS,
) -> BucketReviewReport:
    reconciliation = build_reconciliation_report(packet_paths=packet_paths, machine_report_paths=machine_report_paths)
    selected_items = [item for item in reconciliation.items if item.bucket in buckets]
    selected_bucket_counts = Counter(item.bucket for item in selected_items)

    return BucketReviewReport(
        total_review_items=reconciliation.total_review_items,
        pending_review_signal_items=reconciliation.pending_review_signal_items,
        selected_count=len(selected_items),
        buckets=buckets,
        selected_bucket_counts=dict(selected_bucket_counts),
        items=selected_items,
    )


def _render_items(items: list[SttReconciliationItem]) -> list[str]:
    if not items:
        return ["- None"]

    lines = [
        "| Bucket | Target | Source text | STT transcript | Similarity | Recommended action | Audio | Packet |",
        "|---|---|---|---|---:|---|---|---|",
    ]
    for item in items:
        audio = f"[audio]({item.audio_url})" if item.audio_url else ""
        lines.append(
            "| "
            f"{_markdown_cell(item.bucket)} | "
            f"{_markdown_cell(item.target_key)} | "
            f"{_markdown_cell(item.source_text)} | "
            f"{_markdown_cell(item.transcript)} | "
            f"{item.similarity:.3f} | "
            f"{_markdown_cell(item.recommended_action)} | "
            f"{audio} | "
            f"`{_markdown_cell(item.packet)}` |"
        )
    return lines


def render_markdown(report: BucketReviewReport, *, packet_paths: list[Path], machine_report_paths: list[Path]) -> str:
    bucket_label = ", ".join(report.buckets)
    lines = [
        "# N4 Audio QA Bucket Review Batch",
        "",
        "> Status: FOCUSED REVIEW BATCH - no verdicts applied",
        "> Boundary: listening/inspection aid only; does not replace native-speaker review",
        "",
        "ASSUMPTION: This batch narrows the next review pass to the selected STT",
        "reconciliation bucket(s). It does not set `PASS`, `FLAG`, `FAIL`, or",
        "`WAIVED` on any packet row.",
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
            f"| Pending review-signal items | {report.pending_review_signal_items} |",
            f"| Selected review items | {report.selected_count} |",
            f"| Selected buckets | {_markdown_cell(bucket_label)} |",
            "",
            "## Selected Bucket Counts",
            "",
            "| Bucket | Count |",
            "|---|---:|",
        ]
    )
    for bucket in report.buckets:
        lines.append(f"| {_markdown_cell(bucket)} | {report.selected_bucket_counts.get(bucket, 0)} |")

    lines.extend(
        [
            "",
            "## CSV Apply Boundary",
            "",
            "The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those",
            "columns only after direct listening or an explicitly delegated review step.",
            "Blank rows are ignored by `scripts/apply_n4_audio_qa_verdicts.py`.",
            "",
            "## Review Items",
            "",
        ]
    )
    lines.extend(_render_items(report.items))
    lines.extend(
        [
            "",
            "## Decision",
            "",
            "Use this focused batch before lower-risk STT lanes. Broad/full N4 rollout",
            "remains blocked until packet verdicts contain no `PENDING`, `FLAG`, `FAIL`,",
            "or invalid values.",
            "",
        ]
    )
    return "\n".join(lines)


def _html_item_card(item: SttReconciliationItem) -> str:
    return "\n".join(
        [
            '<article class="review-card">',
            '  <div class="review-card__meta">',
            f"    <span>{_html_text(item.bucket)}</span>",
            f"    <span>{_html_text(item.target_key)}</span>",
            f"    <span>{item.similarity:.3f}</span>",
            "  </div>",
            f"  <h3>{_html_text(item.source_text)}</h3>",
            f"  <p>{_html_text(item.korean_context)}</p>",
            f'  <audio controls preload="none" src="{escape(item.audio_url, quote=True)}"></audio>',
            '  <dl class="review-card__details">',
            f"    <dt>STT</dt><dd>{_html_text(item.transcript)}</dd>",
            f"    <dt>Action</dt><dd>{_html_text(item.recommended_action)}</dd>",
            f"    <dt>Signals</dt><dd>{_html_text(', '.join(item.review_signals))}</dd>",
            f"    <dt>Packet</dt><dd>{_html_text(item.packet)}</dd>",
            "  </dl>",
            "</article>",
        ]
    )


def render_html(report: BucketReviewReport, *, packet_paths: list[Path], machine_report_paths: list[Path]) -> str:
    source_items = "\n".join(f"<li><code>{_html_text(_display_path(path))}</code></li>" for path in [*packet_paths, *machine_report_paths])
    review_items = (
        '<p class="empty">No selected review items.</p>' if not report.items else "\n".join(_html_item_card(item) for item in report.items)
    )
    bucket_label = ", ".join(report.buckets)

    return "\n".join(
        [
            "<!doctype html>",
            '<html lang="en">',
            "<head>",
            '  <meta charset="utf-8">',
            '  <meta name="viewport" content="width=device-width, initial-scale=1">',
            "  <title>N4 Audio QA Bucket Review Sheet</title>",
            "  <style>",
            "    :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }",
            "    body { margin: 0; background: #f6f7f4; color: #22251f; }",
            "    main { max-width: 980px; margin: 0 auto; padding: 40px 20px 80px; }",
            "    header { margin-bottom: 32px; }",
            "    h1 { margin: 0 0 8px; font-size: 32px; line-height: 1.2; }",
            "    h2 { margin: 36px 0 16px; font-size: 22px; }",
            "    h3 { margin: 10px 0 8px; font-size: 20px; line-height: 1.35; }",
            "    p { color: #5d6558; line-height: 1.6; }",
            "    code { background: #e8ebe2; border-radius: 4px; padding: 2px 4px; }",
            "    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; }",
            "    .metric { background: #fff; border: 1px solid #dde4d7; border-radius: 8px; padding: 14px; }",
            "    .metric strong { display: block; font-size: 24px; margin-top: 4px; }",
            "    .review-card { background: #fff; border: 1px solid #e2d7cc; border-radius: 8px; "
            "padding: 18px; margin: 12px 0; box-shadow: inset 4px 0 0 #bf6f36; }",
            "    .review-card__meta { display: flex; flex-wrap: wrap; gap: 8px; }",
            "    .review-card__meta span { background: #f3e6da; border-radius: 999px; padding: 5px 10px; font-size: 13px; }",
            "    audio { width: 100%; margin: 10px 0 12px; }",
            "    .review-card__details { display: grid; grid-template-columns: 88px 1fr; gap: 6px 10px; margin: 0; }",
            "    dt { color: #745b46; font-weight: 700; }",
            "    dd { margin: 0; overflow-wrap: anywhere; }",
            "    .empty { background: #fff; border: 1px dashed #cdc9be; border-radius: 8px; padding: 16px; }",
            "  </style>",
            "</head>",
            "<body>",
            "<main>",
            "  <header>",
            "    <h1>N4 Audio QA Bucket Review Sheet</h1>",
            f"    <p>Focused listening surface for <code>{_html_text(bucket_label)}</code>. It does not apply packet verdicts.</p>",
            "  </header>",
            '  <section class="summary" aria-label="Summary">',
            f'    <div class="metric">Total review items<strong>{report.total_review_items}</strong></div>',
            f'    <div class="metric">Pending signal items<strong>{report.pending_review_signal_items}</strong></div>',
            f'    <div class="metric">Selected items<strong>{report.selected_count}</strong></div>',
            f'    <div class="metric">Buckets<strong>{_html_text(bucket_label)}</strong></div>',
            "  </section>",
            "  <section>",
            "    <h2>Boundary</h2>",
            "    <p>This sheet is a review aid. Fill verdict CSV rows only after direct listening or an explicitly "
            "delegated review step; blank rows remain pending.</p>",
            "  </section>",
            "  <section>",
            "    <h2>Sources</h2>",
            f"    <ul>{source_items}</ul>",
            "  </section>",
            "  <section>",
            "    <h2>Review Items</h2>",
            review_items,
            "  </section>",
            "</main>",
            "</body>",
            "</html>",
        ]
    )


def write_bucket_review_csv(csv_output: Path, report: BucketReviewReport) -> int:
    csv_output.parent.mkdir(parents=True, exist_ok=True)
    with csv_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for item in report.items:
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
                    "recommended_action": item.recommended_action,
                    "new_verdict": "",
                    "new_notes": "",
                }
            )
    return report.selected_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a focused N4 audio QA STT-bucket review batch.")
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
    parser.add_argument(
        "--bucket",
        action="append",
        choices=BUCKET_CHOICES,
        default=None,
        help="STT reconciliation bucket to include. Defaults to LEXICAL_RISK. Repeat for multiple buckets.",
    )
    parser.add_argument("--markdown-output", type=Path, required=True, help="Markdown focused review output path.")
    parser.add_argument("--csv-output", type=Path, default=None, help="Optional focused review CSV output path.")
    parser.add_argument("--html-output", type=Path, default=None, help="Optional static HTML listening sheet output path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    packet_paths = args.packet or default_packet_paths()
    machine_report_paths = args.machine_report or default_machine_report_paths()
    buckets = _normalize_buckets(args.bucket)
    report = build_bucket_review_report(
        packet_paths=packet_paths,
        machine_report_paths=machine_report_paths,
        buckets=buckets,
    )

    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.write_text(
        render_markdown(report, packet_paths=packet_paths, machine_report_paths=machine_report_paths),
        encoding="utf-8",
    )
    print(f"bucket_review_report {_display_path(args.markdown_output)}")
    if args.csv_output:
        write_bucket_review_csv(args.csv_output, report)
        print(f"bucket_review_csv {_display_path(args.csv_output)}")
    if args.html_output:
        args.html_output.parent.mkdir(parents=True, exist_ok=True)
        args.html_output.write_text(
            render_html(report, packet_paths=packet_paths, machine_report_paths=machine_report_paths),
            encoding="utf-8",
        )
        print(f"bucket_review_html {_display_path(args.html_output)}")
    print(f"items {report.pending_review_signal_items}")
    print(f"selected {report.selected_count}")
    for bucket in report.buckets:
        print(f"{bucket.lower()} {report.selected_bucket_counts.get(bucket, 0)}")


if __name__ == "__main__":
    main()
