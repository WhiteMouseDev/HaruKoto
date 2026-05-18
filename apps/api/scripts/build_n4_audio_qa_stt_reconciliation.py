from __future__ import annotations

import argparse
import csv
import difflib
import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from scripts.build_n4_audio_qa_review_queue import (
    ReviewQueueItem,
    _display_path,
    _markdown_cell,
    build_queue,
    default_machine_report_paths,
    default_packet_paths,
)

STT_SIGNAL_PREFIX = "TRANSCRIPTION_TEXT_MISMATCH:"
HANGUL_RE = re.compile(r"[가-힣]")
PUNCTUATION_RE = re.compile(r"[\s。、！？!?.,，・「」『』（）()\[\]【】…:：;；'\"`~〜\-_/]+")

Bucket = Literal[
    "P0_MACHINE_WARNING",
    "CANONICAL_MATCH",
    "NEAR_JAPANESE_MATCH",
    "MIXED_PROMPT_STT_UNRELIABLE",
    "LEXICAL_RISK",
    "NO_STT_TRANSCRIPT",
]


@dataclass(frozen=True)
class SttReconciliationItem:
    target_key: str
    packet: str
    priority: str
    bucket: Bucket
    source_text: str
    korean_context: str
    transcript: str
    audio_url: str
    review_signals: list[str]
    similarity: float
    rationale: str
    recommended_action: str


@dataclass(frozen=True)
class SttReconciliationReport:
    total_review_items: int
    pending_review_signal_items: int
    p0_machine_warning_count: int
    p1_stt_only_count: int
    canonical_match_count: int
    near_japanese_match_count: int
    mixed_prompt_count: int
    lexical_risk_count: int
    no_stt_transcript_count: int
    items: list[SttReconciliationItem]


def _stt_transcript(item: ReviewQueueItem) -> str:
    for signal in item.review_signals:
        if signal.startswith(STT_SIGNAL_PREFIX):
            return signal.removeprefix(STT_SIGNAL_PREFIX).strip()
    return ""


def _katakana_to_hiragana(text: str) -> str:
    converted: list[str] = []
    for char in text:
        codepoint = ord(char)
        if 0x30A1 <= codepoint <= 0x30F6:
            converted.append(chr(codepoint - 0x60))
        else:
            converted.append(char)
    return "".join(converted)


def _canonical_text(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text)
    normalized = normalized.replace("方が", "ほうが")
    normalized = normalized.replace("時に", "ときに")
    normalized = normalized.replace("時", "とき")
    normalized = _katakana_to_hiragana(normalized)
    return PUNCTUATION_RE.sub("", normalized)


def _similarity(source_text: str, transcript: str) -> float:
    source = _canonical_text(source_text)
    observed = _canonical_text(transcript)
    if not source and not observed:
        return 1.0
    return difflib.SequenceMatcher(a=source, b=observed).ratio()


def _is_mixed_prompt(item: ReviewQueueItem) -> bool:
    return item.target.startswith("question") or bool(HANGUL_RE.search(item.japanese_text))


