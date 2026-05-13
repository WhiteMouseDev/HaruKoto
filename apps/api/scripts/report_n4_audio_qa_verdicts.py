from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path

DEFAULT_PACKET_GLOB = "docs/operations/plans/n4-pilot-human-audio-qa-ch*-2026-05-13.md"
REVIEW_TARGET_KINDS = ("script ", "question ")
KNOWN_VERDICTS = {"PASS", "FLAG", "FAIL", "PENDING", "WAIVED"}
BLOCKING_VERDICTS = {"FLAG", "FAIL", "PENDING"}


@dataclass(frozen=True)
class InvalidVerdict:
    target: str
    verdict: str


@dataclass(frozen=True)
class PacketVerdictSummary:
    packet: str
    total_targets: int
    pass_count: int
    pending_count: int
    flag_count: int
    fail_count: int
    waived_count: int
    invalid_verdicts: list[InvalidVerdict]

    @property
    def blocker_count(self) -> int:
        return self.pending_count + self.flag_count + self.fail_count + len(self.invalid_verdicts)


@dataclass(frozen=True)
class VerdictReport:
    packets: list[PacketVerdictSummary]
    total_targets: int
    pass_count: int
    pending_count: int
    flag_count: int
    fail_count: int
    waived_count: int
    invalid_count: int
    blockers: list[str]


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(_repo_root()))
    except ValueError:
        return str(path)


def _split_markdown_row(line: str) -> list[str]:
    content = line.strip()
    if not content.startswith("|") or not content.endswith("|"):
        return []
    content = content[1:-1]

    cells: list[str] = []
    current: list[str] = []
    escaped = False
    for char in content:
        if escaped:
            current.append(char)
            escaped = False
            continue
        if char == "\\":
            escaped = True
            continue
        if char == "|":
            cells.append("".join(current).strip())
            current = []
            continue
        current.append(char)
    cells.append("".join(current).strip())
    return cells


def _is_separator_row(cells: list[str]) -> bool:
    if not cells:
        return False
    return all(cell.replace(":", "").replace("-", "").strip() == "" for cell in cells)


def _normalize_verdict(value: str) -> str:
    return value.strip().strip("`").upper()


def parse_packet(path: Path) -> PacketVerdictSummary:
    verdict_index: int | None = None
    counts = {verdict: 0 for verdict in KNOWN_VERDICTS}
    invalid_verdicts: list[InvalidVerdict] = []

    for line in path.read_text(encoding="utf-8").splitlines():
        cells = _split_markdown_row(line)
        if not cells:
            continue
        if "Reviewer verdict" in cells:
            verdict_index = cells.index("Reviewer verdict")
            continue
        if verdict_index is None or _is_separator_row(cells):
            continue
        if len(cells) <= verdict_index:
            continue

        target = cells[0]
        if not target.startswith(REVIEW_TARGET_KINDS):
            continue

        verdict = _normalize_verdict(cells[verdict_index])
        if verdict in counts:
            counts[verdict] += 1
        else:
            invalid_verdicts.append(InvalidVerdict(target=target, verdict=verdict))

    total_targets = sum(counts.values()) + len(invalid_verdicts)
    return PacketVerdictSummary(
        packet=_display_path(path),
        total_targets=total_targets,
        pass_count=counts["PASS"],
        pending_count=counts["PENDING"],
        flag_count=counts["FLAG"],
        fail_count=counts["FAIL"],
        waived_count=counts["WAIVED"],
        invalid_verdicts=invalid_verdicts,
    )


def build_report(packet_paths: list[Path]) -> VerdictReport:
    packets = [parse_packet(path) for path in packet_paths]
    total_targets = sum(packet.total_targets for packet in packets)
    pass_count = sum(packet.pass_count for packet in packets)
    pending_count = sum(packet.pending_count for packet in packets)
    flag_count = sum(packet.flag_count for packet in packets)
    fail_count = sum(packet.fail_count for packet in packets)
    waived_count = sum(packet.waived_count for packet in packets)
    invalid_count = sum(len(packet.invalid_verdicts) for packet in packets)

    blockers: list[str] = []
    if pending_count:
        blockers.append(f"PENDING_VERDICTS: {pending_count} target(s) still need human verdicts")
    if flag_count:
        blockers.append(f"FLAG_VERDICTS: {flag_count} target(s) need waiver or regeneration before broad rollout")
    if fail_count:
        blockers.append(f"FAIL_VERDICTS: {fail_count} target(s) need fix/regeneration before broad rollout")
    if invalid_count:
        blockers.append(f"INVALID_VERDICTS: {invalid_count} target(s) have unsupported verdict values")
    if total_targets == 0:
        blockers.append("NO_REVIEW_TARGETS: no review item rows were found")

    return VerdictReport(
        packets=packets,
        total_targets=total_targets,
        pass_count=pass_count,
        pending_count=pending_count,
        flag_count=flag_count,
        fail_count=fail_count,
        waived_count=waived_count,
        invalid_count=invalid_count,
        blockers=blockers,
    )


def default_packet_paths() -> list[Path]:
    return sorted(_repo_root().glob(DEFAULT_PACKET_GLOB))


def _packet_paths_from_args(values: list[Path] | None) -> list[Path]:
    if values:
        return values
    return default_packet_paths()


def _print_human(report: VerdictReport) -> None:
    print(f"packets {len(report.packets)}")
    print(f"targets {report.total_targets}")
    print(f"pass {report.pass_count}")
    print(f"pending {report.pending_count}")
    print(f"flag {report.flag_count}")
    print(f"fail {report.fail_count}")
    print(f"waived {report.waived_count}")
    print(f"invalid {report.invalid_count}")
    print("packet_details")
    for packet in report.packets:
        print(
            "- "
            f"{packet.packet}: total={packet.total_targets} pass={packet.pass_count} "
            f"pending={packet.pending_count} flag={packet.flag_count} fail={packet.fail_count} "
            f"waived={packet.waived_count} invalid={len(packet.invalid_verdicts)}"
        )
        for invalid in packet.invalid_verdicts:
            print(f"  - invalid {invalid.target}: {invalid.verdict}")
    print("blockers")
    for blocker in report.blockers:
        print(f"- {blocker}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Report human verdict progress for N4 audio QA packets.")
    parser.add_argument(
        "--packet",
        action="append",
        type=Path,
        default=None,
        help="Packet markdown path. Defaults to all N4 human audio QA chapter packets.",
    )
    parser.add_argument("--json", action="store_true", help="Print JSON instead of the default line-oriented report")
    parser.add_argument("--fail-on-blocker", action="store_true", help="Exit 1 when PENDING/FLAG/FAIL/invalid verdicts remain")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    packet_paths = _packet_paths_from_args(args.packet)
    report = build_report(packet_paths)
    if args.json:
        print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    else:
        _print_human(report)
    if args.fail_on_blocker and report.blockers:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
