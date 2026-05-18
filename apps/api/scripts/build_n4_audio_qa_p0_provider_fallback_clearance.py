from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path

from scripts.apply_n4_audio_qa_verdicts import CSV_COLUMNS as APPLY_CSV_COLUMNS
from scripts.build_n4_audio_qa_review_queue import _display_path, _markdown_cell

PASS_NOTE = (
    "Delegated AI-assisted PASS: provider fallback MP3 probe passed; remaining STT mismatch "
    "is attributable to mixed Japanese/Korean/cloze prompt; not native-speaker review."
)
HOLD_NOTE = (
    "Provider fallback regenerated audio, but post-regeneration HIGH_SILENCE_RATIO remains; "
    "keep PENDING for direct-listen or another regeneration review."
)
REGENERATION_RESULT_REQUIRED_COLUMNS = {"target_key", "provider", "model"}


@dataclass(frozen=True)
class ClearanceRow:
    values: dict[str, str]
    decision: str
    basis: str


@dataclass(frozen=True)
class ClearanceReport:
    rows: list[ClearanceRow]

    @property
    def pass_count(self) -> int:
        return sum(1 for row in self.rows if row.decision == "PASS")

    @property
    def held_count(self) -> int:
        return sum(1 for row in self.rows if row.decision == "HOLD")


def _is_mixed_prompt_provider_fallback_pass(row: dict[str, str]) -> bool:
    notes = row.get("new_notes", "")
    audio_url = row.get("audio_url", "")
    return (
        row.get("current_verdict", "").strip().upper() == "PENDING"
        and "-regen-" in audio_url
        and "TRANSCRIPTION_TEXT_MISMATCH" in notes
        and "HIGH_SILENCE_RATIO" not in notes
    )


def _held_review_signals(row: dict[str, str]) -> str:
    notes = row.get("new_notes", "")
    signals = ["PROVIDER_FALLBACK_REGENERATED"]
    if "HIGH_SILENCE_RATIO" in notes:
        signals.append("POST_REGEN_HIGH_SILENCE_RATIO_REMAINS")
    if "TRANSCRIPTION_TEXT_MISMATCH" in notes:
        signals.append("POST_REGEN_TRANSCRIPTION_TEXT_MISMATCH")
    return ", ".join(signals)


def read_provider_models(csv_input: Path) -> dict[str, str]:
    provider_models: dict[str, str] = {}
    with csv_input.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        missing_columns = REGENERATION_RESULT_REQUIRED_COLUMNS - set(reader.fieldnames or [])
        if missing_columns:
            raise ValueError(f"regeneration results CSV is missing columns: {', '.join(sorted(missing_columns))}")
        for row_number, row in enumerate(reader, start=2):
            target_key = (row.get("target_key") or "").strip()
            if not target_key:
                continue
            if target_key in provider_models:
                raise ValueError(f"row {row_number}: duplicate target_key {target_key!r}")
            provider = (row.get("provider") or "").strip()
            model = (row.get("model") or "").strip()
            if provider and model:
                provider_models[target_key] = f"{provider} / {model}"
    return provider_models


def build_clearance_rows(rows: list[dict[str, str]], *, provider_models: dict[str, str] | None = None) -> ClearanceReport:
    clearance_rows: list[ClearanceRow] = []
    for row in rows:
        output = {column: row.get(column, "") for column in APPLY_CSV_COLUMNS}
        provider_model = (provider_models or {}).get(output["target_key"])
        if provider_model:
            output["provider_model"] = provider_model
        if _is_mixed_prompt_provider_fallback_pass(row):
            output["new_verdict"] = "PASS"
            output["new_notes"] = PASS_NOTE
            output["review_signals"] = "PROVIDER_FALLBACK_REGENERATED, POST_REGEN_STT_MISMATCH_ONLY"
            clearance_rows.append(
                ClearanceRow(
                    values=output,
                    decision="PASS",
                    basis="provider fallback machine pass; STT mismatch only",
                )
            )
            continue

        output["new_verdict"] = "PENDING"
        output["new_notes"] = HOLD_NOTE
        output["review_signals"] = _held_review_signals(row)
        clearance_rows.append(
            ClearanceRow(
                values=output,
                decision="HOLD",
                basis="post-regeneration warning remains",
            )
        )
    return ClearanceReport(rows=clearance_rows)


