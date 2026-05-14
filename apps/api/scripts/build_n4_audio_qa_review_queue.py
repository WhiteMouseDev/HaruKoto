from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

from scripts.report_n4_audio_qa_verdicts import _split_markdown_row

DEFAULT_PACKET_GLOB = "docs/operations/plans/n4-pilot-human-audio-qa-ch*-2026-05-13.md"
DEFAULT_MACHINE_REPORT_GLOB = "docs/operations/plans/n4-pilot-tts-machine-report-*.md"
REVIEW_TARGET_RE = re.compile(r"^(script|question)\s+(\d+)$")
LESSON_HEADING_RE = re.compile(r"^###\s+(HN4-\d{3})\s+-\s+(.+)$")
MACHINE_WARNING_RE = re.compile(r"^-\s+(HN4-\d{3})\s+(script|question):(\d+):\s+(.+)$")
AUDIO_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")


@dataclass(frozen=True)
class ReviewQueueItem:
    packet: str
    lesson_label: str
    lesson_title: str
    target: str
    target_key: str
    speaker: str
    japanese_text: str
    korean_context: str
    provider_model: str
    url_status: str
    audio_url: str
    verdict: str
    notes: str
    machine_signals: list[str]

    @property
    def priority(self) -> str:
        if self.verdict in {"FLAG", "FAIL"}:
            return "P0 verdict blocker"
        if self.machine_signals:
            return "P0 machine warning"
        if self.verdict == "PENDING":
            return "P1 pending"
        return "P2 resolved"


@dataclass(frozen=True)
class ReviewQueueReport:
    total_items: int
    pending_count: int
    pass_count: int
    flag_count: int
    fail_count: int
    waived_count: int
    machine_warning_count: int
    items: list[ReviewQueueItem]


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(_repo_root()))
    except ValueError:
        return str(path)


def _markdown_cell(value: str) -> str:
    return " ".join(value.split()).replace("|", "\\|")


def _audio_url(cell: str) -> str:
    match = AUDIO_LINK_RE.search(cell)
    if match:
        return match.group(1)
    return cell


def _target_key(lesson_label: str, target: str) -> str | None:
    match = REVIEW_TARGET_RE.match(target)
    if not match:
        return None
    kind, order = match.groups()
    return f"{lesson_label} {kind}:{order}"


def parse_machine_warnings(paths: list[Path]) -> dict[str, list[str]]:
    warnings: dict[str, list[str]] = {}
    for path in paths:
        for line in path.read_text(encoding="utf-8").splitlines():
            match = MACHINE_WARNING_RE.match(line.strip())
            if not match:
                continue
            lesson_label, kind, order, signal = match.groups()
            key = f"{lesson_label} {kind}:{order}"
            warnings.setdefault(key, []).append(signal)
    return warnings


def parse_packet_items(path: Path, machine_warnings: dict[str, list[str]]) -> list[ReviewQueueItem]:
    items: list[ReviewQueueItem] = []
    lesson_label = ""
    lesson_title = ""
    header: list[str] | None = None

    for line in path.read_text(encoding="utf-8").splitlines():
        heading_match = LESSON_HEADING_RE.match(line.strip())
        if heading_match:
            lesson_label, lesson_title = heading_match.groups()
            header = None
            continue

        cells = _split_markdown_row(line)
        if not cells:
            continue
        if "Reviewer verdict" in cells:
            header = cells
            continue
        if header is None or len(cells) != len(header):
            continue

        row = dict(zip(header, cells, strict=True))
        target = row.get("Target", "")
        key = _target_key(lesson_label, target)
        if key is None:
            continue
        items.append(
            ReviewQueueItem(
                packet=_display_path(path),
                lesson_label=lesson_label,
                lesson_title=lesson_title,
                target=target,
                target_key=key,
                speaker=row.get("Speaker", ""),
                japanese_text=row.get("Japanese text", ""),
                korean_context=row.get("Korean/context", ""),
                provider_model=row.get("Provider/model", ""),
                url_status=row.get("URL check", ""),
                audio_url=_audio_url(row.get("Audio", "")),
                verdict=row.get("Reviewer verdict", "").strip().strip("`").upper(),
                notes=row.get("Notes", ""),
                machine_signals=machine_warnings.get(key, []),
            )
        )
    return items


def _item_sort_key(item: ReviewQueueItem) -> tuple[int, str, int, int, str]:
    priority_order = {
        "P0 verdict blocker": 0,
        "P0 machine warning": 1,
        "P1 pending": 2,
        "P2 resolved": 3,
    }
    target_match = REVIEW_TARGET_RE.match(item.target)
    if target_match:
        kind, order = target_match.groups()
        kind_order = 0 if kind == "script" else 1
        target_order = int(order)
    else:
        kind_order = 99
        target_order = 0
    return (priority_order[item.priority], item.lesson_label, kind_order, target_order, item.target)


