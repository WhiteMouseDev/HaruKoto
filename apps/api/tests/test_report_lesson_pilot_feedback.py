from scripts.report_lesson_pilot_feedback import (
    ProgressSnapshot,
    ReviewEventSnapshot,
    TtsSnapshot,
    _build_signals,
)


def test_build_signals_marks_waiting_state_without_pilot_traffic() -> None:
    signals, blockers = _build_signals(
        ProgressSnapshot(
            total_users=0,
            completed_users=0,
            in_progress_users=0,
            not_started_users=0,
            perfect_scores=0,
            non_perfect_scores=0,
            total_attempts=0,
            max_attempts=0,
            average_score_percent=None,
            first_started_at=None,
            last_completed_at=None,
            last_updated_at=None,
        ),
        ReviewEventSnapshot(
            total_events=0,
            correct_events=0,
            incorrect_events=0,
            average_response_ms=None,
            first_event_at=None,
            last_event_at=None,
            item_type_counts={},
        ),
        TtsSnapshot(
            expected_script_line_records=4,
            generated_script_line_records=2,
            missing_script_line_indices=[2, 3],
            provider_model_counts={"elevenlabs/eleven_multilingual_v2": 2},
            expected_question_prompt_targets=5,
            generated_question_prompt_records=0,
            missing_question_prompt_orders=[1, 2, 3, 4, 5],
        ),
    )

    assert "WAITING_FOR_PILOT_TRAFFIC" in signals[0]
    assert "NO_REVIEW_EVENTS" in signals[1]
    assert any("SCRIPT_LINE_TTS_MISSING" in blocker for blocker in blockers)
    assert any("QUESTION_PROMPT_TTS_PENDING" in blocker for blocker in blockers)


def test_build_signals_marks_question_prompt_tts_ready_when_complete() -> None:
    signals, blockers = _build_signals(
        ProgressSnapshot(
            total_users=1,
            completed_users=1,
            in_progress_users=0,
            not_started_users=0,
            perfect_scores=1,
            non_perfect_scores=0,
            total_attempts=2,
            max_attempts=2,
            average_score_percent=100.0,
            first_started_at="2026-05-13T00:00:00+00:00",
            last_completed_at="2026-05-13T00:05:00+00:00",
            last_updated_at="2026-05-13T00:05:00+00:00",
        ),
        ReviewEventSnapshot(
            total_events=5,
            correct_events=5,
            incorrect_events=0,
            average_response_ms=900,
            first_event_at="2026-05-13T00:01:00+00:00",
            last_event_at="2026-05-13T00:05:00+00:00",
            item_type_counts={"WORD": 5},
        ),
        TtsSnapshot(
            expected_script_line_records=4,
            generated_script_line_records=4,
            missing_script_line_indices=[],
            provider_model_counts={"elevenlabs/eleven_multilingual_v2": 4},
            expected_question_prompt_targets=5,
            generated_question_prompt_records=5,
            missing_question_prompt_orders=[],
        ),
    )

    assert any("PILOT_PROGRESS_OBSERVED" in signal for signal in signals)
    assert any("REVIEW_EVENTS_OBSERVED" in signal for signal in signals)
    assert any("SCRIPT_LINE_TTS_READY" in signal for signal in signals)
    assert any("QUESTION_PROMPT_TTS_READY" in signal for signal in signals)
    assert blockers == []
