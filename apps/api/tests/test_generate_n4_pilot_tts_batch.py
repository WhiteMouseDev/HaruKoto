from scripts.generate_n4_pilot_tts_batch import GenerationTask, collect_missing_tasks
from scripts.report_n4_pilot_tts_coverage import LessonTtsCoverage, PilotBatchTtsCoverageReport


def test_generation_task_target_id_matches_service_shape() -> None:
    assert (
        GenerationTask(
            lesson_no=1,
            label="HN4-001",
            lesson_id="lesson-id",
            kind="script",
            order=2,
        ).target_id
        == "lesson-id:script:2"
    )
    assert (
        GenerationTask(
            lesson_no=1,
            label="HN4-001",
            lesson_id="lesson-id",
            kind="question",
            order=5,
        ).target_id
        == "lesson-id:question:5"
    )


def test_collect_missing_tasks_orders_filters_and_limits_targets() -> None:
    report = PilotBatchTtsCoverageReport(
        generated_at="2026-05-13T00:00:00+00:00",
        level="N4",
        lesson_count=2,
        expected_script_line_records=8,
        generated_script_line_records=5,
        expected_question_prompt_records=10,
        generated_question_prompt_records=7,
        expected_total_records=18,
        generated_total_records=12,
        provider_model_counts={},
        lessons=[
            LessonTtsCoverage(
                lesson_no=2,
                label="HN4-002",
                lesson_id="lesson-2",
                title="title 2",
                is_published=True,
                expected_script_line_records=4,
                generated_script_line_records=3,
                missing_script_line_indices=[3],
                expected_question_prompt_records=5,
                generated_question_prompt_records=4,
                missing_question_prompt_orders=[5],
            ),
            LessonTtsCoverage(
                lesson_no=1,
                label="HN4-001",
                lesson_id="lesson-1",
                title="title 1",
                is_published=True,
                expected_script_line_records=4,
                generated_script_line_records=2,
                missing_script_line_indices=[1, 2],
                expected_question_prompt_records=5,
                generated_question_prompt_records=3,
                missing_question_prompt_orders=[2, 4],
            ),
        ],
        audio_url_check=None,
        signals=[],
        blockers=[],
    )

    tasks = collect_missing_tasks(report, lesson_numbers={1}, target_kind="all", limit=3)

    assert [(task.label, task.kind, task.order) for task in tasks] == [
        ("HN4-001", "script", 1),
        ("HN4-001", "script", 2),
        ("HN4-001", "question", 2),
    ]


def test_collect_missing_tasks_can_select_question_targets_only() -> None:
    report = PilotBatchTtsCoverageReport(
        generated_at="2026-05-13T00:00:00+00:00",
        level="N4",
        lesson_count=1,
        expected_script_line_records=4,
        generated_script_line_records=3,
        expected_question_prompt_records=5,
        generated_question_prompt_records=3,
        expected_total_records=9,
        generated_total_records=6,
        provider_model_counts={},
        lessons=[
            LessonTtsCoverage(
                lesson_no=1,
                label="HN4-001",
                lesson_id="lesson-1",
                title="title",
                is_published=True,
                expected_script_line_records=4,
                generated_script_line_records=3,
                missing_script_line_indices=[1],
                expected_question_prompt_records=5,
                generated_question_prompt_records=3,
                missing_question_prompt_orders=[2, 4],
            )
        ],
        audio_url_check=None,
        signals=[],
        blockers=[],
    )

    tasks = collect_missing_tasks(report, lesson_numbers=None, target_kind="question", limit=None)

    assert [(task.kind, task.order) for task in tasks] == [("question", 2), ("question", 4)]
