import csv
from pathlib import Path

import pytest

from scripts.audit_n4_flag_post_regeneration_audio import (
    PostRegenerationAuditRow,
    build_post_regeneration_report,
    read_regeneration_metadata,
    read_review_targets,
    recommend_verdict,
    render_markdown,
    write_recommendation_csv,
)
from scripts.audit_n4_pilot_tts_audio_quality import (
    AudioProbe,
    TtsSourceTarget,
    TtsStoredRecord,
    build_transcription_probe,
    evaluate_audio_quality,
)


def test_read_review_targets_enriches_rows_from_regeneration_results(tmp_path: Path) -> None:
    review_csv = _write_review_csv(tmp_path / "review.csv")
    regeneration_csv = _write_regeneration_csv(tmp_path / "regeneration.csv")

    metadata = read_regeneration_metadata(regeneration_csv)
    targets = read_review_targets(review_csv, regeneration_metadata=metadata)

    assert len(targets) == 1
    assert targets[0].target_key == "HN4-001 script:3"
    assert targets[0].target_id == "11111111-1111-1111-1111-111111111111:script:3"
    assert targets[0].provider == "elevenlabs"
    assert targets[0].model == "eleven_multilingual_v2"
    assert targets[0].to_source_target().display_name == "HN4-001 script:3"


def test_read_review_targets_can_accept_pending_when_requested(tmp_path: Path) -> None:
    review_csv = _write_review_csv(tmp_path / "review.csv", current_verdict="PENDING")
    regeneration_csv = _write_regeneration_csv(tmp_path / "regeneration.csv")

    metadata = read_regeneration_metadata(regeneration_csv)
    targets = read_review_targets(review_csv, regeneration_metadata=metadata, current_verdicts={"PENDING"})

    assert targets[0].current_verdict == "PENDING"


def test_read_review_targets_rejects_regenerated_audio_url_drift(tmp_path: Path) -> None:
    review_csv = _write_review_csv(tmp_path / "review.csv")
    regeneration_csv = _write_regeneration_csv(
        tmp_path / "regeneration.csv",
        new_audio_url="https://storage.googleapis.com/harukoto-storage/tts/lesson/11111111-1111-1111-1111-111111111111/script-line-3-other.mp3",
    )

    metadata = read_regeneration_metadata(regeneration_csv)

    with pytest.raises(ValueError, match="audio_url does not match"):
        read_review_targets(review_csv, regeneration_metadata=metadata)


def test_clean_probe_and_exact_stt_recommend_pass_and_write_apply_csv(tmp_path: Path) -> None:
    metadata = read_regeneration_metadata(_write_regeneration_csv(tmp_path / "regeneration.csv"))
    item = read_review_targets(_write_review_csv(tmp_path / "review.csv"), regeneration_metadata=metadata)[0]
    target = item.to_source_target()
    transcription = build_transcription_probe(target=target, transcript=item.japanese_text)
    result = evaluate_audio_quality(
        target=target,
        record=item.to_stored_record(),
        probe=_probe(),
        transcription=transcription,
    )
    verdict, notes = recommend_verdict(result, transcribe=True)
    row = PostRegenerationAuditRow(item=item, result=result, recommended_verdict=verdict, recommended_notes=notes)
    report = build_post_regeneration_report([row])
    output = tmp_path / "recommendations.csv"

    count = write_recommendation_csv(output, report)

    rows = list(csv.DictReader(output.read_text(encoding="utf-8").splitlines()))
    assert count == 1
    assert report.recommended_pass_count == 1
    assert report.recommended_flag_count == 0
    assert rows[0]["provider_model"] == "elevenlabs / eleven_multilingual_v2"
    assert rows[0]["new_verdict"] == "PASS"
    assert "post-regeneration PASS" in rows[0]["new_notes"]


