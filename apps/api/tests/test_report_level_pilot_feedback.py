from scripts.report_lesson_pilot_feedback import (
    LessonSnapshot,
    LessonTarget,
    PilotFeedbackReport,
    ProgressSnapshot,
    ReviewEventSnapshot,
    TtsSnapshot,
)
from scripts.report_level_pilot_feedback import aggregate_blockers, build_level_signals, summarize_reports


def _report(label: str, *, progress_users: int, review_events: int, blockers: list[str] | None = None) -> PilotFeedbackReport:
    return PilotFeedbackReport(
        generated_at="2026-06-01T00:00:00+00:00",
        since="2026-05-18T00:00:00+00:00",
        target=LessonTarget(jlpt_level="N4", lesson_no=int(label[-3:]), label=label),
        lesson=LessonSnapshot(
            lesson_id=f"lesson-{label}",
            title=f"Lesson {label}",
            topic="topic",
            is_published=True,
            script_line_count=4,
            question_count=5,
        ),
        progress=ProgressSnapshot(
            total_users=progress_users,
            completed_users=progress_users,
            in_progress_users=0,
            not_started_users=0,
            perfect_scores=progress_users,
            non_perfect_scores=0,
            total_attempts=progress_users,
            max_attempts=1 if progress_users else 0,
            average_score_percent=100.0 if progress_users else None,
            first_started_at=None,
            last_completed_at=None,
            last_updated_at=None,
        ),
        review_events=ReviewEventSnapshot(
            total_events=review_events,
            correct_events=review_events,
            incorrect_events=0,
            average_response_ms=None,
            first_event_at=None,
            last_event_at=None,
            item_type_counts={},
        ),
        tts=TtsSnapshot(
            expected_script_line_records=4,
            generated_script_line_records=4,
            missing_script_line_indices=[],
            provider_model_counts={"elevenlabs/eleven_multilingual_v2": 9},
            expected_question_prompt_targets=5,
            generated_question_prompt_records=5,
            missing_question_prompt_orders=[],
        ),
        signals=[],
        blockers=blockers or [],
    )


def test_summarize_reports_counts_progress_waiting_and_blockers() -> None:
    reports = [
        _report("HN4-001", progress_users=1, review_events=5),
        _report("HN4-002", progress_users=0, review_events=0, blockers=["SCRIPT_LINE_TTS_MISSING"]),
    ]

    summary = summarize_reports(reports)

    assert summary.lesson_count == 2
    assert summary.lessons_with_progress == 1
    assert summary.waiting_lessons == 1
    assert summary.completed_users == 1
    assert summary.review_events == 5
    assert summary.tts_ready_lessons == 2
    assert summary.blocker_count == 1


def test_aggregate_blockers_prefixes_lesson_labels() -> None:
    blockers = aggregate_blockers([_report("HN4-002", progress_users=0, review_events=0, blockers=["QUESTION_PROMPT_TTS_PENDING"])])

    assert blockers == ["HN4-002: QUESTION_PROMPT_TTS_PENDING"]


def test_aggregate_blockers_marks_empty_published_slice() -> None:
    blockers = aggregate_blockers([])

    assert blockers == ["NO_PUBLISHED_LESSONS: no published lessons were found for the selected level"]


def test_build_level_signals_marks_clear_aggregate_monitor() -> None:
    summary = summarize_reports([_report("HN4-001", progress_users=1, review_events=5)])

    signals = build_level_signals(summary)

    assert "PUBLISHED_LESSONS: 1" in signals
    assert "NO_AUTOMATIC_ROLLBACK_TRIGGER: no aggregate monitor blocker found" in signals
