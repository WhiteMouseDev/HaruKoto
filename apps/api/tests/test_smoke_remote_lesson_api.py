from scripts.smoke_remote_lesson_api import LessonRef, build_report, validate_chapters, validate_detail


def _chapters_payload() -> dict:
    return {
        "chapters": [
            {
                "chapterNo": 1,
                "lessons": [{"id": "lesson-1", "lessonNo": 1, "chapterLessonNo": 1, "title": "old"}],
            },
            {
                "chapterNo": 2,
                "lessons": [{"id": "lesson-2", "lessonNo": 2, "chapterLessonNo": 1, "title": "old"}],
            },
            {
                "chapterNo": 3,
                "lessons": [{"id": "lesson-3", "lessonNo": 3, "chapterLessonNo": 1, "title": "old"}],
            },
            {
                "chapterNo": 4,
                "lessons": [
                    {"id": f"lesson-{lesson_no}", "lessonNo": lesson_no, "chapterLessonNo": index, "title": f"HN4-{lesson_no:03d}"}
                    for index, lesson_no in enumerate(range(12, 17), start=1)
                ],
            },
        ]
    }


def _detail_payload(lesson_no: int) -> dict:
    return {
        "id": f"lesson-{lesson_no}",
        "lessonNo": lesson_no,
        "content": {
            "reading": {
                "script": [
                    {"speaker": "A", "voiceId": "a", "text": "line one", "translation": "one"},
                    {"speaker": "B", "voiceId": "b", "text": "line two", "translation": "two"},
                    {"speaker": "A", "voiceId": "a", "text": "line three", "translation": "three"},
                    {"speaker": "B", "voiceId": "b", "text": "line four", "translation": "four"},
                ]
            },
            "questions": [
                {"order": order, "type": "VOCAB_MCQ", "prompt": "?", "correctAnswer": None, "correctOrder": None} for order in range(1, 6)
            ],
        },
        "vocabItems": [{"id": "vocab", "word": "word"}],
        "grammarItems": [{"id": "grammar", "pattern": "~shi"}],
    }


def test_validate_chapters_finds_ch04_targets_and_counts() -> None:
    chapter_count, lesson_count, targets, blockers = validate_chapters(
        _chapters_payload(),
        expected_chapter_count=4,
        expected_lesson_count=8,
        expected_target_chapter_no=4,
        target_lesson_nos=[12, 13, 14, 15, 16],
    )

    assert chapter_count == 4
    assert lesson_count == 8
    assert blockers == []
    assert [target.lesson_no for target in targets] == [12, 13, 14, 15, 16]
    assert {target.chapter_no for target in targets} == {4}


def test_validate_chapters_blocks_missing_target_lesson() -> None:
    _, _, targets, blockers = validate_chapters(
        _chapters_payload(),
        expected_chapter_count=4,
        expected_lesson_count=8,
        expected_target_chapter_no=4,
        target_lesson_nos=[12, 99],
    )

    assert [target.lesson_no for target in targets] == [12]
    assert blockers == ["TARGET_LESSON_MISSING: HN4-099 was not returned by chapters API"]


def test_validate_detail_accepts_client_safe_detail_shape() -> None:
    check = validate_detail(
        _detail_payload(12),
        lesson_ref=LessonRef(lesson_no=12, lesson_id="lesson-12", chapter_no=4, chapter_lesson_no=1, title="HN4-012"),
        expected_script_lines=4,
        expected_questions=5,
    )

    assert check.status == "PASS"
    assert check.answer_keys_stripped is True
    assert check.blockers == []


def test_validate_detail_blocks_unstripped_answer_keys() -> None:
    payload = _detail_payload(12)
    payload["content"]["questions"][0]["correctAnswer"] = "a"

    check = validate_detail(
        payload,
        lesson_ref=LessonRef(lesson_no=12, lesson_id="lesson-12", chapter_no=4, chapter_lesson_no=1, title="HN4-012"),
        expected_script_lines=4,
        expected_questions=5,
    )

    assert check.status == "FAIL"
    assert "DETAIL_ANSWER_KEYS: HN4-012 did not strip answer keys for client detail" in check.blockers


def test_build_report_passes_when_chapters_and_details_match() -> None:
    report = build_report(
        api_base_url="https://api.example.com",
        level="N4",
        account_label="t***@example.com",
        chapters_payload=_chapters_payload(),
        detail_payloads={lesson_no: _detail_payload(lesson_no) for lesson_no in range(12, 17)},
        expected_chapter_count=4,
        expected_lesson_count=8,
        expected_target_chapter_no=4,
        target_lesson_nos=[12, 13, 14, 15, 16],
        expected_script_lines=4,
        expected_questions=5,
    )

    assert report.status == "PASS"
    assert report.blockers == []
    assert len(report.detail_checks) == 5
