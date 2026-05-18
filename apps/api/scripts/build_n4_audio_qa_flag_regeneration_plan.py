from __future__ import annotations

import argparse
import csv
import re
from collections import Counter
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

AUDIO_LESSON_RE = re.compile(r"/tts/lesson/([^/]+)/")
REVIEW_TARGET_RE = re.compile(r"^(script|question)\s+(\d+)$")
STT_SIGNAL_PREFIX = "TRANSCRIPTION_TEXT_MISMATCH:"

CSV_COLUMNS = [
    "target_key",
    "packet",
    "lesson_label",
    "lesson_title",
    "target_kind",
    "target_order",
    "lesson_id",
    "target_type",
    "field",
    "target_id",
    "provider_model",
    "source_text",
    "korean_context",
    "stt_transcript",
    "review_signals",
    "current_audio_url",
    "current_verdict",
    "current_notes",
    "recommended_action",
    "regeneration_status",
    "new_audio_url",
    "post_regen_verdict",
    "post_regen_notes",
]


@dataclass(frozen=True)
class FlagRegenerationItem:
    target_key: str
    packet: str
    lesson_label: str
    lesson_title: str
    target_kind: str
    target_order: int
    lesson_id: str
    target_type: str
    field: str
    target_id: str
    provider_model: str
    source_text: str
    korean_context: str
    stt_transcript: str
    review_signals: list[str]
    current_audio_url: str
    current_verdict: str
    current_notes: str
    recommended_action: str


@dataclass(frozen=True)
class FlagRegenerationPlan:
    total_review_items: int
    pass_count: int
    pending_count: int
    flag_count: int
    fail_count: int
    source_verdicts: set[str]
    items: list[FlagRegenerationItem]

    @property
    def script_count(self) -> int:
        return sum(1 for item in self.items if item.target_kind == "script")

    @property
    def question_count(self) -> int:
        return sum(1 for item in self.items if item.target_kind == "question")


def _lesson_id_from_audio_url(audio_url: str) -> str:
    match = AUDIO_LESSON_RE.search(audio_url)
    if not match:
        return ""
    return match.group(1)


def _stt_transcript(item: ReviewQueueItem) -> str:
    for signal in item.review_signals:
        if signal.startswith(STT_SIGNAL_PREFIX):
            return signal.removeprefix(STT_SIGNAL_PREFIX).strip()
    return ""


def _target_metadata(item: ReviewQueueItem, lesson_id: str) -> tuple[str, int, str, str, str]:
    match = REVIEW_TARGET_RE.match(item.target)
    if not match:
        return "", -1, "", "", ""

    target_kind, raw_order = match.groups()
    target_order = int(raw_order)
    if target_kind == "script":
        target_type = "lesson_script_line"
        field = "script_line"
    else:
        target_type = "lesson_question_prompt"
        field = "question_prompt"

    target_id = f"{lesson_id}:{target_kind}:{target_order}" if lesson_id else ""
    return target_kind, target_order, target_type, field, target_id


def _recommended_action(item: ReviewQueueItem) -> str:
    if item.verdict == "PENDING":
        return "regenerate audio, then STT audit before setting PASS or FLAG"
    if "wrong-word audio" in item.notes or "lexical divergence" in item.notes:
        return "regenerate audio, then listen before clearing FLAG"
    return "direct-listen waiver or regenerate audio before broad rollout"


def _to_regeneration_item(item: ReviewQueueItem) -> FlagRegenerationItem:
    lesson_id = _lesson_id_from_audio_url(item.audio_url)
    target_kind, target_order, target_type, field, target_id = _target_metadata(item, lesson_id)
    return FlagRegenerationItem(
        target_key=item.target_key,
        packet=item.packet,
        lesson_label=item.lesson_label,
        lesson_title=item.lesson_title,
        target_kind=target_kind,
        target_order=target_order,
        lesson_id=lesson_id,
        target_type=target_type,
        field=field,
        target_id=target_id,
        provider_model=item.provider_model,
        source_text=item.japanese_text,
        korean_context=item.korean_context,
        stt_transcript=_stt_transcript(item),
        review_signals=item.review_signals,
        current_audio_url=item.audio_url,
        current_verdict=item.verdict,
        current_notes=item.notes,
        recommended_action=_recommended_action(item),
    )


