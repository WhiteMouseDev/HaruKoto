from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path

from scripts.build_n4_audio_qa_review_queue import build_queue, default_machine_report_paths, default_packet_paths
from scripts.report_n4_audio_qa_verdicts import KNOWN_VERDICTS, _is_separator_row, _repo_root, _split_markdown_row

CSV_COLUMNS = [
    "target_key",
    "packet",
    "priority",
    "review_signals",
    "japanese_text",
    "korean_context",
    "audio_url",
    "current_verdict",
    "current_notes",
    "new_verdict",
    "new_notes",
]
LESSON_HEADING_RE = re.compile(r"^###\s+(HN4-\d{3})\s+-\s+(.+)$")
REVIEW_TARGET_RE = re.compile(r"^(script|question)\s+(\d+)$")


@dataclass(frozen=True)
class VerdictUpdate:
    target_key: str
    packet_path: Path
    new_verdict: str | None
    new_notes: str | None
    audio_url: str | None = None


@dataclass(frozen=True)
class ApplyResult:
    matched: int
    changed: int
    skipped: int
    packets_changed: list[Path]


def _display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(_repo_root()))
    except ValueError:
        return str(path)


def _resolve_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return _repo_root() / path


def _target_key(lesson_label: str, target: str) -> str | None:
    match = REVIEW_TARGET_RE.match(target)
    if not match:
        return None
    kind, order = match.groups()
    return f"{lesson_label} {kind}:{order}"


def _markdown_cell(value: str) -> str:
    return " ".join(value.split()).replace("|", "\\|")


def _markdown_row(cells: list[str]) -> str:
    return "| " + " | ".join(_markdown_cell(cell) for cell in cells) + " |"


def write_template(csv_output: Path, *, packet_paths: list[Path], machine_report_paths: list[Path]) -> int:
    report = build_queue(packet_paths=packet_paths, machine_report_paths=machine_report_paths)
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
                    "review_signals": ", ".join(item.review_signals),
                    "japanese_text": item.japanese_text,
                    "korean_context": item.korean_context,
                    "audio_url": item.audio_url,
                    "current_verdict": item.verdict,
                    "current_notes": item.notes,
                    "new_verdict": "",
                    "new_notes": "",
                }
            )
    return report.total_items


def read_updates(csv_input: Path) -> list[VerdictUpdate]:
    updates: list[VerdictUpdate] = []
    with csv_input.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        missing_columns = {"target_key", "packet", "new_verdict", "new_notes"} - set(reader.fieldnames or [])
        if missing_columns:
            missing = ", ".join(sorted(missing_columns))
            raise ValueError(f"CSV is missing required columns: {missing}")

        for row_number, row in enumerate(reader, start=2):
            new_verdict = (row.get("new_verdict") or "").strip().strip("`").upper()
            new_notes = (row.get("new_notes") or "").strip()
            if not new_verdict and not new_notes:
                continue
            if new_verdict and new_verdict not in KNOWN_VERDICTS:
                raise ValueError(f"row {row_number}: unsupported verdict {new_verdict!r}")

            target_key = (row.get("target_key") or "").strip()
            packet = (row.get("packet") or "").strip()
            if not target_key or not packet:
                raise ValueError(f"row {row_number}: target_key and packet are required for updates")

            updates.append(
                VerdictUpdate(
                    target_key=target_key,
                    packet_path=_resolve_path(packet),
                    new_verdict=new_verdict or None,
                    new_notes=new_notes or None,
                    audio_url=(row.get("audio_url") or "").strip() or None,
                )
            )
    return updates