def _classify_item(item: ReviewQueueItem) -> tuple[Bucket, float, str, str]:
    transcript = _stt_transcript(item)
    similarity = _similarity(item.japanese_text, transcript) if transcript else 0.0

    if item.has_machine_signal:
        return (
            "P0_MACHINE_WARNING",
            similarity,
            "Machine warning is present, so this remains first-listen priority even when the STT transcript looks plausible.",
            "listen first; check silence/spacing, intelligibility, and text completeness before setting PASS/FLAG/FAIL",
        )
    if not transcript:
        return (
            "NO_STT_TRANSCRIPT",
            similarity,
            "No parsed STT transcript was available for this pending review item.",
            "rerun STT assist or listen manually before setting a verdict",
        )
    if _is_mixed_prompt(item):
        return (
            "MIXED_PROMPT_STT_UNRELIABLE",
            similarity,
            "Question prompts mix Japanese with Korean, cloze blanks, or Korean instructions, "
            "so single-language STT mismatch is weak evidence.",
            "listen for learner-facing completeness; do not treat STT mismatch alone as a fail",
        )
    if _canonical_text(item.japanese_text) == _canonical_text(transcript):
        return (
            "CANONICAL_MATCH",
            similarity,
            "Source and STT transcript match after punctuation, kana, and common kanji/kana notation normalization.",
            "candidate for delegated PASS after optional spot listen; keep native-speaker boundary in notes",
        )
    if similarity >= 0.82:
        return (
            "NEAR_JAPANESE_MATCH",
            similarity,
            "Transcript is close to the Japanese source but differs in ending, polarity, inflection, or a short token.",
            "listen once before PASS; set FLAG if the spoken sentence follows the transcript rather than the source",
        )
    return (
        "LEXICAL_RISK",
        similarity,
        "Transcript diverges enough from the Japanese source that a pronunciation or generated-text issue is plausible.",
        "listen carefully before PASS; prefer FLAG when the source text is not clearly spoken",
    )


def _item_sort_key(item: SttReconciliationItem) -> tuple[int, str]:
    bucket_order = {
        "P0_MACHINE_WARNING": 0,
        "LEXICAL_RISK": 1,
        "NEAR_JAPANESE_MATCH": 2,
        "CANONICAL_MATCH": 3,
        "MIXED_PROMPT_STT_UNRELIABLE": 4,
        "NO_STT_TRANSCRIPT": 5,
    }
    return (bucket_order[item.bucket], item.target_key)


def build_reconciliation_report(packet_paths: list[Path], machine_report_paths: list[Path]) -> SttReconciliationReport:
    queue = build_queue(packet_paths=packet_paths, machine_report_paths=machine_report_paths)
    items: list[SttReconciliationItem] = []
    for item in queue.items:
        if item.verdict != "PENDING" or not item.review_signals:
            continue
        bucket, similarity, rationale, recommended_action = _classify_item(item)
        items.append(
            SttReconciliationItem(
                target_key=item.target_key,
                packet=item.packet,
                priority=item.priority,
                bucket=bucket,
                source_text=item.japanese_text,
                korean_context=item.korean_context,
                transcript=_stt_transcript(item),
                audio_url=item.audio_url,
                review_signals=item.review_signals,
                similarity=similarity,
                rationale=rationale,
                recommended_action=recommended_action,
            )
        )

    items.sort(key=_item_sort_key)

    return SttReconciliationReport(
        total_review_items=queue.total_items,
        pending_review_signal_items=len(items),
        p0_machine_warning_count=sum(1 for item in items if item.bucket == "P0_MACHINE_WARNING"),
        p1_stt_only_count=sum(1 for item in items if item.priority == "P1 STT mismatch"),
        canonical_match_count=sum(1 for item in items if item.bucket == "CANONICAL_MATCH"),
        near_japanese_match_count=sum(1 for item in items if item.bucket == "NEAR_JAPANESE_MATCH"),
        mixed_prompt_count=sum(1 for item in items if item.bucket == "MIXED_PROMPT_STT_UNRELIABLE"),
        lexical_risk_count=sum(1 for item in items if item.bucket == "LEXICAL_RISK"),
        no_stt_transcript_count=sum(1 for item in items if item.bucket == "NO_STT_TRANSCRIPT"),
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


def render_markdown(report: SttReconciliationReport, *, packet_paths: list[Path], machine_report_paths: list[Path]) -> str:
    lines = [
        "# N4 Audio QA STT Reconciliation",
        "",
        "> Status: TRIAGE ONLY - no verdicts applied",
        "> Boundary: STT mismatch reconciliation only; does not replace listening or native-speaker review",
        "",
        "ASSUMPTION: This report helps reduce review ambiguity while preserving",
        "the current verdict gate. It does not set `PASS`, `FLAG`, `FAIL`, or",
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
            f"| P0 machine-warning retained first | {report.p0_machine_warning_count} |",
            f"| P1 STT-only items | {report.p1_stt_only_count} |",
            f"| Canonical text matches | {report.canonical_match_count} |",
            f"| Near Japanese matches | {report.near_japanese_match_count} |",
            f"| Mixed/Korean prompt STT-unreliable | {report.mixed_prompt_count} |",
            f"| Lexical-risk Japanese mismatches | {report.lexical_risk_count} |",
            f"| Missing STT transcript | {report.no_stt_transcript_count} |",
            "",
            "## Review Order",
            "",
            "1. Listen to `P0_MACHINE_WARNING` rows first because high silence ratio",
            "   can hide pacing or truncation problems even when the audio file exists.",
            "2. Review `LEXICAL_RISK` rows next because the transcript diverges from",
            "   the source enough to suggest possible wrong-word audio.",
            "3. Use `NEAR_JAPANESE_MATCH` and `CANONICAL_MATCH` rows as lower-risk",
            "   candidates for delegated PASS after a spot listen.",
            "4. Treat `MIXED_PROMPT_STT_UNRELIABLE` as a prompt-design/STT limitation;",
            "   decide by direct playback rather than transcript mismatch alone.",
            "",
            "## CSV Apply Boundary",
            "",
            "The companion CSV leaves `new_verdict` and `new_notes` blank. Fill those",
            "columns only after direct listening or an explicitly delegated review step.",
            "",
        ]
    )

    for bucket in (
        "P0_MACHINE_WARNING",
        "LEXICAL_RISK",
        "NEAR_JAPANESE_MATCH",
        "CANONICAL_MATCH",
        "MIXED_PROMPT_STT_UNRELIABLE",
        "NO_STT_TRANSCRIPT",
    ):
        bucket_items = [item for item in report.items if item.bucket == bucket]
        lines.extend(["", f"## {bucket}", ""])
        lines.extend(_render_items(bucket_items))

    lines.extend(
        [
            "",
            "## Decision",
            "",
            "Broad/full N4 rollout remains blocked. This triage only narrows the",
            f"remaining {report.pending_review_signal_items} pending review-signal audio QA rows",
            "into review lanes and does not lower the verdict gate by itself.",
            "",
        ]
    )
    return "\n".join(lines)