def build_queue(packet_paths: list[Path], machine_report_paths: list[Path]) -> ReviewQueueReport:
    machine_warnings = parse_machine_warnings(machine_report_paths)
    items: list[ReviewQueueItem] = []
    for packet_path in packet_paths:
        items.extend(parse_packet_items(packet_path, machine_warnings))

    items.sort(key=_item_sort_key)

    return ReviewQueueReport(
        total_items=len(items),
        pending_count=sum(1 for item in items if item.verdict == "PENDING"),
        pass_count=sum(1 for item in items if item.verdict == "PASS"),
        flag_count=sum(1 for item in items if item.verdict == "FLAG"),
        fail_count=sum(1 for item in items if item.verdict == "FAIL"),
        waived_count=sum(1 for item in items if item.verdict == "WAIVED"),
        machine_warning_count=sum(1 for item in items if item.machine_signals),
        items=items,
    )


def _render_items(items: list[ReviewQueueItem]) -> list[str]:
    if not items:
        return ["- None"]
    lines = [
        "| Priority | Target | Japanese text | Korean/context | Audio | Machine signals | Verdict | Packet |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for item in items:
        audio = f"[audio]({item.audio_url})" if item.audio_url else ""
        lines.append(
            "| "
            f"{_markdown_cell(item.priority)} | "
            f"{_markdown_cell(item.target_key)} | "
            f"{_markdown_cell(item.japanese_text)} | "
            f"{_markdown_cell(item.korean_context)} | "
            f"{audio} | "
            f"{_markdown_cell(', '.join(item.machine_signals) or '-')} | "
            f"{_markdown_cell(item.verdict)} | "
            f"`{_markdown_cell(item.packet)}` |"
        )
    return lines


def render_markdown(report: ReviewQueueReport, *, packet_paths: list[Path], machine_report_paths: list[Path]) -> str:
    p0_items = [item for item in report.items if item.priority.startswith("P0")]
    p1_items = [item for item in report.items if item.priority == "P1 pending"]
    p2_items = [item for item in report.items if item.priority == "P2 resolved"]

    lines = [
        "# N4 Audio QA Review Queue",
        "",
        "> Status: REVIEW QUEUE - human audio verdicts pending",
        "> Boundary: prioritization artifact only; does not approve rollout",
        "",
        "ASSUMPTION: This queue orders review work but does not replace listening,",
        "native-speaker review, or explicit `PASS` / `FLAG` / `FAIL` verdicts.",
        "",
        "## Sources",
        "",
    ]
    lines.extend(f"- Packet: `{_display_path(path)}`" for path in packet_paths)
    lines.extend(f"- Machine report: `{_display_path(path)}`" for path in machine_report_paths)
    lines.extend(
        [
            "",
            "## Summary",
            "",
            "| Metric | Count |",
            "|---|---:|",
            f"| Total review items | {report.total_items} |",
            f"| PENDING | {report.pending_count} |",
            f"| PASS | {report.pass_count} |",
            f"| FLAG | {report.flag_count} |",
            f"| FAIL | {report.fail_count} |",
            f"| WAIVED | {report.waived_count} |",
            f"| Machine-warning priority items | {report.machine_warning_count} |",
            "",
            "## P0 Review First",
            "",
        ]
    )
    lines.extend(_render_items(p0_items))
    lines.extend(["", "## P1 Remaining Pending", ""])
    lines.extend(_render_items(p1_items))
    lines.extend(["", "## P2 Resolved Or Waived", ""])
    lines.extend(_render_items(p2_items))
    lines.extend(
        [
            "",
            "## Decision",
            "",
            "Use this queue to review machine-warning items first, then complete the",
            "remaining pending packet rows. Broad/full N4 rollout remains blocked until",
            "the packet verdict tracker has no `PENDING`, `FLAG`, `FAIL`, or invalid",
            "verdict values.",
            "",
        ]
    )
    return "\n".join(lines)


def default_packet_paths() -> list[Path]:
    return sorted(_repo_root().glob(DEFAULT_PACKET_GLOB))


def default_machine_report_paths() -> list[Path]:
    return sorted(_repo_root().glob(DEFAULT_MACHINE_REPORT_GLOB))[-1:]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a prioritized N4 human audio QA review queue.")
    parser.add_argument("--packet", action="append", type=Path, default=None, help="Packet markdown path.")
    parser.add_argument("--machine-report", action="append", type=Path, default=None, help="Machine report markdown path.")
    parser.add_argument("--output", "--markdown-output", dest="output", type=Path, required=True, help="Markdown output path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    packet_paths = args.packet or default_packet_paths()
    machine_report_paths = args.machine_report or default_machine_report_paths()
    report = build_queue(packet_paths=packet_paths, machine_report_paths=machine_report_paths)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_markdown(report, packet_paths=packet_paths, machine_report_paths=machine_report_paths), encoding="utf-8")
    print(f"review_queue {_display_path(args.output)}")
    print(f"items {report.total_items}")
    print(f"pending {report.pending_count}")
    print(f"machine_warning_priority {report.machine_warning_count}")


if __name__ == "__main__":
    main()
