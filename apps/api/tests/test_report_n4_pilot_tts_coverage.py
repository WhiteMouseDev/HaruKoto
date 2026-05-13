from scripts.report_n4_pilot_tts_coverage import (
    AudioUrlCheckSummary,
    LessonTtsCoverage,
    _build_signals,
    _question_orders,
    _script_line_indices,
)


def test_content_target_helpers_use_runtime_target_shape() -> None:
    content = {
        "reading": {"script": [{"text": "一行目"}, "invalid", {"text": "二行目"}]},
        "questions": [{"order": 3, "prompt": "問題三"}, {"prompt": "fallback"}, "invalid"],
    }

    assert _script_line_indices(content) == [0, 2]
    assert _question_orders(content) == [3, 2]


def test_build_signals_blocks_when_batch_records_are_missing() -> None:
    signals, blockers = _build_signals(
        lessons=[
            LessonTtsCoverage(
                lesson_no=1,
                label="HN4-001",
                lesson_id="lesson-1",
                title="title",
                is_published=True,
                expected_script_line_records=4,
                generated_script_line_records=3,
                missing_script_line_indices=[2],
                expected_question_prompt_records=5,
                generated_question_prompt_records=0,
                missing_question_prompt_orders=[1, 2, 3, 4, 5],
            )
        ],
        audio_url_check=None,
    )

    assert any("SCRIPT_LINE_TTS_RECORDS_MISSING" in blocker for blocker in blockers)
    assert any("QUESTION_PROMPT_TTS_RECORDS_MISSING" in blocker for blocker in blockers)
    assert any("LESSONS_WITH_TTS_GAPS: HN4-001" in blocker for blocker in blockers)
    assert any("AUDIO_URL_CHECK_SKIPPED" in signal for signal in signals)


def test_build_signals_marks_full_batch_and_audio_urls_ready() -> None:
    signals, blockers = _build_signals(
        lessons=[
            LessonTtsCoverage(
                lesson_no=1,
                label="HN4-001",
                lesson_id="lesson-1",
                title="title",
                is_published=True,
                expected_script_line_records=4,
                generated_script_line_records=4,
                missing_script_line_indices=[],
                expected_question_prompt_records=5,
                generated_question_prompt_records=5,
                missing_question_prompt_orders=[],
            )
        ],
        audio_url_check=AudioUrlCheckSummary(
            checked_records=9,
            ok_records=9,
            failed_records=0,
            failures=[],
        ),
    )

    assert any("SCRIPT_LINE_TTS_RECORDS_READY" in signal for signal in signals)
    assert any("QUESTION_PROMPT_TTS_RECORDS_READY" in signal for signal in signals)
    assert any("PILOT_BATCH_TTS_RECORDS_READY" in signal for signal in signals)
    assert any("AUDIO_URLS_READY" in signal for signal in signals)
    assert blockers == []
