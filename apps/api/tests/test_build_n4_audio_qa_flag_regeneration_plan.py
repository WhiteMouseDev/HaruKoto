import csv
from pathlib import Path

from scripts.build_n4_audio_qa_flag_regeneration_plan import (
    build_regeneration_plan,
    render_markdown,
    write_csv,
)


def _write_packet(path: Path) -> Path:
    flagged_audio = "https://storage.googleapis.com/harukoto-storage/tts/lesson/11111111-1111-1111-1111-111111111111/script-line-0.mp3"
    flag_note = (
        "Delegated AI-assisted FLAG: STT/source lexical divergence suggests possible wrong-word audio; "
        "regenerate or direct-listen before broad rollout; not native-speaker review."
    )
    path.write_text(
        "\n".join(
            [
                "# Packet",
                "",
                "### HN4-001 - 테스트",
                "",
                "| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |",
                "|---|---|---|---|---|---|---|---|---|",
                "| script 0 | 先生 | 諦めないで、急いで行きましょう。 | 포기하지 말고 서둘러 갑시다. | elevenlabs / model | ok | "
                f"[audio]({flagged_audio}) | FLAG | {flag_note} |",
                "",
                "| script 1 | 学生 | 心配ですね。 | 걱정이네요. | elevenlabs / model | ok | "
                "[audio](https://example.com/script-1.mp3) | PENDING |  |",
                "",
                "| question 1 |  | 心配의 뜻은? |  | elevenlabs / model | ok | "
                "[audio](https://example.com/question-1.mp3) | PASS | checked |",
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
                "- HN4-001 script:0: TRANSCRIPTION_TEXT_MISMATCH:始めないで競いに行きましょう",
                "- HN4-001 script:1: TRANSCRIPTION_TEXT_MISMATCH:心配ですね",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return path


def test_build_regeneration_plan_extracts_only_flag_rows(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")

    plan = build_regeneration_plan(packet_paths=[packet], machine_report_paths=[signal_report])

    assert plan.total_review_items == 3
    assert plan.pass_count == 1
    assert plan.pending_count == 1
    assert plan.flag_count == 1
    assert len(plan.items) == 1

    item = plan.items[0]
    assert item.target_key == "HN4-001 script:0"
    assert item.target_kind == "script"
    assert item.target_order == 0
    assert item.lesson_id == "11111111-1111-1111-1111-111111111111"
    assert item.target_type == "lesson_script_line"
    assert item.field == "script_line"
    assert item.target_id == "11111111-1111-1111-1111-111111111111:script:0"
    assert item.stt_transcript == "始めないで競いに行きましょう"
    assert item.recommended_action == "regenerate audio, then listen before clearing FLAG"


def test_render_markdown_keeps_regeneration_boundary_explicit(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    plan = build_regeneration_plan(packet_paths=[packet], machine_report_paths=[signal_report])

    markdown = render_markdown(plan, packet_paths=[packet], machine_report_paths=[signal_report])

    assert "> Status: REGENERATION HANDOFF - no audio generated" in markdown
    assert "no TTS provider call, storage write" in markdown
    assert "| Current FLAG verdicts | 1 |" in markdown
    assert "| Script-line rows | 1 |" in markdown
    assert "generate_n4_pilot_tts_batch.py` currently generates missing TTS" in markdown
    assert "HN4-001 script:0" in markdown
    assert "HN4-001 script:1" not in markdown


def test_write_csv_leaves_post_regeneration_columns_blank(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    signal_report = _write_signal_report(tmp_path / "signals.md")
    plan = build_regeneration_plan(packet_paths=[packet], machine_report_paths=[signal_report])
    output = tmp_path / "flag-regeneration.csv"

    count = write_csv(output, plan)

    assert count == 1
    csv_text = output.read_text(encoding="utf-8")
    assert "\r\n" not in csv_text
    rows = list(csv.DictReader(csv_text.splitlines()))
    assert rows[0]["target_key"] == "HN4-001 script:0"
    assert rows[0]["target_id"] == "11111111-1111-1111-1111-111111111111:script:0"
    assert rows[0]["regeneration_status"] == ""
    assert rows[0]["new_audio_url"] == ""
    assert rows[0]["post_regen_verdict"] == ""
    assert rows[0]["post_regen_notes"] == ""
