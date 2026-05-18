from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from html import escape
from pathlib import Path

DEFAULT_FLAG_MANIFEST_CSV = Path("docs/operations/plans/n4-human-audio-qa-flag-regeneration-plan-2026-05-14.csv")
DEFAULT_FIRST_REGENERATION_RESULTS_CSV = Path("docs/operations/plans/n4-human-audio-qa-flag-regeneration-results-2026-05-14.csv")
DEFAULT_FIRST_RECOMMENDATIONS_CSV = Path("docs/operations/plans/n4-human-audio-qa-flag-post-regeneration-recommendations-2026-05-18.csv")
DEFAULT_SECOND_REGENERATION_RESULTS_CSV = Path(
    "docs/operations/plans/n4-human-audio-qa-flag-regeneration-second-pass-results-2026-05-18.csv"
)
DEFAULT_SECOND_RECOMMENDATIONS_CSV = Path("docs/operations/plans/n4-human-audio-qa-flag-second-pass-recommendations-2026-05-18.csv")
DEFAULT_MARKDOWN_OUTPUT = Path("docs/operations/plans/n4-human-audio-qa-residual-flag-adjudication-2026-05-18.md")
DEFAULT_CSV_OUTPUT = Path("docs/operations/plans/n4-human-audio-qa-residual-flag-adjudication-2026-05-18.csv")
DEFAULT_HTML_OUTPUT = Path("docs/operations/plans/n4-human-audio-qa-residual-flag-adjudication-2026-05-18.html")
TRANSCRIPTION_MISMATCH_RE = re.compile(r"TRANSCRIPTION_TEXT_MISMATCH:(?P<transcript>.*?)(?:;|$)")

FLAG_MANIFEST_REQUIRED_COLUMNS = {
    "target_key",
    "packet",
    "source_text",
    "korean_context",
    "stt_transcript",
    "review_signals",
    "current_audio_url",
    "current_verdict",
    "current_notes",
}
REGENERATION_RESULTS_REQUIRED_COLUMNS = {
    "target_key",
    "target_id",
    "source_text",
    "status",
    "old_audio_url",
    "new_audio_url",
    "provider",
    "model",
}
RECOMMENDATIONS_REQUIRED_COLUMNS = {
    "target_key",
    "packet",
    "review_signals",
    "japanese_text",
    "korean_context",
    "audio_url",
    "current_verdict",
    "current_notes",
    "new_verdict",
    "new_notes",
}
ADJUDICATION_CSV_COLUMNS = [
    "target_key",
    "packet",
    "priority",
    "review_signals",
    "japanese_text",
    "korean_context",
    "audio_url",
    "current_verdict",
    "current_notes",
    "target_id",
    "provider",
    "model",
    "original_audio_url",
    "original_stt_transcript",
    "first_pass_audio_url",
    "first_pass_stt_transcript",
    "second_pass_audio_url",
    "second_pass_stt_transcript",
    "recommended_next_step",
    "rewrite_candidate",
    "adjudication_decision",
    "best_audio_version",
    "rewrite_notes",
    "new_verdict",
    "new_notes",
]


@dataclass(frozen=True)
class ResidualFlagItem:
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
    original_audio_url: str
    original_stt_transcript: str
    first_pass_audio_url: str
    first_pass_stt_transcript: str
    second_pass_audio_url: str
    second_pass_stt_transcript: str
    recommended_next_step: str
    rewrite_candidate: str


@dataclass(frozen=True)
class ResidualFlagAdjudicationReport:
    total_second_pass_rows: int
    residual_flag_count: int
    residual_pass_count: int
    rewrite_candidate_count: int
    items: list[ResidualFlagItem]


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


def _html_text(value: str) -> str:
    return escape(value, quote=False)


def _html_attr(value: str) -> str:
    return escape(value, quote=True)


def _markdown_cell(value: str | int) -> str:
    return " ".join(str(value).split()).replace("|", "\\|")


def _row_value(row: dict[str, str], column: str) -> str:
    return (row.get(column) or "").strip()


