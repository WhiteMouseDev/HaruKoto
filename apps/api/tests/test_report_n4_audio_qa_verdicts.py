from pathlib import Path

import pytest

import scripts.report_n4_audio_qa_verdicts as verdicts
from scripts.report_n4_audio_qa_verdicts import build_report, default_packet_paths, parse_packet


def _write_packet(path: Path, verdicts: list[str]) -> Path:
    rows = "\n\n".join(
        f"| question {index} |  | 問題 {index} |  | elevenlabs / eleven_multilingual_v2 | ok | "
        f"[audio](https://example.com/{index}.mp3) | {verdict} |  |"
        for index, verdict in enumerate(verdicts, start=1)
    )
    path.write_text(
        "\n".join(
            [
                "# Packet",
                "",
                "| Verdict | Meaning | Broad-rollout impact |",
                "|---|---|---|",
                "| PASS | rubric row ignored | ignored |",
                "",
                "| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |",
                "|---|---|---|---|---|---|---|---|---|",
                rows,
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def test_parse_packet_counts_only_review_item_verdict_column(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md", ["PASS", "PENDING", "FLAG", "FAIL", "WAIVED"])

    summary = parse_packet(packet)

    assert summary.total_targets == 5
    assert summary.pass_count == 1
    assert summary.pending_count == 1
    assert summary.flag_count == 1
    assert summary.fail_count == 1
    assert summary.waived_count == 1
    assert summary.invalid_verdicts == []


def test_build_report_marks_pending_flag_fail_and_invalid_as_blockers(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md", ["PASS", "PENDING", "FLAG", "FAIL", "MAYBE"])

    report = build_report([packet])

    assert report.total_targets == 5
    assert report.pass_count == 1
    assert report.pending_count == 1
    assert report.flag_count == 1
    assert report.fail_count == 1
    assert report.invalid_count == 1
    assert report.blockers == [
        "PENDING_VERDICTS: 1 target(s) still need human verdicts",
        "FLAG_VERDICTS: 1 target(s) need waiver or regeneration before broad rollout",
        "FAIL_VERDICTS: 1 target(s) need fix/regeneration before broad rollout",
        "INVALID_VERDICTS: 1 target(s) have unsupported verdict values",
    ]


def test_build_report_marks_empty_packets_as_blocked(tmp_path: Path) -> None:
    packet = tmp_path / "empty.md"
    packet.write_text("# Empty\n", encoding="utf-8")

    report = build_report([packet])

    assert report.total_targets == 0
    assert report.blockers == ["NO_REVIEW_TARGETS: no review item rows were found"]


def test_default_packet_paths_include_pilot_packets_through_ch07() -> None:
    packets = [path.as_posix() for path in default_packet_paths()]

    assert any("n4-pilot-human-audio-qa-ch01-2026-05-13.md" in packet for packet in packets)
    assert any("n4-wave2-draft-human-audio-qa-ch04-2026-05-20.md" in packet for packet in packets)
    assert any("n4-wave3-draft-human-audio-qa-ch05-2026-05-27.md" in packet for packet in packets)
    assert any("n4-ch06-pilot-human-audio-qa-ch06-2026-06-01.md" in packet for packet in packets)
    assert any("n4-ch07-pilot-human-audio-qa-ch07-2026-06-05.md" in packet for packet in packets)


def test_default_packet_paths_can_select_n5_packets() -> None:
    packets = default_packet_paths(level="N5")

    assert any("n5-human-audio-qa-ch01-" in packet.name for packet in packets)
    assert all(packet.name.startswith("n5-human-audio-qa-ch") for packet in packets)


def test_n5_discovery_uses_latest_packet_per_chapter_without_reusing_old_passes(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    directory = tmp_path / "docs/operations/plans"
    directory.mkdir(parents=True)
    old = _write_packet(directory / "n5-human-audio-qa-ch01-2026-05-26.md", ["PASS"])
    current = _write_packet(directory / "n5-human-audio-qa-ch01-2026-10-26.md", ["PENDING"])
    chapter_two = _write_packet(directory / "n5-human-audio-qa-ch02-2026-05-26.md", ["FLAG"])
    monkeypatch.setattr(verdicts, "_repo_root", lambda: tmp_path)

    paths = default_packet_paths(level="n5")
    report = build_report(paths)

    assert paths == sorted([current, chapter_two])
    assert old not in paths
    assert report.total_targets == 2
    assert report.pass_count == 0
    assert report.pending_count == 1
    assert report.flag_count == 1


def test_n5_discovery_rejects_ambiguous_same_day_chapter_packets(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    directory = tmp_path / "docs/operations/plans"
    directory.mkdir(parents=True)
    _write_packet(directory / "n5-human-audio-qa-ch1-2026-10-26.md", ["PASS"])
    _write_packet(directory / "n5-human-audio-qa-ch01-2026-10-26.md", ["PENDING"])
    monkeypatch.setattr(verdicts, "_repo_root", lambda: tmp_path)

    with pytest.raises(ValueError, match="Multiple latest N5 packets for chapter 1"):
        default_packet_paths(level="N5")


def test_explicit_packet_selection_can_inspect_a_historical_snapshot(tmp_path: Path) -> None:
    historical = _write_packet(tmp_path / "n5-human-audio-qa-ch01-2026-05-26.md", ["PASS"])

    assert verdicts._packet_paths_from_args([historical], level="N5") == [historical]


def test_unknown_level_default_discovery_remains_blocked() -> None:
    report = build_report(default_packet_paths(level="N1"))

    assert report.total_targets == 0
    assert report.blockers == ["NO_REVIEW_TARGETS: no review item rows were found"]


@pytest.mark.parametrize("name", ["n5-human-audio-qa-ch01-2026-99-99.md", "n5-human-audio-qa-ch01-undated.md"])
def test_n5_discovery_rejects_invalid_snapshot_names_instead_of_falling_back_to_old_pass(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, name: str
) -> None:
    directory = tmp_path / "docs/operations/plans"
    directory.mkdir(parents=True)
    _write_packet(directory / "n5-human-audio-qa-ch01-2026-05-26.md", ["PASS"])
    _write_packet(directory / name, ["PENDING"])
    monkeypatch.setattr(verdicts, "_repo_root", lambda: tmp_path)

    with pytest.raises(ValueError, match="N5 packet"):
        default_packet_paths(level="N5")
