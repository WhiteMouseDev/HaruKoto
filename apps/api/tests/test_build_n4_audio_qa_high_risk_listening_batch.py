import csv
from pathlib import Path

from scripts.build_n4_audio_qa_high_risk_listening_batch import (
    build_high_risk_listening_batch_report,
    render_html,
    render_markdown,
    write_high_risk_csv,
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


def test_build_high_risk_batch_only_includes_p0_and_lexical_risk(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")

    report = build_high_risk_listening_batch_report(packet_paths=[packet], machine_report_paths=[signal_report])

    assert report.total_review_items == 6
    assert report.pending_review_signal_items == 5
    assert report.batch_count == 2
    assert report.p0_machine_warning_count == 1
    assert report.lexical_risk_count == 1
    assert [(item.target_key, item.bucket) for item in report.items] == [
        ("HN4-001 question:3", "P0_MACHINE_WARNING"),
        ("HN4-001 script:1", "LEXICAL_RISK"),
    ]


def test_render_markdown_keeps_batch_separate_from_verdicts(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_high_risk_listening_batch_report(packet_paths=[packet], machine_report_paths=[signal_report])

    markdown = render_markdown(report, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "> Status: LISTENING BATCH - no verdicts applied" in markdown
    assert "It does not set `PASS`, `FLAG`, `FAIL`, or `WAIVED`" in markdown
    assert "| High-risk listening batch | 2 |" in markdown
    assert "| P0_MACHINE_WARNING | HN4-001 question:3 | 名前を書き___." in markdown
    assert "| LEXICAL_RISK | HN4-001 script:1 | 諦めないで、急いで行きましょう。" in markdown
    assert "HN4-001 script:2" not in markdown
    assert "HN4-001 question:1" not in markdown
    assert "Broad/full N4 rollout remains blocked." in markdown


def test_write_high_risk_csv_leaves_verdict_columns_blank(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_high_risk_listening_batch_report(packet_paths=[packet], machine_report_paths=[signal_report])
    output = tmp_path / "high-risk.csv"

    count = write_high_risk_csv(output, report)

    csv_text = output.read_text(encoding="utf-8")
    assert count == 2
    assert "\r\n" not in csv_text
    assert "target_key,packet,priority,bucket" in csv_text
    assert "current_verdict,recommended_action,new_verdict,new_notes" in csv_text
    assert "HN4-001 script:2" not in csv_text
    rows = list(csv.DictReader(csv_text.splitlines()))
    assert rows[0]["target_key"] == "HN4-001 question:3"
    assert rows[0]["current_verdict"] == "PENDING"
    assert rows[0]["new_verdict"] == ""
    assert rows[0]["new_notes"] == ""
    assert rows[1]["bucket"] == "LEXICAL_RISK"


def test_render_html_includes_high_risk_audio_controls_only(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_high_risk_listening_batch_report(packet_paths=[packet], machine_report_paths=[signal_report])

    html = render_html(report, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "N4 Audio QA High-Risk Listening Batch" in html
    assert "This file does not apply PASS, FLAG, FAIL, or WAIVED." in html
    assert "High-risk batch<strong>2</strong>" in html
    assert "HN4-001 question:3" in html
    assert "HN4-001 script:1" in html
    assert '<audio controls preload="none" src="https://example.com/question-3.mp3"></audio>' in html
    assert '<audio controls preload="none" src="https://example.com/script-1.mp3"></audio>' in html
    assert "HN4-001 script:2" not in html
    assert "HN4-001 question:1" not in html