def test_stt_mismatch_keeps_flag_recommendation_in_markdown(tmp_path: Path) -> None:
    item = read_review_targets(_write_review_csv(tmp_path / "review.csv"))[0]
    target = item.to_source_target()
    transcription = build_transcription_probe(target=target, transcript="分かりました。定時に確認します。")
    result = evaluate_audio_quality(
        target=target,
        record=item.to_stored_record(),
        probe=_probe(),
        transcription=transcription,
    )
    verdict, notes = recommend_verdict(result, transcribe=True)
    row = PostRegenerationAuditRow(item=item, result=result, recommended_verdict=verdict, recommended_notes=notes)
    report = build_post_regeneration_report([row])

    markdown = render_markdown(
        report,
        command="uv run python scripts/audit_n4_flag_post_regeneration_audio.py --transcribe",
        review_csv=tmp_path / "review.csv",
        regeneration_results_csv=tmp_path / "regeneration.csv",
    )

    assert verdict == "FLAG"
    assert "still has review signal" in notes
    assert "> Status: REVIEW" in markdown
    assert "| Recommended FLAG | 1 |" in markdown
    assert "TRANSCRIPTION_TEXT_MISMATCH" in markdown


def _write_review_csv(path: Path, *, current_verdict: str = "FLAG") -> Path:
    rows = [
        {
            "target_key": "HN4-001 script:3",
            "packet": "docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md",
            "priority": "POST_REGEN_FLAG_REVIEW",
            "review_signals": "TRANSCRIPTION_TEXT_MISMATCH:わかりました。定時に確認します。",
            "japanese_text": "分かりました。丁寧に確認します。",
            "korean_context": "알겠습니다. 꼼꼼히 확인하겠습니다.",
            "audio_url": "https://storage.googleapis.com/harukoto-storage/tts/lesson/11111111-1111-1111-1111-111111111111/script-line-3-regen-RUN.mp3",
            "current_verdict": current_verdict,
            "current_notes": "Delegated AI-assisted FLAG.",
            "new_verdict": "",
            "new_notes": "",
        }
    ]
    return _write_csv(path, rows)


def _write_regeneration_csv(path: Path, *, new_audio_url: str | None = None) -> Path:
    rows = [
        {
            "target_key": "HN4-001 script:3",
            "target_id": "11111111-1111-1111-1111-111111111111:script:3",
            "source_text": "分かりました。丁寧に確認します。",
            "current_audio_url": "https://example.com/old.mp3",
            "status": "regenerated",
            "gcs_path": "tts/lesson/11111111-1111-1111-1111-111111111111/script-line-3-regen-RUN.mp3",
            "old_audio_url": "https://example.com/old.mp3",
            "new_audio_url": new_audio_url
            or "https://storage.googleapis.com/harukoto-storage/tts/lesson/11111111-1111-1111-1111-111111111111/script-line-3-regen-RUN.mp3",
            "provider": "elevenlabs",
            "model": "eleven_multilingual_v2",
            "error": "",
        }
    ]
    return _write_csv(path, rows)


def _write_csv(path: Path, rows: list[dict[str, str]]) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return path


def _probe(**overrides: object) -> AudioProbe:
    values = {
        "content_type": "audio/mpeg",
        "byte_size": 4096,
        "format_name": "mp3",
        "codec_name": "mp3",
        "duration_seconds": 1.8,
        "bit_rate": 128000,
        "silence_seconds": 0.0,
        "silence_ratio": 0.0,
    }
    values.update(overrides)
    return AudioProbe(**values)  # type: ignore[arg-type]


def _target(source_text: str = "分かりました。丁寧に確認します。") -> TtsSourceTarget:
    return TtsSourceTarget(
        lesson_no=1,
        label="HN4-001",
        lesson_id="11111111-1111-1111-1111-111111111111",
        title="알겠습니다. 꼼꼼히 확인하겠습니다.",
        kind="script",
        order=3,
        target_type="lesson_script_line",
        target_id="11111111-1111-1111-1111-111111111111:script:3",
        field="script_line",
        source_text=source_text,
    )


def _record(text: str = "分かりました。丁寧に確認します。") -> TtsStoredRecord:
    return TtsStoredRecord(
        target_id="11111111-1111-1111-1111-111111111111:script:3",
        text=text,
        provider="elevenlabs",
        model="eleven_multilingual_v2",
        audio_url="https://example.com/audio.mp3",
    )
