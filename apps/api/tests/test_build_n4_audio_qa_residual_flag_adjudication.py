import csv
from pathlib import Path

import pytest

from scripts.build_n4_audio_qa_residual_flag_adjudication import (
    build_adjudication_report,
    render_html,
    render_markdown,
    write_adjudication_csv,
)


def test_build_adjudication_report_selects_only_second_pass_flags(tmp_path: Path) -> None:
    inputs = _write_inputs(tmp_path)

    report = build_adjudication_report(**inputs)

    assert report.total_second_pass_rows == 2
    assert report.residual_pass_count == 1
    assert report.residual_flag_count == 1
    assert report.rewrite_candidate_count == 1
    assert [item.target_key for item in report.items] == ["HN4-001 script:3"]

    item = report.items[0]
    assert item.current_verdict == "FLAG"
    assert item.review_signals == "TRANSCRIPTION_TEXT_MISMATCH:わかりました。艇中に確認します。"
    assert item.original_audio_url == "https://example.com/original-001.mp3"
    assert item.original_stt_transcript == "わかりました。定時に確認します。"
    assert item.first_pass_audio_url == "https://example.com/first-001.mp3"
    assert item.first_pass_stt_transcript == "分かりました。店主に確認します。"
    assert item.second_pass_audio_url == "https://example.com/second-001.mp3"
    assert item.second_pass_stt_transcript == "わかりました。艇中に確認します。"
    assert "before a third regeneration" in item.recommended_next_step


def test_write_adjudication_csv_keeps_apply_columns_blank(tmp_path: Path) -> None:
    report = build_adjudication_report(**_write_inputs(tmp_path / "inputs"))
    output = tmp_path / "adjudication.csv"

    count = write_adjudication_csv(output, report)

    rows = list(csv.DictReader(output.read_text(encoding="utf-8").splitlines()))
    assert count == 1
    assert "\r\n" not in output.read_text(encoding="utf-8")
    assert rows[0]["target_key"] == "HN4-001 script:3"
    assert rows[0]["audio_url"] == "https://example.com/second-001.mp3"
    assert rows[0]["adjudication_decision"] == ""
    assert rows[0]["best_audio_version"] == ""
    assert rows[0]["rewrite_notes"] == ""
    assert rows[0]["new_verdict"] == ""
    assert rows[0]["new_notes"] == ""


def test_render_outputs_compare_three_audio_versions_and_exclude_pass_rows(tmp_path: Path) -> None:
    inputs = _write_inputs(tmp_path)
    report = build_adjudication_report(**inputs)

    markdown = render_markdown(report, **inputs)
    html = render_html(report)

    assert "> Status: REVIEW SHEET - no packet verdicts applied" in markdown
    assert "| Residual FLAG rows selected | 1 |" in markdown
    assert "HN4-001 script:3" in markdown
    assert "HN4-003 script:1" not in markdown
    assert "https://example.com/second-001.mp3" in markdown

    assert "<title>N4 Residual FLAG Audio QA Adjudication</title>" in html
    assert html.count("<audio controls") == 3
    assert "https://example.com/original-001.mp3" in html
    assert "https://example.com/first-001.mp3" in html
    assert "https://example.com/second-001.mp3" in html
    assert "https://example.com/second-pass-row.mp3" not in html


def test_build_adjudication_report_rejects_audio_url_drift(tmp_path: Path) -> None:
    inputs = _write_inputs(tmp_path, second_recommendation_audio_url="https://example.com/drifted.mp3")

    with pytest.raises(ValueError, match="second recommendation audio URL drift"):
        build_adjudication_report(**inputs)


