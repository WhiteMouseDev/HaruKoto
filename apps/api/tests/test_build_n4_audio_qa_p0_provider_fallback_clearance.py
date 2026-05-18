from scripts.build_n4_audio_qa_p0_provider_fallback_clearance import build_clearance_rows


def test_build_clearance_passes_regenerated_mixed_prompt_stt_only_row() -> None:
    report = build_clearance_rows(
        [_row(new_notes="TRANSCRIPTION_TEXT_MISMATCH:線の太さを見ます。")],
        provider_models={"HN4-006 question:4": "gemini / gemini-2.5-flash-preview-tts"},
    )

    assert report.pass_count == 1
    assert report.held_count == 0
    assert report.rows[0].values["new_verdict"] == "PASS"
    assert report.rows[0].values["provider_model"] == "gemini / gemini-2.5-flash-preview-tts"
    assert report.rows[0].values["review_signals"] == "PROVIDER_FALLBACK_REGENERATED, POST_REGEN_STT_MISMATCH_ONLY"
    assert "mixed Japanese/Korean/cloze prompt" in report.rows[0].values["new_notes"]


def test_build_clearance_holds_regenerated_row_with_silence_warning() -> None:
    report = build_clearance_rows([_row(new_notes=("HIGH_SILENCE_RATIO:0.3725, TRANSCRIPTION_TEXT_MISMATCH:間に合わない"))])

    assert report.pass_count == 0
    assert report.held_count == 1
    assert report.rows[0].values["new_verdict"] == "PENDING"
    assert (
        report.rows[0].values["review_signals"]
        == "PROVIDER_FALLBACK_REGENERATED, POST_REGEN_HIGH_SILENCE_RATIO_REMAINS, POST_REGEN_TRANSCRIPTION_TEXT_MISMATCH"
    )
    assert "HIGH_SILENCE_RATIO remains" in report.rows[0].values["new_notes"]


def _row(*, new_notes: str) -> dict[str, str]:
    return {
        "target_key": "HN4-006 question:4",
        "packet": "docs/operations/plans/n4-pilot-human-audio-qa-ch02-2026-05-13.md",
        "priority": "P0_MACHINE_WARNING_PROVIDER_FALLBACK_POST_REGEN_REVIEW",
        "review_signals": "PROVIDER_FALLBACK_REGENERATED",
        "japanese_text": "線の太___を見ます。 (선의 굵기를 봅니다.)",
        "korean_context": "",
        "provider_model": "",
        "audio_url": "https://storage.googleapis.com/harukoto-storage/tts/lesson/lesson/question-4-regen-RUN.mp3",
        "current_verdict": "PENDING",
        "current_notes": "",
        "new_verdict": "FLAG",
        "new_notes": new_notes,
    }
