import csv
from pathlib import Path

from scripts.build_n4_audio_qa_delegated_pending_clearance import (
    PASS_NOTE,
    build_clearance_report,
    render_markdown,
    write_clearance_csv,
)


def _write_packet(path: Path) -> Path:
    path.write_text(
        "\n".join(
            [
                "# Packet",
                "",
                "## Review Items",
                "",
                "### HN4-001 - 테스트",
                "",
                "| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |",
                "|---|---|---|---|---|---|---|---|---|",
                "| script 0 | 先生 | 少し頭が痛いです。 | 머리가 조금 아픕니다. | elevenlabs / model | ok | "
                "[audio](https://example.com/script-0.mp3) | PENDING |  |",
                "",
                "| question 1 |  | 心配의 뜻은? |  | elevenlabs / model | ok | [audio](https://example.com/question-1.mp3) | PENDING |  |",
                "",
                "| question 3 |  | 名前を書き___. (이름을 쓰세요.) |  | elevenlabs / model | ok | "
                "[audio](https://example.com/question-3.mp3) | PENDING |  |",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def _write_signal_report(path: Path) -> Path:
    path.write_text(
        "\n".join(
            [
                "# Signal report",
                "",
                "## Review-Priority Warnings",
                "",
                "- HN4-001 script:0: TRANSCRIPTION_TEXT_MISMATCH:少し頭が痛い",
                "- HN4-001 question:1: TRANSCRIPTION_TEXT_MISMATCH:しんぺいげんつ",
                "- HN4-001 question:3: HIGH_SILENCE_RATIO:0.3863, TRANSCRIPTION_TEXT_MISMATCH:名前を書き イムルスセヨ",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def test_build_clearance_report_only_approves_mixed_prompt_without_machine_warning(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")

    report = build_clearance_report(packet_paths=[packet], machine_report_paths=[signal_report])

    assert report.total_review_items == 3
    assert report.pending_review_signal_items == 3
    assert report.approved_count == 1
    assert report.held_count == 2
    assert [item.target_key for item in report.approved_items] == ["HN4-001 question:1"]
    assert report.held_bucket_counts == {
        "NEAR_JAPANESE_MATCH": 1,
        "P0_MACHINE_WARNING": 1,
    }


def test_render_markdown_states_boundaries_and_held_rows(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_clearance_report(packet_paths=[packet], machine_report_paths=[signal_report])

    markdown = render_markdown(report, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "> Status: MIXED-PROMPT PASS CSV GENERATED" in markdown
    assert "ASSUMPTION: A `MIXED_PROMPT_STT_UNRELIABLE` row" in markdown
    assert "| Delegated PASS rows in CSV | 1 |" in markdown
    assert "| HN4-001 question:1 | MIXED_PROMPT_STT_UNRELIABLE" in markdown
    assert "| HN4-001 script:0 | NEAR_JAPANESE_MATCH" in markdown
    assert "Broad/full N4 rollout remains blocked" in markdown


def test_write_clearance_csv_marks_only_approved_rows_for_apply(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_clearance_report(packet_paths=[packet], machine_report_paths=[signal_report])
    output = tmp_path / "clearance.csv"

    approved_count = write_clearance_csv(output, report)

    csv_text = output.read_text(encoding="utf-8")
    assert approved_count == 1
    assert "\r\n" not in csv_text
    rows = list(csv.DictReader(csv_text.splitlines()))
    approved = [row for row in rows if row["new_verdict"] == "PASS"]
    held = [row for row in rows if row["new_verdict"] == ""]
    assert [row["target_key"] for row in approved] == ["HN4-001 question:1"]
    assert approved[0]["new_notes"] == PASS_NOTE
    assert {row["target_key"] for row in held} == {"HN4-001 script:0", "HN4-001 question:3"}