def build_regeneration_plan(
    *,
    packet_paths: list[Path],
    machine_report_paths: list[Path],
    source_verdicts: set[str] | None = None,
) -> FlagRegenerationPlan:
    queue = build_queue(packet_paths=packet_paths, machine_report_paths=machine_report_paths)
    allowed_verdicts = source_verdicts or {"FLAG"}
    items = [_to_regeneration_item(item) for item in queue.items if item.verdict in allowed_verdicts]

    return FlagRegenerationPlan(
        total_review_items=queue.total_items,
        pass_count=queue.pass_count,
        pending_count=queue.pending_count,
        flag_count=queue.flag_count,
        fail_count=queue.fail_count,
        source_verdicts=allowed_verdicts,
        items=items,
    )


def _render_packet_counts(items: list[FlagRegenerationItem]) -> list[str]:
    if not items:
        return ["- None"]

    counts = Counter(item.packet for item in items)
    lines = ["| Packet | Selected targets |", "|---|---:|"]
    for packet, count in sorted(counts.items()):
        lines.append(f"| `{_markdown_cell(packet)}` | {count} |")
    return lines


def _render_items(items: list[FlagRegenerationItem]) -> list[str]:
    if not items:
        return ["- None"]

    lines = [
        "| Target | Source text | STT transcript | Lesson target | Current audio | Action | Packet |",
        "|---|---|---|---|---|---|---|",
    ]
    for item in items:
        lesson_target = f"{item.lesson_id} {item.target_kind}:{item.target_order}" if item.lesson_id else ""
        audio = f"[audio]({item.current_audio_url})" if item.current_audio_url else ""
        lines.append(
            "| "
            f"{_markdown_cell(item.target_key)} | "
            f"{_markdown_cell(item.source_text)} | "
            f"{_markdown_cell(item.stt_transcript)} | "
            f"{_markdown_cell(lesson_target)} | "
            f"{audio} | "
            f"{_markdown_cell(item.recommended_action)} | "
            f"`{_markdown_cell(item.packet)}` |"
        )
    return lines


def render_markdown(
    plan: FlagRegenerationPlan,
    *,
    packet_paths: list[Path],
    machine_report_paths: list[Path],
) -> str:
    lines = [
        "# N4 Audio QA Verdict Regeneration Plan",
        "",
        "> Status: REGENERATION HANDOFF - no audio generated",
        "> Boundary: planning artifact only; no TTS provider call, storage write,",
        "> packet verdict update, or native-speaker review is performed here",
        "",
        "ASSUMPTION: Existing blocker verdict rows should stay blocking until",
        "they are regenerated and re-reviewed, or explicitly waived after direct",
        "listening. This plan only extracts the exact targets that need that next",
        "step.",
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
            f"| Total review targets | {plan.total_review_items} |",
            f"| Current PASS verdicts | {plan.pass_count} |",
            f"| Current PENDING verdicts | {plan.pending_count} |",
            f"| Current FLAG verdicts | {plan.flag_count} |",
            f"| Current FAIL verdicts | {plan.fail_count} |",
            f"| Source verdict filter | {', '.join(sorted(plan.source_verdicts))} |",
            f"| Regeneration manifest rows | {len(plan.items)} |",
            f"| Script-line rows | {plan.script_count} |",
            f"| Question-prompt rows | {plan.question_count} |",
            "",
            "## Packet Distribution",
            "",
        ]
    )
    lines.extend(_render_packet_counts(plan.items))
    lines.extend(
        [
            "",
            "## Execution Boundary",
            "",
            "`scripts/generate_n4_pilot_tts_batch.py` currently generates missing TTS",
            "coverage only. Do not expect it to replace selected rows because",
            "their current audio records already exist. A targeted replacement path",
            "must create a new audio object and update the matching `tts_audio`",
            "record, or record an explicit direct-listening waiver.",
            "",
            "`scripts/regenerate_n4_audio_qa_flagged_tts.py` is the targeted replacement",
            "harness for this manifest. It is dry-run by default; `--execute` is",
            "required before any TTS provider call, storage write, or DB update.",
            "",
            "## Manifest",
            "",
        ]
    )
    lines.extend(_render_items(plan.items))
    lines.extend(
        [
            "",
            "## CSV Review Columns",
            "",
            "The companion CSV leaves `regeneration_status`, `new_audio_url`,",
            "`post_regen_verdict`, and `post_regen_notes` blank. Fill these only",
            "after actual regeneration or an approved waiver step.",
            "",
            "## Decision",
            "",
            "Broad/full N4 rollout remains on hold while any `FLAG`, `PENDING`,",
            "`FAIL`, or invalid verdict remains. This handoff reduces ambiguity for",
            "the next execution slice but does not clear the gate by itself.",
            "",
        ]
    )
    return "\n".join(lines)


