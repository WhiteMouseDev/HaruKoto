from types import SimpleNamespace

from scripts.audit_n4_pilot_tts_audio_quality import (
    AudioProbe,
    TtsSourceTarget,
    TtsStoredRecord,
    _build_report,
    build_transcription_probe,
    evaluate_audio_quality,
    render_markdown_report,
    source_targets_from_lesson,
)


def _target(source_text: str = "名前を書きなさい。") -> TtsSourceTarget:
    return TtsSourceTarget(
        lesson_no=1,
        label="HN4-001",
        lesson_id="lesson-1",
        title="이름을 쓰세요",
        kind="script",
        order=0,
        target_type="lesson_script_line",
        target_id="lesson-1:script:0",
        field="script_line",
        source_text=source_text,
    )


def _record(text: str = "名前を書きなさい。") -> TtsStoredRecord:
    return TtsStoredRecord(
        target_id="lesson-1:script:0",
        text=text,
        provider="elevenlabs",
        model="eleven_multilingual_v2",
        audio_url="https://cdn.example.com/audio.mp3",
    )


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


def test_source_targets_from_lesson_uses_runtime_tts_target_shape() -> None:
    lesson = SimpleNamespace(
        id="lesson-1",
        lesson_no=1,
        title="이름을 쓰세요",
        content_jsonb={
            "reading": {
                "script": [
                    {"text": "名前を書きなさい。"},
                    "invalid",
                    {"text": "規則を確認しなさい。"},
                ]
            },
            "questions": [
                {"order": "3", "prompt": "規則の意味は?"},
                {"prompt": "fallback order"},
                "invalid",
            ],
        },
    )

    targets = source_targets_from_lesson(level="N4", lesson=lesson)  # type: ignore[arg-type]

    assert [(target.kind, target.order, target.target_type, target.target_id, target.field) for target in targets] == [
        ("script", 0, "lesson_script_line", "lesson-1:script:0", "script_line"),
        ("script", 2, "lesson_script_line", "lesson-1:script:2", "script_line"),
        ("question", 3, "lesson_question_prompt", "lesson-1:question:3", "question_prompt"),
        ("question", 2, "lesson_question_prompt", "lesson-1:question:2", "question_prompt"),
    ]


def test_evaluate_audio_quality_passes_clean_mp3_probe() -> None:
    result = evaluate_audio_quality(target=_target(), record=_record(), probe=_probe())

    assert result.status == "PASS"
    assert result.blockers == []
    assert result.warnings == []
    assert result.provider == "elevenlabs"
    assert result.model == "eleven_multilingual_v2"


def test_evaluate_audio_quality_blocks_text_mismatch_and_bad_probe() -> None:
    result = evaluate_audio_quality(
        target=_target(),
        record=_record(text="違う文です。"),
        probe=_probe(
            content_type="text/plain",
            byte_size=16,
            codec_name="wav",
            duration_seconds=0.2,
        ),
    )

    assert result.status == "BLOCK"
    assert result.blockers == [
        "TEXT_MISMATCH",
        "INVALID_CONTENT_TYPE:text/plain",
        "AUDIO_TOO_SMALL:16",
        "UNEXPECTED_CODEC:wav",
        "AUDIO_TOO_SHORT:0.2",
    ]


def test_evaluate_audio_quality_warns_on_transcription_mismatch_by_default() -> None:
    target = _target()
    transcription = build_transcription_probe(target=target, transcript="違う文です。")

    result = evaluate_audio_quality(target=target, record=_record(), probe=_probe(), transcription=transcription)

    assert result.status == "PASS"
    assert result.blockers == []
    assert result.warnings == ["TRANSCRIPTION_TEXT_MISMATCH:違う文です。"]
    assert result.transcription == transcription


