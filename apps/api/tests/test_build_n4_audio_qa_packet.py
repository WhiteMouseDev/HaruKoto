from scripts.build_n4_audio_qa_packet import (
    AudioQaTarget,
    LessonSource,
    attach_audio_records,
    build_targets_for_lesson,
    render_packet_markdown,
)


def test_build_targets_for_lesson_uses_lesson_scoped_tts_shape() -> None:
    lesson = LessonSource(
        level="N4",
        lesson_id="lesson-1",
        lesson_no=1,
        chapter_no=1,
        chapter_title="chapter",
        title="title",
        topic="topic",
        content={
            "reading": {
                "script": [
                    {"speaker": "先生", "text": "名前を書きなさい。", "translation": "이름을 쓰세요."},
                    "invalid",
                ]
            },
            "questions": [
                {"order": 3, "prompt": "規則の意味は?"},
                {"prompt": "fallback order"},
            ],
        },
    )

    targets = build_targets_for_lesson(lesson)

    assert [(target.kind, target.order, target.target_type, target.target_id, target.field) for target in targets] == [
        ("script", 0, "lesson_script_line", "lesson-1:script:0", "script_line"),
        ("question", 3, "lesson_question_prompt", "lesson-1:question:3", "question_prompt"),
        ("question", 2, "lesson_question_prompt", "lesson-1:question:2", "question_prompt"),
    ]
    assert targets[0].speaker == "先生"
    assert targets[0].translation == "이름을 쓰세요."


def test_attach_audio_records_only_fills_exact_target_field_matches() -> None:
    targets = [
        AudioQaTarget(
            lesson_label="HN4-001",
            lesson_title="title",
            chapter_no=1,
            chapter_title="chapter",
            kind="script",
            order=0,
            target_type="lesson_script_line",
            target_id="lesson-1:script:0",
            field="script_line",
            text="名前を書きなさい。",
        )
    ]

    attached = attach_audio_records(
        targets,
        {
            ("lesson_script_line", "lesson-1:script:0", "word"): (
                "bad",
                "bad",
                "https://cdn.example.com/bad.mp3",
            ),
            ("lesson_script_line", "lesson-1:script:0", "script_line"): (
                "elevenlabs",
                "eleven_multilingual_v2",
                "https://cdn.example.com/good.mp3",
            ),
        },
    )

    assert attached[0].provider == "elevenlabs"
    assert attached[0].model == "eleven_multilingual_v2"
    assert attached[0].audio_url == "https://cdn.example.com/good.mp3"


def test_render_packet_markdown_keeps_human_verdict_pending() -> None:
    markdown = render_packet_markdown(
        generated_at="2026-05-13T00:00:00+00:00",
        level="N4",
        chapter_no=1,
        targets=[
            AudioQaTarget(
                lesson_label="HN4-001",
                lesson_title="이름을 쓰세요",
                chapter_no=1,
                chapter_title="지시와 판단 표현",
                kind="script",
                order=0,
                target_type="lesson_script_line",
                target_id="lesson-1:script:0",
                field="script_line",
                text="名前を書きなさい。",
                speaker="先生",
                translation="이름을 쓰세요.",
                provider="elevenlabs",
                model="eleven_multilingual_v2",
                audio_url="https://cdn.example.com/audio.mp3",
                url_status="ok",
            )
        ],
    )

    assert "Status: REVIEW PACKET - human verdict pending" in markdown
    assert "| Script-line targets | 1 |" in markdown
    assert "[audio](https://cdn.example.com/audio.mp3)" in markdown
    assert "PENDING" in markdown


def test_render_packet_markdown_can_label_pilot_draft_scope() -> None:
    markdown = render_packet_markdown(
        generated_at="2026-05-20T00:00:00+00:00",
        level="N4",
        chapter_no=4,
        scope_label="Pilot/Draft",
        targets=[],
    )

    assert "# N4 Pilot/Draft Human Audio QA Packet - Chapter 4" in markdown


def test_lesson_source_label_uses_configured_level() -> None:
    lesson = LessonSource(
        level="N5",
        lesson_id="lesson-1",
        lesson_no=7,
        chapter_no=2,
        chapter_title="chapter",
        title="title",
        topic="topic",
        content={},
    )

    assert lesson.label == "HN5-007"


def test_render_packet_markdown_uses_level_specific_rollout_boundary() -> None:
    markdown = render_packet_markdown(
        generated_at="2026-05-26T00:00:00+00:00",
        level="N5",
        chapter_no=1,
        targets=[],
    )

    assert "before considering broader N5 rollout" in markdown
