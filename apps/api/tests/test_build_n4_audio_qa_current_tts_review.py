from pathlib import Path

import pytest

from scripts.build_n4_audio_qa_current_tts_review import (
    CurrentTtsRecord,
    build_review_rows,
    read_manifest_items,
    write_regeneration_results_csv,
    write_review_csv,
)


def test_read_manifest_items_filters_pending_rows(tmp_path: Path) -> None:
    manifest = _write_manifest(tmp_path / "manifest.csv", current_verdict="PENDING")
    _append_manifest_row(manifest, target_key="HN4-002 question:4", current_verdict="FLAG")

    items = read_manifest_items(manifest)

    assert [item.target_key for item in items] == ["HN4-001 question:3"]


def test_build_review_rows_rejects_original_audio_url(tmp_path: Path) -> None:
    item = read_manifest_items(_write_manifest(tmp_path / "manifest.csv"))[0]
    record = _record(audio_url=item.current_audio_url)

    with pytest.raises(ValueError, match="still matches manifest"):
        build_review_rows([item], {item.target_id: record})


def test_write_review_and_regeneration_results_csv(tmp_path: Path) -> None:
    manifest = _write_manifest(tmp_path / "manifest.csv")
    item = read_manifest_items(manifest)[0]
    record = _record(
        audio_url=(
            "https://storage.googleapis.com/harukoto-storage/tts/lesson/11111111-1111-1111-1111-111111111111/question-3-regen-RUN.mp3"
        )
    )
    rows = build_review_rows([item], {item.target_id: record})
    review_csv = tmp_path / "review.csv"
    results_csv = tmp_path / "results.csv"

    assert write_review_csv(review_csv, rows) == 1
    assert write_regeneration_results_csv(results_csv, rows) == 1

    review_text = review_csv.read_text(encoding="utf-8")
    results_text = results_csv.read_text(encoding="utf-8")
    assert "target_key,packet,priority,review_signals" in review_text
    assert "PROVIDER_FALLBACK_REGENERATED" in review_text
    assert ",gemini / gemini-2.5-flash-preview-tts," in review_text
    assert ",PENDING," in review_text
    assert "question-3-regen-RUN.mp3" in results_text
    assert ",regenerated,tts/lesson/11111111-1111-1111-1111-111111111111/question-3-regen-RUN.mp3," in results_text


def _write_manifest(path: Path, *, current_verdict: str = "PENDING") -> Path:
    rows = [
        _manifest_row(
            target_key="HN4-001 question:3",
            target_id="11111111-1111-1111-1111-111111111111:question:3",
            current_verdict=current_verdict,
        )
    ]
    _write_csv(path, rows)
    return path


def _append_manifest_row(path: Path, *, target_key: str, current_verdict: str) -> None:
    rows = [
        _manifest_row(
            target_key=target_key,
            target_id="11111111-1111-1111-1111-111111111111:question:4",
            current_verdict=current_verdict,
        )
    ]
    with path.open("a", encoding="utf-8", newline="") as file:
        import csv

        writer = csv.DictWriter(file, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writerows(rows)


def _manifest_row(*, target_key: str, target_id: str, current_verdict: str) -> dict[str, str]:
    return {
        "target_key": target_key,
        "packet": "docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md",
        "lesson_label": "HN4-001",
        "lesson_title": "이름을 쓰세요",
        "target_kind": "question",
        "target_order": "3",
        "lesson_id": "11111111-1111-1111-1111-111111111111",
        "target_type": "lesson_question_prompt",
        "field": "question_prompt",
        "target_id": target_id,
        "provider_model": "elevenlabs / eleven_multilingual_v2",
        "source_text": "名前を書き___. (이름을 쓰세요.)",
        "korean_context": "",
        "stt_transcript": "名前を書き イムルスセヨ",
        "review_signals": "HIGH_SILENCE_RATIO:0.3863",
        "current_audio_url": "https://storage.googleapis.com/harukoto-storage/tts/lesson/111/question-3.mp3",
        "current_verdict": current_verdict,
        "current_notes": "",
        "recommended_action": "provider fallback regenerate high-silence question prompt",
        "regeneration_status": "",
        "new_audio_url": "",
        "post_regen_verdict": "",
        "post_regen_notes": "",
    }


def _record(*, audio_url: str) -> CurrentTtsRecord:
    return CurrentTtsRecord(
        target_type="lesson_question_prompt",
        target_id="11111111-1111-1111-1111-111111111111:question:3",
        field="question_prompt",
        text="名前を書き___. (이름을 쓰세요.)",
        provider="gemini",
        model="gemini-2.5-flash-preview-tts",
        audio_url=audio_url,
    )


def _write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    import csv

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