def test_evaluate_audio_quality_can_block_transcription_mismatch() -> None:
    target = _target()
    transcription = build_transcription_probe(target=target, transcript="違う文です。")

    result = evaluate_audio_quality(
        target=target,
        record=_record(),
        probe=_probe(),
        transcription=transcription,
        block_on_transcription_mismatch=True,
    )

    assert result.status == "BLOCK"
    assert result.blockers == ["TRANSCRIPTION_TEXT_MISMATCH:違う文です。"]
    assert result.warnings == []


def test_evaluate_audio_quality_blocks_empty_transcription() -> None:
    target = _target()
    transcription = build_transcription_probe(target=target, transcript=" ")

    result = evaluate_audio_quality(target=target, record=_record(), probe=_probe(), transcription=transcription)

    assert result.status == "BLOCK"
    assert result.blockers == ["TRANSCRIPTION_EMPTY"]


def test_build_report_summarizes_blockers_warnings_and_durations() -> None:
    target = _target(source_text="これは少し長い音声チェック文です。")
    transcription = build_transcription_probe(target=target, transcript="これは少し長い音声チェック文です。")
    result = evaluate_audio_quality(
        target=target,
        record=_record(text="これは少し長い音声チェック文です。"),
        probe=_probe(duration_seconds=5.0, silence_seconds=2.0, silence_ratio=0.4),
        transcription=transcription,
    )

    report = _build_report(level="N4", results=[result])

    assert report.target_count == 1
    assert report.pass_count == 1
    assert report.blocked_count == 0
    assert report.warning_count == 1
    assert report.transcribed_count == 1
    assert report.transcription_match_count == 1
    assert report.transcription_mismatch_count == 0
    assert report.transcription_error_count == 0
    assert report.duration_min_seconds == 5.0
    assert report.duration_max_seconds == 5.0
    assert report.duration_average_seconds == 5.0
    assert report.provider_model_counts == {"elevenlabs/eleven_multilingual_v2": 1}
    assert report.warnings == ["HN4-001 script:0: HIGH_SILENCE_RATIO:0.4"]


def test_render_markdown_report_includes_transcription_mismatch_triage() -> None:
    target = _target(source_text="名前を書きなさい。")
    transcription = build_transcription_probe(target=target, transcript="名前を聞きなさい。")
    result = evaluate_audio_quality(target=target, record=_record(), probe=_probe(), transcription=transcription)
    report = _build_report(level="N4", results=[result])

    markdown = render_markdown_report(report=report, command="uv run python script.py --transcribe")

    assert "> Status: REVIEW" in markdown
    assert "| STT mismatches | 1 |" in markdown
    assert "TRANSCRIPTION_TEXT_MISMATCH:名前を聞きなさい。" in markdown
    assert "| HN4-001 script:0 | 名前を書きなさい。 | 名前を聞きなさい。 | no | https://cdn.example.com/audio.mp3 |" in markdown
    assert "REVIEW: inspect STT mismatches before recording final audio verdicts." in markdown


def test_render_markdown_report_marks_strict_transcription_blocker() -> None:
    target = _target(source_text="名前を書きなさい。")
    transcription = build_transcription_probe(target=target, transcript="名前を聞きなさい。")
    result = evaluate_audio_quality(
        target=target,
        record=_record(),
        probe=_probe(),
        transcription=transcription,
        block_on_transcription_mismatch=True,
    )
    report = _build_report(level="N4", results=[result])

    markdown = render_markdown_report(report=report, strict_mode=True)

    assert "> Status: BLOCK" in markdown
    assert "| HN4-001 script:0 | 名前を書きなさい。 | 名前を聞きなさい。 | yes | https://cdn.example.com/audio.mp3 |" in markdown
    assert "Strict STT mismatch blocker mode was enabled for this run." in markdown


def test_render_markdown_report_uses_na_for_missing_duration_metrics() -> None:
    report = _build_report(level="N4", results=[])

    markdown = render_markdown_report(report=report)

    assert "| Duration min | n/a |" in markdown
    assert "| Duration max | n/a |" in markdown
    assert "| Duration average | n/a |" in markdown
