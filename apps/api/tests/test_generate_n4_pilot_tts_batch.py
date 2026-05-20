import pytest

from scripts.generate_n4_pilot_tts_batch import GenerationResult, GenerationTask, collect_missing_tasks, run_generation
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


@pytest.mark.asyncio
async def test_run_generation_can_include_unpublished_lessons(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, bool] = {}

    async def fake_build_report(
        *,
        level: str,
        include_unpublished: bool,
        check_audio_urls: bool,
        timeout_seconds: float,
    ) -> PilotBatchTtsCoverageReport:
        captured["include_unpublished"] = include_unpublished
        return PilotBatchTtsCoverageReport(
            generated_at="2026-05-20T00:00:00+00:00",
            level=level,
            lesson_count=0,
            expected_script_line_records=0,
            generated_script_line_records=0,
            expected_question_prompt_records=0,
            generated_question_prompt_records=0,
            expected_total_records=0,
            generated_total_records=0,
            provider_model_counts={},
            lessons=[],
            audio_url_check=None,
            signals=[],
            blockers=[],
        )

    monkeypatch.setattr("scripts.generate_n4_pilot_tts_batch.build_report", fake_build_report)

    results = await run_generation(
        level="N4",
        include_unpublished=True,
        lesson_numbers=None,
        target_kind="all",
        limit=None,
        execute=False,
        continue_on_error=False,
        sleep_seconds=0,
    )

    assert results == []
    assert captured == {"include_unpublished": True}


@pytest.mark.asyncio
async def test_run_generation_passes_unpublished_access_to_executor(monkeypatch: pytest.MonkeyPatch) -> None:
    async def fake_build_report(
        *,
        level: str,
        include_unpublished: bool,
        check_audio_urls: bool,
        timeout_seconds: float,
    ) -> PilotBatchTtsCoverageReport:
        return PilotBatchTtsCoverageReport(
            generated_at="2026-05-20T00:00:00+00:00",
            level=level,
            lesson_count=1,
            expected_script_line_records=1,
            generated_script_line_records=0,
            expected_question_prompt_records=0,
            generated_question_prompt_records=0,
            expected_total_records=1,
            generated_total_records=0,
            provider_model_counts={},
            lessons=[
                LessonTtsCoverage(
                    lesson_no=12,
                    label="HN4-012",
                    lesson_id="lesson-12",
                    title="title",
                    is_published=False,
                    expected_script_line_records=1,
                    generated_script_line_records=0,
                    missing_script_line_indices=[0],
                    expected_question_prompt_records=0,
                    generated_question_prompt_records=0,
                    missing_question_prompt_orders=[],
                )
            ],
            audio_url_check=None,
            signals=[],
            blockers=[],
        )

    captured: dict[str, bool] = {}

    async def fake_execute_task(task: GenerationTask, *, allow_unpublished: bool = False) -> GenerationResult:
        captured["allow_unpublished"] = allow_unpublished
        return GenerationResult(task=task, status="generated", audio_url="https://cdn.example.com/audio.mp3")

    monkeypatch.setattr("scripts.generate_n4_pilot_tts_batch.build_report", fake_build_report)
    monkeypatch.setattr("scripts.generate_n4_pilot_tts_batch.execute_task", fake_execute_task)

    results = await run_generation(
        level="N4",
        include_unpublished=True,
        lesson_numbers={12},
        target_kind="all",
        limit=None,
        execute=True,
        continue_on_error=False,
        sleep_seconds=0,
    )

    assert [result.status for result in results] == ["generated"]
    assert captured == {"allow_unpublished": True}
