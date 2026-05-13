from pathlib import Path

from scripts.report_n4_audio_qa_verdicts import build_report, parse_packet


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