def _read_indexed_csv(path: Path, *, required_columns: set[str]) -> dict[str, dict[str, str]]:
    resolved_input = _resolve_path(path)
    rows: dict[str, dict[str, str]] = {}
    with resolved_input.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        missing_columns = required_columns - set(reader.fieldnames or [])
        if missing_columns:
            missing = ", ".join(sorted(missing_columns))
            raise ValueError(f"{_display_path(resolved_input)} is missing required columns: {missing}")

        for row_number, row in enumerate(reader, start=2):
            target_key = _row_value(row, "target_key")
            if not target_key:
                continue
            if target_key in rows:
                raise ValueError(f"{_display_path(resolved_input)} row {row_number}: duplicate target_key {target_key!r}")
            rows[target_key] = {key: value for key, value in row.items() if key is not None}
    return rows


def _extract_stt_transcript(notes_or_signal: str) -> str:
    match = TRANSCRIPTION_MISMATCH_RE.search(notes_or_signal)
    if match is None:
        return ""
    return match.group("transcript").strip()


def _extract_stt_signal(notes_or_signal: str) -> str:
    transcript = _extract_stt_transcript(notes_or_signal)
    if not transcript:
        return ""
    return f"TRANSCRIPTION_TEXT_MISMATCH:{transcript}"


def _recommended_next_step(item_key: str) -> str:
    return (
        f"Adjudicate {item_key} across original/first/second audio before a third regeneration; "
        "if no version is clearly acceptable, rewrite the source sentence and regenerate from the rewritten source."
    )


def _validate_same_text(target_key: str, *, label: str, actual: str, expected: str) -> None:
    if actual != expected:
        raise ValueError(f"{target_key}: {label} source text drift: {actual!r} != {expected!r}")


def _validate_same_url(target_key: str, *, label: str, actual: str, expected: str) -> None:
    if actual != expected:
        raise ValueError(f"{target_key}: {label} audio URL drift: {actual!r} != {expected!r}")


