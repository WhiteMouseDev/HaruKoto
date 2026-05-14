import csv
from pathlib import Path

from scripts.build_n4_audio_qa_pass_candidates import (
    build_candidate_report,
    render_html,
    render_markdown,
    write_candidate_csv,
)


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
                "[audio](https://example.com/script-0.mp3) | PENDING |  |",
                "",
                "| script 1 | 佐藤 | はい、ここに書けばいいですか。 | 네, 여기에 쓰면 되나요? | elevenlabs / model | ok | "
                "[audio](https://example.com/script-1.mp3) | PENDING |  |",
                "",
                "| question 3 |  | 名前を書き___. |  | elevenlabs / model | ok | "
                "[audio](https://example.com/question-3.mp3) | PENDING |  |",
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


def _write_signal_report(path: Path) -> Path:
    path.write_text(
        "\n".join(
            [
                "# Signal report",
                "",
                "## Review-Priority Warnings",
                "",
                "- HN4-001 script:1: TRANSCRIPTION_TEXT_MISMATCH:はい、そこに書けばいいですか。",
                "- HN4-001 question:3: HIGH_SILENCE_RATIO:0.3863, TRANSCRIPTION_TEXT_MISMATCH:名前を書き",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def test_build_candidate_report_only_includes_pending_rows_without_signals(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")

    report = build_candidate_report(packet_paths=[packet], machine_report_paths=[signal_report])

    assert report.total_items == 4
    assert report.pending_count == 3
    assert report.candidate_count == 1
    assert report.held_for_review_count == 2
    assert report.machine_warning_count == 1
    assert report.stt_mismatch_count == 2
    assert [item.target_key for item in report.candidates] == ["HN4-001 script:0"]


def test_render_markdown_keeps_candidates_separate_from_final_verdicts(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_candidate_report(packet_paths=[packet], machine_report_paths=[signal_report])

    markdown = render_markdown(report, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "> Status: PASS CANDIDATES - no verdicts applied" in markdown
    assert "ASSUMPTION: A candidate means" in markdown
    assert "| AI-assisted PASS candidates | 1 |" in markdown
    assert "| HN4-001 script:0 | 名前を書きなさい。" in markdown
    assert "P0 machine-warning and P1 STT-mismatch rows stay out of the candidate CSV." in markdown


def test_write_candidate_csv_leaves_apply_columns_blank_until_listening_confirmation(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_candidate_report(packet_paths=[packet], machine_report_paths=[signal_report])
    output = tmp_path / "candidates.csv"

    count = write_candidate_csv(output, report)

    csv_text = output.read_text(encoding="utf-8")
    assert count == 1
    assert "\r\n" not in csv_text
    assert "target_key,packet,priority" in csv_text
    assert "candidate_reason,recommended_action,new_verdict,new_notes" in csv_text
    assert "HN4-001 script:0" in csv_text
    assert "HN4-001 script:1" not in csv_text
    rows = list(csv.DictReader(csv_text.splitlines()))
    assert rows[0]["recommended_action"] == "listen once; if complete and intelligible, set new_verdict=PASS"
    assert rows[0]["new_verdict"] == ""
    assert rows[0]["new_notes"] == ""


def test_render_html_includes_candidate_audio_controls_only(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    report = build_candidate_report(packet_paths=[packet], machine_report_paths=[signal_report])

    html = render_html(report, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "N4 Audio QA PASS Candidate Listening Sheet" in html
    assert "Candidate status is not a final human audio-quality verdict." in html
    assert "PASS candidates<strong>1</strong>" in html
    assert "HN4-001 script:0" in html
    assert '<audio controls preload="none" src="https://example.com/script-0.mp3"></audio>' in html
    assert "HN4-001 script:1" not in html
    assert "HIGH_SILENCE_RATIO:0.3863" not in html
