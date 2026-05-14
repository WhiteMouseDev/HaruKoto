import csv
from pathlib import Path

from scripts.build_n4_audio_qa_stt_reconciliation import (
    build_reconciliation_report,
    render_markdown,
    write_reconciliation_csv,
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
                "| script 0 | 先生 | 心配ですね。今日は早く寝たほうがいいです。 | 걱정이네요. | elevenlabs / model | ok | "
                "[audio](https://example.com/script-0.mp3) | PENDING |  |",
                "",
                "| script 1 | 学生 | 諦めないで、急いで行きましょう。 | 포기하지 말고 서둘러 갑시다. | elevenlabs / model | ok | "
                "[audio](https://example.com/script-1.mp3) | PENDING |  |",
                "",
                "| script 2 | 先生 | 少し頭が痛いです。 | 머리가 조금 아픕니다. | elevenlabs / model | ok | "
                "[audio](https://example.com/script-2.mp3) | PENDING |  |",
                "",
                "| question 1 |  | 心配의 뜻은? |  | elevenlabs / model | ok | [audio](https://example.com/question-1.mp3) | PENDING |  |",
                "",
                "| question 3 |  | 名前を書き___. (이름을 쓰세요.) |  | elevenlabs / model | ok | "
                "[audio](https://example.com/question-3.mp3) | PENDING |  |",
                "",
                "| script 3 | 先生 | これは確認済みです。 | 확인했습니다. | elevenlabs / model | ok | "
                "[audio](https://example.com/script-3.mp3) | PASS | checked |",
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
                "- HN4-001 script:0: TRANSCRIPTION_TEXT_MISMATCH:心配ですね。今日は早く寝た方がいいです。",
                "- HN4-001 script:1: TRANSCRIPTION_TEXT_MISMATCH:始めないで競いに行きましょう",
                "- HN4-001 script:2: TRANSCRIPTION_TEXT_MISMATCH:少し頭が痛い",
                "- HN4-001 question:1: TRANSCRIPTION_TEXT_MISMATCH:しんぺいげんつ",
                "- HN4-001 question:3: HIGH_SILENCE_RATIO:0.3863, TRANSCRIPTION_TEXT_MISMATCH:名前を書き イムルスセヨ",
                "- HN4-001 script:3: TRANSCRIPTION_TEXT_MISMATCH:これは確認済みです。",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def test_build_reconciliation_report_buckets_pending_signal_items(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")

    report = build_reconciliation_report(packet_paths=[packet], machine_report_paths=[signal_report])

    assert report.total_review_items == 6
    assert report.pending_review_signal_items == 5
    assert report.p0_machine_warning_count == 1
    assert report.p1_stt_only_count == 4
    assert report.canonical_match_count == 1
    assert report.near_japanese_match_count == 1
    assert report.mixed_prompt_count == 1
    assert report.lexical_risk_count == 1
    assert [(item.target_key, item.bucket) for item in report.items] == [
        ("HN4-001 question:3", "P0_MACHINE_WARNING"),
        ("HN4-001 script:1", "LEXICAL_RISK"),
        ("HN4-001 script:2", "NEAR_JAPANESE_MATCH"),
        ("HN4-001 script:0", "CANONICAL_MATCH"),
        ("HN4-001 question:1", "MIXED_PROMPT_STT_UNRELIABLE"),
    ]


def test_render_markdown_keeps_triage_separate_from_verdicts(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_reconciliation_report(packet_paths=[packet], machine_report_paths=[signal_report])

    markdown = render_markdown(report, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "> Status: TRIAGE ONLY - no verdicts applied" in markdown
    assert "does not set `PASS`, `FLAG`, `FAIL`, or" in markdown
    assert "| Pending review-signal items | 5 |" in markdown
    assert "## P0_MACHINE_WARNING" in markdown
    assert "| P0_MACHINE_WARNING | HN4-001 question:3 | 名前を書き___." in markdown
    assert "## CANONICAL_MATCH" in markdown
    assert "| CANONICAL_MATCH | HN4-001 script:0 | 心配ですね。" in markdown
    assert "Broad/full N4 rollout remains blocked." in markdown


def test_write_reconciliation_csv_leaves_verdict_columns_blank(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_reconciliation_report(packet_paths=[packet], machine_report_paths=[signal_report])
    output = tmp_path / "reconciliation.csv"

    count = write_reconciliation_csv(output, report)

    csv_text = output.read_text(encoding="utf-8")
    assert count == 5
    assert "\r\n" not in csv_text
    assert "target_key,packet,priority,bucket" in csv_text
    rows = list(csv.DictReader(csv_text.splitlines()))
    assert rows[0]["target_key"] == "HN4-001 question:3"
    assert rows[0]["new_verdict"] == ""
    assert rows[0]["new_notes"] == ""
    assert rows[3]["bucket"] == "CANONICAL_MATCH"
    assert rows[3]["recommended_action"].startswith("candidate for delegated PASS")