def build_adjudication_report(
    *,
    flag_manifest_csv: Path = DEFAULT_FLAG_MANIFEST_CSV,
    first_regeneration_results_csv: Path = DEFAULT_FIRST_REGENERATION_RESULTS_CSV,
    first_recommendations_csv: Path = DEFAULT_FIRST_RECOMMENDATIONS_CSV,
    second_regeneration_results_csv: Path = DEFAULT_SECOND_REGENERATION_RESULTS_CSV,
    second_recommendations_csv: Path = DEFAULT_SECOND_RECOMMENDATIONS_CSV,
) -> ResidualFlagAdjudicationReport:
    manifest_rows = _read_indexed_csv(flag_manifest_csv, required_columns=FLAG_MANIFEST_REQUIRED_COLUMNS)
    first_result_rows = _read_indexed_csv(first_regeneration_results_csv, required_columns=REGENERATION_RESULTS_REQUIRED_COLUMNS)
    first_recommendation_rows = _read_indexed_csv(first_recommendations_csv, required_columns=RECOMMENDATIONS_REQUIRED_COLUMNS)
    second_result_rows = _read_indexed_csv(second_regeneration_results_csv, required_columns=REGENERATION_RESULTS_REQUIRED_COLUMNS)
    second_recommendation_rows = _read_indexed_csv(second_recommendations_csv, required_columns=RECOMMENDATIONS_REQUIRED_COLUMNS)

    items: list[ResidualFlagItem] = []
    residual_pass_count = 0
    for target_key, second_recommendation in second_recommendation_rows.items():
        second_new_verdict = _row_value(second_recommendation, "new_verdict").upper()
        if second_new_verdict == "PASS":
            residual_pass_count += 1
            continue
        if second_new_verdict != "FLAG":
            continue

        try:
            manifest = manifest_rows[target_key]
            first_result = first_result_rows[target_key]
            first_recommendation = first_recommendation_rows[target_key]
            second_result = second_result_rows[target_key]
        except KeyError as exc:
            raise ValueError(f"{target_key}: missing required adjudication input row in {exc.args[0]!r}") from exc

        japanese_text = _row_value(second_recommendation, "japanese_text")
        _validate_same_text(target_key, label="manifest", actual=_row_value(manifest, "source_text"), expected=japanese_text)
        _validate_same_text(target_key, label="first regeneration", actual=_row_value(first_result, "source_text"), expected=japanese_text)
        _validate_same_text(
            target_key,
            label="first recommendation",
            actual=_row_value(first_recommendation, "japanese_text"),
            expected=japanese_text,
        )
        _validate_same_text(
            target_key, label="second regeneration", actual=_row_value(second_result, "source_text"), expected=japanese_text
        )

        first_pass_audio_url = _row_value(first_result, "new_audio_url")
        second_pass_audio_url = _row_value(second_result, "new_audio_url")
        _validate_same_url(
            target_key,
            label="first recommendation",
            actual=_row_value(first_recommendation, "audio_url"),
            expected=first_pass_audio_url,
        )
        _validate_same_url(
            target_key,
            label="second recommendation",
            actual=_row_value(second_recommendation, "audio_url"),
            expected=second_pass_audio_url,
        )
        if _row_value(first_result, "status") != "regenerated":
            raise ValueError(f"{target_key}: first regeneration result status is not regenerated")
        if _row_value(second_result, "status") != "regenerated":
            raise ValueError(f"{target_key}: second regeneration result status is not regenerated")

        items.append(
            ResidualFlagItem(
                target_key=target_key,
                packet=_row_value(second_recommendation, "packet"),
                priority="RESIDUAL_FLAG_ADJUDICATION",
                review_signals=_extract_stt_signal(_row_value(second_recommendation, "new_notes")),
                japanese_text=japanese_text,
                korean_context=_row_value(second_recommendation, "korean_context"),
                audio_url=second_pass_audio_url,
                current_verdict="FLAG",
                current_notes=_row_value(second_recommendation, "new_notes"),
                target_id=_row_value(second_result, "target_id"),
                provider=_row_value(second_result, "provider"),
                model=_row_value(second_result, "model"),
                original_audio_url=_row_value(manifest, "current_audio_url"),
                original_stt_transcript=_row_value(manifest, "stt_transcript"),
                first_pass_audio_url=first_pass_audio_url,
                first_pass_stt_transcript=_extract_stt_transcript(_row_value(first_recommendation, "new_notes")),
                second_pass_audio_url=second_pass_audio_url,
                second_pass_stt_transcript=_extract_stt_transcript(_row_value(second_recommendation, "new_notes")),
                recommended_next_step=_recommended_next_step(target_key),
                rewrite_candidate="yes",
            )
        )

    return ResidualFlagAdjudicationReport(
        total_second_pass_rows=len(second_recommendation_rows),
        residual_flag_count=len(items),
        residual_pass_count=residual_pass_count,
        rewrite_candidate_count=sum(1 for item in items if item.rewrite_candidate == "yes"),
        items=items,
    )


def write_adjudication_csv(csv_output: Path, report: ResidualFlagAdjudicationReport) -> int:
    resolved_output = _resolve_output_path(csv_output)
    resolved_output.parent.mkdir(parents=True, exist_ok=True)
    with resolved_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=ADJUDICATION_CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for item in report.items:
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
                    "target_id": item.target_id,
                    "provider": item.provider,
                    "model": item.model,
                    "original_audio_url": item.original_audio_url,
                    "original_stt_transcript": item.original_stt_transcript,
                    "first_pass_audio_url": item.first_pass_audio_url,
                    "first_pass_stt_transcript": item.first_pass_stt_transcript,
                    "second_pass_audio_url": item.second_pass_audio_url,
                    "second_pass_stt_transcript": item.second_pass_stt_transcript,
                    "recommended_next_step": item.recommended_next_step,
                    "rewrite_candidate": item.rewrite_candidate,
                    "adjudication_decision": "",
                    "best_audio_version": "",
                    "rewrite_notes": "",
                    "new_verdict": "",
                    "new_notes": "",
                }
            )
    return len(report.items)


