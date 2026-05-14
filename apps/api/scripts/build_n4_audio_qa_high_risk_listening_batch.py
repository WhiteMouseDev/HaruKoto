from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from html import escape
from pathlib import Path

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

HIGH_RISK_BUCKETS: tuple[Bucket, ...] = ("P0_MACHINE_WARNING", "LEXICAL_RISK")
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
    "current_verdict",
    "recommended_action",
    "new_verdict",
    "new_notes",
]


@dataclass(frozen=True)
class HighRiskListeningBatchReport:
    total_review_items: int
    pending_review_signal_items: int
    batch_count: int
    p0_machine_warning_count: int
    lexical_risk_count: int
    items: list[SttReconciliationItem]


def build_high_risk_listening_batch_report(packet_paths: list[Path], machine_report_paths: list[Path]) -> HighRiskListeningBatchReport:
    reconciliation = build_reconciliation_report(packet_paths=packet_paths, machine_report_paths=machine_report_paths)
    items = [item for item in reconciliation.items if item.bucket in HIGH_RISK_BUCKETS]
    return HighRiskListeningBatchReport(
        total_review_items=reconciliation.total_review_items,
        pending_review_signal_items=reconciliation.pending_review_signal_items,
        batch_count=len(items),
        p0_machine_warning_count=sum(1 for item in items if item.bucket == "P0_MACHINE_WARNING"),
        lexical_risk_count=sum(1 for item in items if item.bucket == "LEXICAL_RISK"),
        items=items,
    )


def _render_items(items: list[SttReconciliationItem]) -> list[str]:
    if not items:
        return ["- None"]
    lines = [
        "| Bucket | Target | Source text | STT transcript | Similarity | Signals | Recommended action | Audio |",
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
            f"{_markdown_cell(', '.join(item.review_signals))} | "
            f"{_markdown_cell(item.recommended_action)} | "
            f"{audio} |"
        )
    return lines


def render_markdown(report: HighRiskListeningBatchReport, *, packet_paths: list[Path], machine_report_paths: list[Path]) -> str:
    p0_items = [item for item in report.items if item.bucket == "P0_MACHINE_WARNING"]
    lexical_items = [item for item in report.items if item.bucket == "LEXICAL_RISK"]

    lines = [
        "# N4 Audio QA High-Risk Listening Batch",
        "",
        "> Status: LISTENING BATCH - no verdicts applied",
        "> Boundary: high-risk audio review surface only; does not approve rollout",
        "",
        "ASSUMPTION: This batch only separates rows that should be listened to",
        "first. It does not set `PASS`, `FLAG`, `FAIL`, or `WAIVED` on any packet",
        "row, and it does not replace native-speaker review.",
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
            f"| High-risk listening batch | {report.batch_count} |",
            f"| P0 machine-warning rows | {report.p0_machine_warning_count} |",
            f"| Lexical-risk rows | {report.lexical_risk_count} |",
            "",
            "## Review Sequence",
            "",
            "1. Listen to `P0_MACHINE_WARNING` rows first. These rows include machine",
            "   warnings such as silence-ratio signals, so pacing or truncation can hide",
            "   behind an otherwise reachable audio URL.",
            "2. Listen to `LEXICAL_RISK` rows next. These rows have Japanese source/STT",
            "   divergence large enough that wrong-word audio is plausible.",
            "3. Leave `new_verdict` and `new_notes` blank until direct listening or an",
            "   explicitly delegated review step confirms the audio quality.",
            "",
            "## P0_MACHINE_WARNING",
            "",
        ]
    )
    lines.extend(_render_items(p0_items))
    lines.extend(["", "## LEXICAL_RISK", ""])
    lines.extend(_render_items(lexical_items))
    lines.extend(
        [
            "",
            "## CSV And HTML Use",
            "",
            "The companion CSV is an input worksheet only. The HTML file is a static",
            "listening surface with audio controls. Neither file applies verdicts.",
            "",
            "## Decision",
            "",
            "Broad/full N4 rollout remains blocked. This batch makes the first listening",
            "slice explicit but does not lower the audio-quality verdict gate.",
            "",
        ]
    )
    return "\n".join(lines)


