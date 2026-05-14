from pathlib import Path

from scripts.apply_n4_audio_qa_verdicts import apply_updates, read_updates, write_template
from scripts.report_n4_audio_qa_verdicts import parse_packet


def _write_packet(path: Path) -> Path:
    path.write_text(
        "\n".join(
            [
                "# Packet",
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
            ]
        ),
        encoding="utf-8",
    )
    return path


def _write_machine_report(path: Path) -> Path:
    path.write_text("- HN4-001 question:3: HIGH_SILENCE_RATIO:0.3863\n", encoding="utf-8")
    return path


def test_write_template_includes_edit_columns_and_priority(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    machine_report = _write_machine_report(tmp_path / "machine.md")
    output = tmp_path / "template.csv"

    count = write_template(output, packet_paths=[packet], machine_report_paths=[machine_report])

    csv_text = output.read_text(encoding="utf-8")
    assert count == 2
    assert "target_key,packet,priority" in csv_text
    assert "new_verdict,new_notes" in csv_text
    assert "HN4-001 question:3" in csv_text
    assert "P0 machine warning" in csv_text


def test_apply_updates_dry_run_does_not_modify_packet(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    csv_path = tmp_path / "updates.csv"
    csv_path.write_text(
        "\n".join(
            [
                "target_key,packet,new_verdict,new_notes",
                f"HN4-001 question:3,{packet},PASS,checked in browser",
                "",
            ]
        ),
        encoding="utf-8",
    )

    result = apply_updates(read_updates(csv_path), write=False)

    assert result.matched == 1
    assert result.changed == 1
    assert parse_packet(packet).pending_count == 2


def test_apply_updates_writes_verdict_and_notes(tmp_path: Path) -> None:
    packet = _write_packet(tmp_path / "packet.md")
    csv_path = tmp_path / "updates.csv"
    csv_path.write_text(
        "\n".join(
            [
                "target_key,packet,new_verdict,new_notes",
                f"HN4-001 question:3,{packet},PASS,checked in browser",
                "",
            ]
        ),
        encoding="utf-8",
    )

    result = apply_updates(read_updates(csv_path), write=True)

    assert result.matched == 1
    assert result.changed == 1
    assert parse_packet(packet).pass_count == 1
    assert parse_packet(packet).pending_count == 1
    assert "checked in browser" in packet.read_text(encoding="utf-8")


def test_read_updates_rejects_invalid_verdict(tmp_path: Path) -> None:
    csv_path = tmp_path / "updates.csv"
    csv_path.write_text(
        "\n".join(
            [
                "target_key,packet,new_verdict,new_notes",
                "HN4-001 question:3,packet.md,MAYBE,",
                "",
            ]
        ),
        encoding="utf-8",
    )

    try:
        read_updates(csv_path)
    except ValueError as error:
        assert "unsupported verdict" in str(error)
    else:
        raise AssertionError("expected invalid verdict to fail")