def _render_markdown_items(items: list[ResidualFlagItem]) -> list[str]:
    if not items:
        return ["- None"]

    lines = [
        "| Target | Source text | Original STT | First-pass STT | Second-pass STT | Next step | Current audio |",
        "|---|---|---|---|---|---|---|",
    ]
    for item in items:
        lines.append(
            "| "
            f"{_markdown_cell(item.target_key)} | "
            f"{_markdown_cell(item.japanese_text)} | "
            f"{_markdown_cell(item.original_stt_transcript)} | "
            f"{_markdown_cell(item.first_pass_stt_transcript)} | "
            f"{_markdown_cell(item.second_pass_stt_transcript)} | "
            f"{_markdown_cell(item.recommended_next_step)} | "
            f"[audio]({item.audio_url}) |"
        )
    return lines


def render_markdown(
    report: ResidualFlagAdjudicationReport,
    *,
    flag_manifest_csv: Path,
    first_regeneration_results_csv: Path,
    first_recommendations_csv: Path,
    second_regeneration_results_csv: Path,
    second_recommendations_csv: Path,
) -> str:
    lines = [
        "# N4 Residual FLAG Audio QA Adjudication",
        "",
        "> Status: REVIEW SHEET - no packet verdicts applied",
        "> Scope: second-pass regenerated N4 audio rows that still recommend `FLAG`",
        "> Boundary: adjudication aid only; not native-speaker review and not a DB mutation",
        "",
        "ASSUMPTION: Repeated STT mismatch across original, first-pass, and second-pass",
        "audio is enough to justify a focused adjudication/rewrite decision before",
        "spending another TTS regeneration cycle.",
        "",
        "## Inputs",
        "",
        f"- Original FLAG manifest: `{_display_path(_resolve_path(flag_manifest_csv))}`",
        f"- First regeneration results: `{_display_path(_resolve_path(first_regeneration_results_csv))}`",
        f"- First-pass recommendations: `{_display_path(_resolve_path(first_recommendations_csv))}`",
        f"- Second regeneration results: `{_display_path(_resolve_path(second_regeneration_results_csv))}`",
        f"- Second-pass recommendations: `{_display_path(_resolve_path(second_recommendations_csv))}`",
        "",
        "## Summary",
        "",
        "| Metric | Count |",
        "|---|---:|",
        f"| Second-pass recommendation rows | {report.total_second_pass_rows} |",
        f"| Second-pass rows cleared to PASS | {report.residual_pass_count} |",
        f"| Residual FLAG rows selected | {report.residual_flag_count} |",
        f"| Rewrite candidates | {report.rewrite_candidate_count} |",
        "",
        "## CSV Boundary",
        "",
        "The companion CSV keeps `new_verdict` and `new_notes` blank. Those columns",
        "must stay blank until an adjudication decision is made. If a row is later",
        "cleared on the current second-pass audio, the CSV can be used with",
        "`scripts/apply_n4_audio_qa_verdicts.py` because it preserves the standard",
        "`target_key`, `packet`, `audio_url`, `new_verdict`, and `new_notes` columns.",
        "",
        "## Residual FLAG Items",
        "",
    ]
    lines.extend(_render_markdown_items(report.items))
    lines.extend(
        [
            "",
            "## Decision",
            "",
            "Keep these rows as `FLAG` in packet verdicts. Do not run a third regeneration",
            "blindly; first choose whether any existing version is acceptable or whether",
            "the source sentence should be rewritten for clearer TTS/STT behavior.",
            "",
        ]
    )
    return "\n".join(lines)


def _audio_version(label: str, url: str, transcript: str) -> str:
    return "\n".join(
        [
            '<div class="audio-version">',
            f"  <h4>{_html_text(label)}</h4>",
            f'  <audio controls preload="none" src="{_html_attr(url)}"></audio>',
            f"  <p>{_html_text(transcript)}</p>",
            "</div>",
        ]
    )