def _html_card(item: SttReconciliationItem) -> str:
    return "\n".join(
        [
            f'<article class="qa-card {item.bucket.lower()}">',
            '  <div class="qa-card__meta">',
            f"    <span>{_html_text(item.bucket)}</span>",
            f"    <span>{_html_text(item.target_key)}</span>",
            f"    <span>{_html_text(item.priority)}</span>",
            "  </div>",
            '  <div class="qa-card__text-grid">',
            "    <section>",
            "      <h3>Source</h3>",
            f"      <p>{_html_text(item.source_text)}</p>",
            "    </section>",
            "    <section>",
            "      <h3>STT Transcript</h3>",
            f"      <p>{_html_text(item.transcript or 'none')}</p>",
            "    </section>",
            "  </div>",
            f'  <p class="context">{_html_text(item.korean_context)}</p>',
            f'  <audio controls preload="none" src="{escape(item.audio_url, quote=True)}"></audio>',
            '  <dl class="qa-card__details">',
            f"    <dt>Similarity</dt><dd>{item.similarity:.3f}</dd>",
            f"    <dt>Signals</dt><dd>{_html_text(', '.join(item.review_signals))}</dd>",
            f"    <dt>Action</dt><dd>{_html_text(item.recommended_action)}</dd>",
            f"    <dt>Packet</dt><dd>{_html_text(item.packet)}</dd>",
            "  </dl>",
            "</article>",
        ]
    )


def _html_section(title: str, items: list[SttReconciliationItem]) -> str:
    body = '<p class="empty">No items.</p>' if not items else "\n".join(_html_card(item) for item in items)
    return "\n".join([f"<section><h2>{_html_text(title)}</h2>", body, "</section>"])


def render_html(report: HighRiskListeningBatchReport, *, packet_paths: list[Path], machine_report_paths: list[Path]) -> str:
    p0_items = [item for item in report.items if item.bucket == "P0_MACHINE_WARNING"]
    lexical_items = [item for item in report.items if item.bucket == "LEXICAL_RISK"]
    source_items = "\n".join(f"<li><code>{_html_text(_display_path(path))}</code></li>" for path in [*packet_paths, *machine_report_paths])

    return "\n".join(
        [
            "<!doctype html>",
            '<html lang="en">',
            "<head>",
            '  <meta charset="utf-8">',
            '  <meta name="viewport" content="width=device-width, initial-scale=1">',
            "  <title>N4 Audio QA High-Risk Listening Batch</title>",
            "  <style>",
            "    :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }",
            "    body { margin: 0; background: #f8f5f2; color: #24211f; }",
            "    main { max-width: 1040px; margin: 0 auto; padding: 40px 20px 80px; }",
            "    header { margin-bottom: 32px; }",
            "    h1 { margin: 0 0 8px; font-size: 32px; line-height: 1.2; }",
            "    h2 { margin: 36px 0 16px; font-size: 22px; }",
            "    h3 { margin: 0 0 8px; color: #7a6f67; font-size: 13px; letter-spacing: 0; text-transform: uppercase; }",
            "    p { color: #625b55; line-height: 1.6; }",
            "    code { background: #eee7df; border-radius: 4px; padding: 2px 4px; }",
            "    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; }",
            "    .metric { background: #fff; border: 1px solid #eadfd5; border-radius: 8px; padding: 14px; }",
            "    .metric strong { display: block; font-size: 24px; margin-top: 4px; }",
            "    .qa-card { background: #fff; border: 1px solid #e8ded4; border-radius: 8px; padding: 18px; margin: 12px 0; }",
            "    .qa-card.p0_machine_warning { border-color: #f1a0a8; box-shadow: inset 4px 0 0 #e95f73; }",
            "    .qa-card.lexical_risk { border-color: #f4c27a; box-shadow: inset 4px 0 0 #d9891d; }",
            "    .qa-card__meta { display: flex; flex-wrap: wrap; gap: 8px; }",
            "    .qa-card__meta span { background: #f0e9e2; border-radius: 999px; padding: 5px 10px; font-size: 13px; }",
            "    .qa-card__text-grid { display: grid; grid-template-columns: repeat(auto-fit, "
            "minmax(260px, 1fr)); gap: 14px; margin: 16px 0 4px; }",
            "    .qa-card__text-grid section { background: #fbf8f5; border: 1px solid #eee3da; border-radius: 8px; padding: 14px; }",
            "    .qa-card__text-grid p { margin: 0; color: #24211f; font-size: 18px; overflow-wrap: anywhere; }",
            "    .context { margin: 10px 0; }",
            "    audio { width: 100%; margin: 10px 0 12px; }",
            "    .qa-card__details { display: grid; grid-template-columns: 100px 1fr; gap: 6px 10px; margin: 0; }",
            "    dt { color: #7a6f67; font-weight: 700; }",
            "    dd { margin: 0; overflow-wrap: anywhere; }",
            "    .empty { background: #fff; border: 1px dashed #d8cbc0; border-radius: 8px; padding: 16px; }",
            "  </style>",
            "</head>",
            "<body>",
            "<main>",
            "  <header>",
            "    <h1>N4 Audio QA High-Risk Listening Batch</h1>",
            "    <p>Read-only listening surface for the rows that should be heard first. "
            "Record final verdicts in the CSV or packet workflow.</p>",
            "  </header>",
            '  <section class="summary" aria-label="Summary">',
            f'    <div class="metric">Total review items<strong>{report.total_review_items}</strong></div>',
            f'    <div class="metric">Pending signal items<strong>{report.pending_review_signal_items}</strong></div>',
            f'    <div class="metric">High-risk batch<strong>{report.batch_count}</strong></div>',
            f'    <div class="metric">P0 / Lexical<strong>{report.p0_machine_warning_count} / {report.lexical_risk_count}</strong></div>',
            "  </section>",
            "  <section>",
            "    <h2>Boundary</h2>",
            "    <p>This file does not apply PASS, FLAG, FAIL, or WAIVED. Use it only to listen before recording an explicit verdict.</p>",
            "  </section>",
            "  <section>",
            "    <h2>Sources</h2>",
            f"    <ul>{source_items}</ul>",
            "  </section>",
            _html_section("P0 Machine Warnings", p0_items),
            _html_section("Lexical Risk", lexical_items),
            "</main>",
            "</body>",
            "</html>",
        ]
    )


