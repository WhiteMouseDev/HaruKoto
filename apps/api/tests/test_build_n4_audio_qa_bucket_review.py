import csv
from pathlib import Path

from scripts.build_n4_audio_qa_bucket_review import (
    build_bucket_review_report,
    render_html,
    render_markdown,
    write_bucket_review_csv,
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
                "| question 1 |  | 心配의 뜻은? |  | elevenlabs / model | ok | [audio](https://example.com/question-1.mp3) | PENDING |  |",
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
                "- HN4-001 question:1: TRANSCRIPTION_TEXT_MISMATCH:しんぺいげんつ",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def test_build_bucket_review_report_defaults_to_lexical_risk(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")

    report = build_bucket_review_report(packet_paths=[packet], machine_report_paths=[signal_report])

    assert report.total_review_items == 3
    assert report.pending_review_signal_items == 3
    assert report.selected_count == 1
    assert report.buckets == ("LEXICAL_RISK",)
    assert report.selected_bucket_counts == {"LEXICAL_RISK": 1}
    assert [(item.target_key, item.bucket) for item in report.items] == [("HN4-001 script:1", "LEXICAL_RISK")]


def test_render_markdown_keeps_focused_review_separate_from_verdicts(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_bucket_review_report(packet_paths=[packet], machine_report_paths=[signal_report])

    markdown = render_markdown(report, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "> Status: FOCUSED REVIEW BATCH - no verdicts applied" in markdown
    assert "does not set `PASS`, `FLAG`, `FAIL`, or" in markdown
    assert "| Selected review items | 1 |" in markdown
    assert "| LEXICAL_RISK | HN4-001 script:1 | 諦めないで" in markdown
    assert "HN4-001 script:0" not in markdown
    assert "Blank rows are ignored by `scripts/apply_n4_audio_qa_verdicts.py`." in markdown


def test_write_bucket_review_csv_leaves_verdict_columns_blank(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_bucket_review_report(packet_paths=[packet], machine_report_paths=[signal_report])
    output = tmp_path / "bucket-review.csv"

    count = write_bucket_review_csv(output, report)

    csv_text = output.read_text(encoding="utf-8")
    assert count == 1
    assert "\r\n" not in csv_text
    assert "target_key,packet,priority,bucket" in csv_text
    rows = list(csv.DictReader(csv_text.splitlines()))
    assert rows == [
        {
            "target_key": "HN4-001 script:1",
            "packet": str(packet),
            "priority": "P1 STT mismatch",
            "bucket": "LEXICAL_RISK",
            "similarity": "0.786",
            "review_signals": "TRANSCRIPTION_TEXT_MISMATCH:始めないで競いに行きましょう",
            "japanese_text": "諦めないで、急いで行きましょう。",
            "korean_context": "포기하지 말고 서둘러 갑시다.",
            "stt_transcript": "始めないで競いに行きましょう",
            "audio_url": "https://example.com/script-1.mp3",
            "recommended_action": "listen carefully before PASS; prefer FLAG when the source text is not clearly spoken",
            "new_verdict": "",
            "new_notes": "",
        }
    ]


def test_render_html_includes_audio_controls_for_selected_items_only(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_bucket_review_report(packet_paths=[packet], machine_report_paths=[signal_report])

    html = render_html(report, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "<title>N4 Audio QA Bucket Review Sheet</title>" in html
    assert "https://example.com/script-1.mp3" in html
    assert "https://example.com/script-0.mp3" not in html
    assert "It does not apply packet verdicts." in html