def write_csv(csv_output: Path, plan: FlagRegenerationPlan) -> int:
    csv_output.parent.mkdir(parents=True, exist_ok=True)
    with csv_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for item in plan.items:
            writer.writerow(
                {
                    "target_key": item.target_key,
                    "packet": item.packet,
                    "lesson_label": item.lesson_label,
                    "lesson_title": item.lesson_title,
                    "target_kind": item.target_kind,
                    "target_order": item.target_order,
                    "lesson_id": item.lesson_id,
                    "target_type": item.target_type,
                    "field": item.field,
                    "target_id": item.target_id,
                    "provider_model": item.provider_model,
                    "source_text": item.source_text,
                    "korean_context": item.korean_context,
                    "stt_transcript": item.stt_transcript,
                    "review_signals": ", ".join(item.review_signals),
                    "current_audio_url": item.current_audio_url,
                    "current_verdict": item.current_verdict,
                    "current_notes": item.current_notes,
                    "recommended_action": item.recommended_action,
                    "regeneration_status": "",
                    "new_audio_url": "",
                    "post_regen_verdict": "",
                    "post_regen_notes": "",
                }
            )
    return len(plan.items)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a regeneration handoff for N4 audio QA FLAG rows.")
    parser.add_argument("--packet", action="append", type=Path, default=None, help="Packet markdown path.")
    parser.add_argument(
        "--machine-report",
        "--signal-report",
        action="append",
        type=Path,
        default=None,
        help="Quality signal report markdown path. Defaults to latest machine and STT assist reports.",
    )
    parser.add_argument(
        "--source-verdict",
        action="append",
        default=None,
        help="Include rows with this current verdict. Defaults to FLAG. Repeatable, for example --source-verdict PENDING.",
    )
    parser.add_argument("--markdown-output", required=True, type=Path, help="Markdown regeneration plan output path.")
    parser.add_argument("--csv-output", type=Path, default=None, help="Optional regeneration manifest CSV output path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    packet_paths = args.packet or default_packet_paths()
    machine_report_paths = args.machine_report or default_machine_report_paths()
    source_verdicts = {verdict.upper() for verdict in args.source_verdict} if args.source_verdict else None
    plan = build_regeneration_plan(
        packet_paths=packet_paths,
        machine_report_paths=machine_report_paths,
        source_verdicts=source_verdicts,
    )

    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.write_text(
        render_markdown(plan, packet_paths=packet_paths, machine_report_paths=machine_report_paths),
        encoding="utf-8",
    )
    print(f"flag_regeneration_plan {args.markdown_output}")
    if args.csv_output:
        write_csv(args.csv_output, plan)
        print(f"flag_regeneration_csv {args.csv_output}")
    print(f"regeneration_rows {len(plan.items)}")


if __name__ == "__main__":
    main()
