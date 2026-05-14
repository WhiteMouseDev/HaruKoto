from pathlib import Path

from scripts.build_n4_audio_qa_review_queue import build_queue, parse_review_signals, render_html, render_markdown


def _write_packet(path: Path) -> Path:
    path.write_text(
        "\n".join(
            [
                "# Packet",
                "",
                "## Review Items",
                "",
                "### HN4-001 - 이름을 쓰세요",
                "",
                "| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |",
                "|---|---|---|---|---|---|---|---|---|",
                "| script 0 | キム | 名前を書きなさい。 | 이름을 쓰세요. | elevenlabs / model | ok | "
                "[audio](https://example.com/script.mp3) | PENDING |  |",
                "",
                "| question 3 |  | 規則を守りなさい。 |  | elevenlabs / model | ok | "
                "[audio](https://example.com/question.mp3) | PENDING |  |",
                "",
                "### HN4-002 - 일찍 쉬는 편이 좋아요",
                "",
                "| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |",
                "|---|---|---|---|---|---|---|---|---|",
                "| question 1 |  | 医者に相談します。 |  | elevenlabs / model | ok | "
                "[audio](https://example.com/resolved.mp3) | PASS | checked |",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def _write_machine_report(path: Path) -> Path:
    path.write_text(
        "\n".join(
            [
                "# Machine report",
                "",
                "## Review-Priority Warnings",
                "",
                "- HN4-001 question:3: HIGH_SILENCE_RATIO:0.3863, TRANSCRIPTION_TEXT_MISMATCH:規則を守りなさい。",
                "- HN4-001 script:0: TRANSCRIPTION_TEXT_MISMATCH:名前を聞きなさい。",
                "- HN4-999 question:1: HIGH_SILENCE_RATIO:0.4, TRANSCRIPTION_TEXT_MISMATCH:医者に相談します。",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def test_parse_review_signals_uses_target_keys_and_splits_combined_signals(tmp_path: Path) -> None:
    machine_report = _write_machine_report(tmp_path / "machine.md")

    warnings = parse_review_signals([machine_report])

    assert warnings["HN4-001 question:3"] == [
        "HIGH_SILENCE_RATIO:0.3863",
        "TRANSCRIPTION_TEXT_MISMATCH:規則を守りなさい。",
    ]
    assert warnings["HN4-001 script:0"] == ["TRANSCRIPTION_TEXT_MISMATCH:名前を聞きなさい。"]
    assert warnings["HN4-999 question:1"] == [
        "HIGH_SILENCE_RATIO:0.4",
        "TRANSCRIPTION_TEXT_MISMATCH:医者に相談します。",
    ]


def test_build_queue_prioritizes_machine_then_stt_signal_items(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    machine_report = _write_machine_report(tmp_path / "machine.md")

    report = build_queue(packet_paths=[packet], machine_report_paths=[machine_report])

    assert report.total_items == 3
    assert report.pending_count == 2
    assert report.pass_count == 1
    assert report.machine_warning_count == 1
    assert report.stt_mismatch_count == 2
    assert report.review_signal_count == 2
    assert [item.target_key for item in report.items] == [
        "HN4-001 question:3",
        "HN4-001 script:0",
        "HN4-002 question:1",
    ]
    assert report.items[0].priority == "P0 machine warning"
    assert report.items[0].review_signals == [
        "HIGH_SILENCE_RATIO:0.3863",
        "TRANSCRIPTION_TEXT_MISMATCH:規則を守りなさい。",
    ]
    assert report.items[1].priority == "P1 STT mismatch"
    assert report.items[1].review_signals == ["TRANSCRIPTION_TEXT_MISMATCH:名前を聞きなさい。"]
    assert report.items[2].priority == "P3 resolved"


def test_render_markdown_groups_priority_sections(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    machine_report = _write_machine_report(tmp_path / "machine.md")
    report = build_queue(packet_paths=[packet], machine_report_paths=[machine_report])

    markdown = render_markdown(report, packet_paths=[packet], machine_report_paths=[machine_report])

    assert "> Status: REVIEW QUEUE - human audio verdicts pending" in markdown
    assert "| Review-signal items | 2 |" in markdown
    assert "| P0 machine-warning items | 1 |" in markdown
    assert "| STT-mismatch signal items | 2 |" in markdown
    assert "## P0 Review First" in markdown
    assert "| P0 machine warning | HN4-001 question:3 | 規則を守りなさい。" in markdown
    assert "## P1 STT Mismatch Review" in markdown
    assert "| P1 STT mismatch | HN4-001 script:0 | 名前を書きなさい。" in markdown
    assert "[audio](https://example.com/question.mp3)" in markdown
    assert "## P2 Remaining Pending" in markdown
    assert "## P3 Resolved Or Waived" in markdown
    assert "| P3 resolved | HN4-002 question:1 | 医者に相談します。" in markdown


def test_render_html_includes_audio_controls_and_escapes_text(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    machine_report = _write_machine_report(tmp_path / "machine.md")
    report = build_queue(packet_paths=[packet], machine_report_paths=[machine_report])

    html = render_html(report, packet_paths=[packet], machine_report_paths=[machine_report])

    assert "<!doctype html>" in html
    assert "<h1>N4 Audio QA Review Sheet</h1>" in html
    assert "Record final verdicts in the source packet Markdown files." in html
    assert '<audio controls preload="none" src="https://example.com/question.mp3"></audio>' in html
    assert "P0 machine warning" in html
    assert "P1 STT mismatch" in html
    assert "HIGH_SILENCE_RATIO:0.3863" in html
    assert "TRANSCRIPTION_TEXT_MISMATCH:名前を聞きなさい。" in html
    assert "<h3>規則を守りなさい。</h3>" in html