def write_reconciliation_csv(csv_output: Path, report: SttReconciliationReport) -> int:
    csv_output.parent.mkdir(parents=True, exist_ok=True)
    with csv_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
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
            ],
            lineterminator="\n",
        )
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
    return len(report.items)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build N4 audio QA STT mismatch reconciliation artifacts.")
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
    parser.add_argument("--markdown-output", type=Path, required=True, help="Markdown reconciliation report output path.")
    parser.add_argument("--csv-output", type=Path, default=None, help="Optional CSV reconciliation output path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    packet_paths = args.packet or default_packet_paths()
    machine_report_paths = args.machine_report or default_machine_report_paths()
    report = build_reconciliation_report(packet_paths=packet_paths, machine_report_paths=machine_report_paths)

    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.write_text(
        render_markdown(report, packet_paths=packet_paths, machine_report_paths=machine_report_paths),
        encoding="utf-8",
    )
    print(f"stt_reconciliation_report {_display_path(args.markdown_output)}")
    if args.csv_output:
        write_reconciliation_csv(args.csv_output, report)
        print(f"stt_reconciliation_csv {_display_path(args.csv_output)}")
    print(f"items {report.pending_review_signal_items}")
    print(f"p0_machine_warning {report.p0_machine_warning_count}")
    print(f"p1_stt_only {report.p1_stt_only_count}")
    print(f"canonical_matches {report.canonical_match_count}")
    print(f"near_japanese_matches {report.near_japanese_match_count}")
    print(f"mixed_prompt_stt_unreliable {report.mixed_prompt_count}")
    print(f"lexical_risk {report.lexical_risk_count}")


if __name__ == "__main__":
    main()