def write_high_risk_csv(csv_output: Path, report: HighRiskListeningBatchReport) -> int:
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
                    "current_verdict": "PENDING",
                    "recommended_action": item.recommended_action,
                    "new_verdict": "",
                    "new_notes": "",
                }
            )
    return report.batch_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build N4 audio QA high-risk listening batch artifacts.")
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
    parser.add_argument("--markdown-output", type=Path, required=True, help="Markdown high-risk batch output path.")
    parser.add_argument("--csv-output", type=Path, default=None, help="Optional high-risk CSV output path.")
    parser.add_argument("--html-output", type=Path, default=None, help="Optional static HTML listening sheet output path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    packet_paths = args.packet or default_packet_paths()
    machine_report_paths = args.machine_report or default_machine_report_paths()
    report = build_high_risk_listening_batch_report(packet_paths=packet_paths, machine_report_paths=machine_report_paths)

    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.write_text(
        render_markdown(report, packet_paths=packet_paths, machine_report_paths=machine_report_paths),
        encoding="utf-8",
    )
    print(f"high_risk_listening_batch {_display_path(args.markdown_output)}")
    if args.csv_output:
        write_high_risk_csv(args.csv_output, report)
        print(f"high_risk_listening_csv {_display_path(args.csv_output)}")
    if args.html_output:
        args.html_output.parent.mkdir(parents=True, exist_ok=True)
        args.html_output.write_text(
            render_html(report, packet_paths=packet_paths, machine_report_paths=machine_report_paths),
            encoding="utf-8",
        )
        print(f"high_risk_listening_html {_display_path(args.html_output)}")
    print(f"items {report.batch_count}")
    print(f"p0_machine_warning {report.p0_machine_warning_count}")
    print(f"lexical_risk {report.lexical_risk_count}")


if __name__ == "__main__":
    main()