def _apply_updates_to_packet(path: Path, updates: dict[str, VerdictUpdate]) -> tuple[str, set[str], int]:
    lines = path.read_text(encoding="utf-8").splitlines()
    output: list[str] = []
    matched: set[str] = set()
    changed = 0
    lesson_label = ""
    header: list[str] | None = None
    verdict_index: int | None = None
    notes_index: int | None = None
    audio_index: int | None = None

    for line in lines:
        heading_match = LESSON_HEADING_RE.match(line.strip())
        if heading_match:
            lesson_label = heading_match.group(1)
            header = None
            verdict_index = None
            notes_index = None
            output.append(line)
            continue

        cells = _split_markdown_row(line)
        if not cells:
            output.append(line)
            continue
        if "Reviewer verdict" in cells and "Notes" in cells:
            header = cells
            verdict_index = cells.index("Reviewer verdict")
            notes_index = cells.index("Notes")
            audio_index = cells.index("Audio") if "Audio" in cells else None
            output.append(line)
            continue
        if header is None or verdict_index is None or notes_index is None or _is_separator_row(cells):
            output.append(line)
            continue
        if len(cells) != len(header):
            output.append(line)
            continue

        key = _target_key(lesson_label, cells[0])
        if key is None or key not in updates:
            output.append(line)
            continue

        update = updates[key]
        matched.add(key)
        original = cells[:]
        if update.new_verdict:
            cells[verdict_index] = update.new_verdict
        if update.new_notes:
            cells[notes_index] = update.new_notes
        if update.audio_url and audio_index is not None:
            cells[audio_index] = f"[audio]({update.audio_url})"
        if cells != original:
            changed += 1
            output.append(_markdown_row(cells))
        else:
            output.append(line)

    return "\n".join(output) + "\n", matched, changed


def apply_updates(updates: list[VerdictUpdate], *, write: bool) -> ApplyResult:
    by_packet: dict[Path, dict[str, VerdictUpdate]] = {}
    for update in updates:
        by_packet.setdefault(update.packet_path, {})[update.target_key] = update

    matched_total = 0
    changed_total = 0
    modified_files: dict[Path, str] = {}
    unmatched: list[str] = []

    for packet_path, packet_updates in by_packet.items():
        if not packet_path.exists():
            raise FileNotFoundError(f"packet not found: {packet_path}")
        new_content, matched, changed = _apply_updates_to_packet(packet_path, packet_updates)
        matched_total += len(matched)
        changed_total += changed
        unmatched.extend(sorted(set(packet_updates) - matched))
        if changed:
            modified_files[packet_path] = new_content

    if unmatched:
        missing = ", ".join(unmatched)
        raise ValueError(f"CSV update targets were not found in packet markdown: {missing}")

    if write:
        for packet_path, content in modified_files.items():
            packet_path.write_text(content, encoding="utf-8")

    return ApplyResult(
        matched=matched_total,
        changed=changed_total,
        skipped=len(updates) - matched_total,
        packets_changed=sorted(modified_files),
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create or apply N4 human audio QA verdict CSV updates.")
    parser.add_argument("--packet", action="append", type=Path, default=None, help="Packet markdown path for template generation.")
    parser.add_argument(
        "--machine-report",
        "--signal-report",
        action="append",
        dest="machine_report",
        type=Path,
        default=None,
        help="Quality signal report markdown path for template generation.",
    )
    parser.add_argument("--csv-output", type=Path, default=None, help="Write a review verdict CSV template.")
    parser.add_argument("--csv-input", type=Path, default=None, help="Read reviewer verdict updates from CSV.")
    parser.add_argument("--write", action="store_true", help="Apply CSV updates to packet Markdown files.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if bool(args.csv_output) == bool(args.csv_input):
        raise SystemExit("Provide exactly one of --csv-output or --csv-input")

    if args.csv_output:
        packet_paths = args.packet or default_packet_paths()
        machine_report_paths = args.machine_report or default_machine_report_paths()
        count = write_template(args.csv_output, packet_paths=packet_paths, machine_report_paths=machine_report_paths)
        print(f"verdict_template {_display_path(args.csv_output)}")
        print(f"items {count}")
        return

    updates = read_updates(args.csv_input)
    result = apply_updates(updates, write=args.write)
    print("mode write" if args.write else "mode dry-run")
    print(f"updates {len(updates)}")
    print(f"matched {result.matched}")
    print(f"changed {result.changed}")
    print(f"skipped {result.skipped}")
    print("packets_changed")
    for packet in result.packets_changed:
        print(f"- {_display_path(packet)}")


if __name__ == "__main__":
    main()