def _html_item_card(item: ResidualFlagItem) -> str:
    return "\n".join(
        [
            '<article class="review-card">',
            '  <div class="review-card__meta">',
            f"    <span>{_html_text(item.target_key)}</span>",
            f"    <span>{_html_text(item.packet)}</span>",
            f"    <span>rewrite candidate: {_html_text(item.rewrite_candidate)}</span>",
            "  </div>",
            f"  <h3>{_html_text(item.japanese_text)}</h3>",
            f"  <p>{_html_text(item.korean_context)}</p>",
            '  <div class="audio-grid">',
            _audio_version("Original", item.original_audio_url, item.original_stt_transcript),
            _audio_version("First pass", item.first_pass_audio_url, item.first_pass_stt_transcript),
            _audio_version("Second pass", item.second_pass_audio_url, item.second_pass_stt_transcript),
            "  </div>",
            '  <dl class="review-card__details">',
            f"    <dt>Next step</dt><dd>{_html_text(item.recommended_next_step)}</dd>",
            f"    <dt>Current notes</dt><dd>{_html_text(item.current_notes)}</dd>",
            f"    <dt>Target ID</dt><dd>{_html_text(item.target_id)}</dd>",
            "  </dl>",
            "</article>",
        ]
    )


def render_html(report: ResidualFlagAdjudicationReport) -> str:
    review_items = (
        '<p class="empty">No residual FLAG items.</p>' if not report.items else "\n".join(_html_item_card(item) for item in report.items)
    )
    return "\n".join(
        [
            "<!doctype html>",
            '<html lang="en">',
            "<head>",
            '  <meta charset="utf-8">',
            '  <meta name="viewport" content="width=device-width, initial-scale=1">',
            "  <title>N4 Residual FLAG Audio QA Adjudication</title>",
            "  <style>",
            "    :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }",
            "    body { margin: 0; background: #f5f6f1; color: #20241f; }",
            "    main { max-width: 1120px; margin: 0 auto; padding: 40px 20px 80px; }",
            "    header { margin-bottom: 28px; }",
            "    h1 { margin: 0 0 8px; font-size: 32px; line-height: 1.2; }",
            "    h2 { margin: 34px 0 14px; font-size: 22px; }",
            "    h3 { margin: 12px 0 8px; font-size: 21px; line-height: 1.35; }",
            "    h4 { margin: 0 0 8px; font-size: 15px; }",
            "    p { color: #596054; line-height: 1.55; }",
            "    code { background: #e7eadf; border-radius: 4px; padding: 2px 4px; }",
            "    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }",
            "    .metric { background: #fff; border: 1px solid #d9dfd0; border-radius: 8px; padding: 14px; }",
            "    .metric strong { display: block; font-size: 24px; margin-top: 4px; }",
            "    .review-card { background: #fff; border: 1px solid #dfd1c5; border-radius: 8px; "
            "padding: 18px; margin: 14px 0; box-shadow: inset 4px 0 0 #b86439; }",
            "    .review-card__meta { display: flex; flex-wrap: wrap; gap: 8px; }",
            "    .review-card__meta span { background: #f2e4d9; border-radius: 999px; padding: 5px 10px; font-size: 13px; }",
            "    .audio-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 12px; margin: 14px 0; }",
            "    .audio-version { border: 1px solid #e1e4dc; border-radius: 8px; padding: 12px; background: #fbfcf8; }",
            "    audio { width: 100%; margin-bottom: 8px; }",
            "    .audio-version p { margin: 0; overflow-wrap: anywhere; }",
            "    .review-card__details { display: grid; grid-template-columns: 104px 1fr; gap: 7px 10px; margin: 0; }",
            "    dt { color: #75543d; font-weight: 700; }",
            "    dd { margin: 0; overflow-wrap: anywhere; }",
            "    .empty { background: #fff; border: 1px dashed #c9cbbf; border-radius: 8px; padding: 16px; }",
            "  </style>",
            "</head>",
            "<body>",
            "<main>",
            "  <header>",
            "    <h1>N4 Residual FLAG Audio QA Adjudication</h1>",
            "    <p>Compare original, first-pass, and second-pass audio before deciding on PASS, waiver, or source rewrite.</p>",
            "  </header>",
            '  <section class="summary" aria-label="Summary">',
            f'    <div class="metric">Second-pass rows<strong>{report.total_second_pass_rows}</strong></div>',
            f'    <div class="metric">Cleared to PASS<strong>{report.residual_pass_count}</strong></div>',
            f'    <div class="metric">Residual FLAG<strong>{report.residual_flag_count}</strong></div>',
            f'    <div class="metric">Rewrite candidates<strong>{report.rewrite_candidate_count}</strong></div>',
            "  </section>",
            "  <section>",
            "    <h2>Boundary</h2>",
            "    <p>This sheet does not mutate packet verdicts or database rows. "
            "Keep the rows as FLAG until adjudication evidence is explicit.</p>",
            "  </section>",
            "  <section>",
            "    <h2>Items</h2>",
            review_items,
            "  </section>",
            "</main>",
            "</body>",
            "</html>",
        ]
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a residual N4 FLAG audio QA adjudication sheet.")
    parser.add_argument("--flag-manifest-csv", type=Path, default=DEFAULT_FLAG_MANIFEST_CSV)
    parser.add_argument("--first-regeneration-results-csv", type=Path, default=DEFAULT_FIRST_REGENERATION_RESULTS_CSV)
    parser.add_argument("--first-recommendations-csv", type=Path, default=DEFAULT_FIRST_RECOMMENDATIONS_CSV)
    parser.add_argument("--second-regeneration-results-csv", type=Path, default=DEFAULT_SECOND_REGENERATION_RESULTS_CSV)
    parser.add_argument("--second-recommendations-csv", type=Path, default=DEFAULT_SECOND_RECOMMENDATIONS_CSV)
    parser.add_argument("--markdown-output", type=Path, default=DEFAULT_MARKDOWN_OUTPUT)
    parser.add_argument("--csv-output", type=Path, default=DEFAULT_CSV_OUTPUT)
    parser.add_argument("--html-output", type=Path, default=DEFAULT_HTML_OUTPUT)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    report = build_adjudication_report(
        flag_manifest_csv=args.flag_manifest_csv,
        first_regeneration_results_csv=args.first_regeneration_results_csv,
        first_recommendations_csv=args.first_recommendations_csv,
        second_regeneration_results_csv=args.second_regeneration_results_csv,
        second_recommendations_csv=args.second_recommendations_csv,
    )

    markdown_output = _resolve_output_path(args.markdown_output)
    markdown_output.parent.mkdir(parents=True, exist_ok=True)
    markdown_output.write_text(
        render_markdown(
            report,
            flag_manifest_csv=args.flag_manifest_csv,
            first_regeneration_results_csv=args.first_regeneration_results_csv,
            first_recommendations_csv=args.first_recommendations_csv,
            second_regeneration_results_csv=args.second_regeneration_results_csv,
            second_recommendations_csv=args.second_recommendations_csv,
        ),
        encoding="utf-8",
    )
    write_adjudication_csv(args.csv_output, report)
    html_output = _resolve_output_path(args.html_output)
    html_output.parent.mkdir(parents=True, exist_ok=True)
    html_output.write_text(render_html(report), encoding="utf-8")

    print(f"residual_flag_adjudication_markdown {_display_path(markdown_output)}")
    print(f"residual_flag_adjudication_csv {_display_path(_resolve_output_path(args.csv_output))}")
    print(f"residual_flag_adjudication_html {_display_path(html_output)}")
    print(f"second_pass_rows {report.total_second_pass_rows}")
    print(f"residual_flag {report.residual_flag_count}")
    print(f"second_pass_pass {report.residual_pass_count}")
    print(f"rewrite_candidates {report.rewrite_candidate_count}")


if __name__ == "__main__":
    main()