def read_recommendation_rows(csv_input: Path) -> list[dict[str, str]]:
    with csv_input.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        optional_columns = {"provider_model"}
        missing_columns = (set(APPLY_CSV_COLUMNS) - optional_columns) - set(reader.fieldnames or [])
        if missing_columns:
            raise ValueError(f"recommendation CSV is missing columns: {', '.join(sorted(missing_columns))}")
        return [dict(row) for row in reader]


def write_clearance_csv(csv_output: Path, report: ClearanceReport) -> int:
    csv_output.parent.mkdir(parents=True, exist_ok=True)
    with csv_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=APPLY_CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for row in report.rows:
            writer.writerow(row.values)
    return len(report.rows)


def render_markdown(
    report: ClearanceReport,
    *,
    recommendations_csv: Path,
    regeneration_results_csv: Path | None = None,
) -> str:
    lines = [
        "# N4 P0 Provider Fallback Clearance",
        "",
        "> Status: APPLY CSV GENERATED",
        "> Boundary: delegated AI-assisted verdicts only; not native-speaker approval",
        "",
        "ASSUMPTION: After provider fallback regeneration, a P0 mixed Japanese/Korean",
        "cloze prompt can be cleared when the MP3 probe has no blocker or silence",
        "warning and the only remaining signal is STT mismatch. STT remains weak",
        "evidence for these mixed prompt rows.",
        "",
        "## Inputs",
        "",
        f"- Post-regeneration recommendation CSV: `{_display_path(recommendations_csv)}`",
    ]
    if regeneration_results_csv is not None:
        lines.append(f"- Regeneration results CSV: `{_display_path(regeneration_results_csv)}`")
    lines.extend(
        [
            "",
            "## Summary",
            "",
            "| Metric | Count |",
            "|---|---:|",
            f"| Total rows | {len(report.rows)} |",
            f"| PASS rows | {report.pass_count} |",
            f"| Held rows | {report.held_count} |",
            "",
            "## Decisions",
            "",
            "| Target | Decision | Basis | Provider/model | Audio |",
            "|---|---|---|---|---|",
        ]
    )
    for row in report.rows:
        audio_url = row.values.get("audio_url", "")
        audio = f"[audio]({audio_url})" if audio_url else ""
        lines.append(
            "| "
            f"{_markdown_cell(row.values.get('target_key', ''))} | "
            f"{_markdown_cell(row.decision)} | "
            f"{_markdown_cell(row.basis)} | "
            f"{_markdown_cell(row.values.get('provider_model', ''))} | "
            f"{audio} |"
        )
    lines.extend(
        [
            "",
            "## Decision",
            "",
            "Apply the companion CSV to update regenerated audio URLs, clear rows that",
            "only have mixed-prompt STT mismatch remaining, and keep any row with",
            "post-regeneration silence warning pending.",
            "",
        ]
    )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build apply-ready clearance for N4 P0 provider fallback rows.")
    parser.add_argument("--recommendations-csv", type=Path, required=True, help="Post-regeneration recommendation CSV input.")
    parser.add_argument(
        "--regeneration-results-csv",
        type=Path,
        default=None,
        help="Optional regeneration results CSV for provider/model updates.",
    )
    parser.add_argument("--csv-output", type=Path, required=True, help="Apply-ready clearance CSV output.")
    parser.add_argument("--markdown-output", type=Path, required=True, help="Markdown clearance report output.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    provider_models = read_provider_models(args.regeneration_results_csv) if args.regeneration_results_csv is not None else None
    report = build_clearance_rows(read_recommendation_rows(args.recommendations_csv), provider_models=provider_models)
    write_clearance_csv(args.csv_output, report)
    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.write_text(
        render_markdown(
            report,
            recommendations_csv=args.recommendations_csv,
            regeneration_results_csv=args.regeneration_results_csv,
        ),
        encoding="utf-8",
    )

    print(f"p0_provider_fallback_clearance_csv {_display_path(args.csv_output)}")
    print(f"p0_provider_fallback_clearance_report {_display_path(args.markdown_output)}")
    print(f"rows {len(report.rows)}")
    print(f"pass {report.pass_count}")
    print(f"held {report.held_count}")


if __name__ == "__main__":
    main()