def _write_inputs(tmp_path: Path, *, second_recommendation_audio_url: str = "https://example.com/second-001.mp3") -> dict[str, Path]:
    tmp_path.mkdir(parents=True, exist_ok=True)
    flag_manifest_csv = _write_csv(
        tmp_path / "manifest.csv",
        [
            {
                "target_key": "HN4-001 script:3",
                "packet": "docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md",
                "source_text": "分かりました。丁寧に確認します。",
                "korean_context": "알겠습니다. 꼼꼼히 확인하겠습니다.",
                "stt_transcript": "わかりました。定時に確認します。",
                "review_signals": "TRANSCRIPTION_TEXT_MISMATCH:わかりました。定時に確認します。",
                "current_audio_url": "https://example.com/original-001.mp3",
                "current_verdict": "FLAG",
                "current_notes": "original flag",
            }
        ],
    )
    first_regeneration_results_csv = _write_csv(
        tmp_path / "first-results.csv",
        [
            {
                "target_key": "HN4-001 script:3",
                "target_id": "lesson-001:script:3",
                "source_text": "分かりました。丁寧に確認します。",
                "status": "regenerated",
                "old_audio_url": "https://example.com/original-001.mp3",
                "new_audio_url": "https://example.com/first-001.mp3",
                "provider": "elevenlabs",
                "model": "eleven_multilingual_v2",
            }
        ],
    )
    first_recommendations_csv = _write_csv(
        tmp_path / "first-recommendations.csv",
        [
            {
                "target_key": "HN4-001 script:3",
                "packet": "docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md",
                "review_signals": "TRANSCRIPTION_TEXT_MISMATCH:わかりました。定時に確認します。",
                "japanese_text": "分かりました。丁寧に確認します。",
                "korean_context": "알겠습니다. 꼼꼼히 확인하겠습니다.",
                "audio_url": "https://example.com/first-001.mp3",
                "current_verdict": "FLAG",
                "current_notes": "original flag",
                "new_verdict": "FLAG",
                "new_notes": "Delegated FLAG: TRANSCRIPTION_TEXT_MISMATCH:分かりました。店主に確認します。; direct-listen.",
            }
        ],
    )
    second_regeneration_results_csv = _write_csv(
        tmp_path / "second-results.csv",
        [
            {
                "target_key": "HN4-001 script:3",
                "target_id": "lesson-001:script:3",
                "source_text": "分かりました。丁寧に確認します。",
                "status": "regenerated",
                "old_audio_url": "https://example.com/first-001.mp3",
                "new_audio_url": "https://example.com/second-001.mp3",
                "provider": "elevenlabs",
                "model": "eleven_multilingual_v2",
            }
        ],
    )
    second_recommendations_csv = _write_csv(
        tmp_path / "second-recommendations.csv",
        [
            {
                "target_key": "HN4-001 script:3",
                "packet": "docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md",
                "review_signals": "TRANSCRIPTION_TEXT_MISMATCH:分かりました。店主に確認します。",
                "japanese_text": "分かりました。丁寧に確認します。",
                "korean_context": "알겠습니다. 꼼꼼히 확인하겠습니다.",
                "audio_url": second_recommendation_audio_url,
                "current_verdict": "FLAG",
                "current_notes": "first pass flag",
                "new_verdict": "FLAG",
                "new_notes": "Delegated FLAG: TRANSCRIPTION_TEXT_MISMATCH:わかりました。艇中に確認します。; direct-listen.",
            },
            {
                "target_key": "HN4-003 script:1",
                "packet": "docs/operations/plans/n4-pilot-human-audio-qa-ch01-2026-05-13.md",
                "review_signals": "TRANSCRIPTION_TEXT_MISMATCH:じゃ、会議に間に合わないかもしれませんね。",
                "japanese_text": "じゃあ、会議に間に合わないかもしれませんね。",
                "korean_context": "그럼 회의에 맞추지 못할지도 모르겠네요.",
                "audio_url": "https://example.com/second-pass-row.mp3",
                "current_verdict": "FLAG",
                "current_notes": "first pass flag",
                "new_verdict": "PASS",
                "new_notes": "Delegated PASS.",
            },
        ],
    )
    return {
        "flag_manifest_csv": flag_manifest_csv,
        "first_regeneration_results_csv": first_regeneration_results_csv,
        "first_recommendations_csv": first_recommendations_csv,
        "second_regeneration_results_csv": second_regeneration_results_csv,
        "second_recommendations_csv": second_recommendations_csv,
    }


def _write_csv(path: Path, rows: list[dict[str, str]]) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return path
