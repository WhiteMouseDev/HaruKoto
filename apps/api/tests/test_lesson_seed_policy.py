import json
import uuid
from collections import Counter
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy.sql.dml import Delete

from app.seeds import lessons as lesson_seed
from app.seeds.lessons import (
    CONTENT_DIR,
    CONTENT_FILES,
    CONTENT_FILES_BY_LEVEL,
    CONTENT_ROOT,
    DEFAULT_LESSON_LEVEL,
    _forced_unpublished_filepaths,
    _iter_content_filepaths,
    _lesson_is_published,
    _normalize_lesson_level,
    _parse_args,
    _replace_item_links,
    _resolve_extra_content_file,
    _seed_one_chapter,
    _selected_lesson_levels,
    audit_lesson_seed_sync,
    seed_lessons,
)


@pytest.mark.parametrize("status", ["PILOT", "PUBLISHED"])
def test_lesson_seed_publishes_reviewed_statuses(status: str) -> None:
    assert _lesson_is_published({"status": status}) is True


def test_lesson_seed_does_not_publish_draft_status() -> None:
    assert _lesson_is_published({"status": "DRAFT"}) is False


def test_lesson_seed_can_force_extra_pilot_source_to_unpublished() -> None:
    assert _lesson_is_published({"status": "PILOT"}, force_unpublished=True) is False
    assert _lesson_is_published({"status": "PUBLISHED"}, force_unpublished=True) is False


def test_lesson_seed_rejects_unknown_status() -> None:
    with pytest.raises(ValueError, match="Unsupported lesson meta.status: ARCHIVED"):
        _lesson_is_published({"status": "ARCHIVED"})


def test_lesson_seed_registry_keeps_n5_as_default_source() -> None:
    assert DEFAULT_LESSON_LEVEL == "N5"
    assert CONTENT_DIR == CONTENT_ROOT / "n5"
    assert CONTENT_FILES_BY_LEVEL[DEFAULT_LESSON_LEVEL] == CONTENT_FILES


def test_lesson_seed_level_selection_defaults_to_n5() -> None:
    assert _selected_lesson_levels() == ("N5",)


def test_lesson_seed_level_selection_normalizes_and_deduplicates_levels() -> None:
    assert _selected_lesson_levels(["n5", " N5 "]) == ("N5",)


def test_lesson_seed_level_selection_supports_n4_sources() -> None:
    assert _normalize_lesson_level("N4") == "N4"
    assert CONTENT_FILES_BY_LEVEL["N4"] == [
        "ch01-core-directions-and-judgment.json",
        "ch02-reasons-conditions-and-intent.json",
        "ch03-quality-and-degree.json",
        "ch04-everyday-action-extensions.json",
        "ch05-observation-reporting-and-expectation.json",
        "ch06-benefactive-contrast-and-passive.json",
    ]


def test_lesson_seed_n5_sources_are_pilot_publishable() -> None:
    lesson_count = 0

    for filename in CONTENT_FILES_BY_LEVEL["N5"]:
        data = json.loads((CONTENT_ROOT / "n5" / filename).read_text(encoding="utf-8"))

        assert data["meta"]["jlpt_level"] == "N5"
        assert data["meta"]["status"] == "PILOT"
        assert _lesson_is_published(data["meta"]) is True
        assert data["meta"]["lesson_count"] == len(data["lessons"])
        lesson_count += len(data["lessons"])

    assert lesson_count == 50


def test_lesson_seed_n4_sources_are_pilot_publishable() -> None:
    lesson_count = 0
    expected_statuses = {
        "ch01-core-directions-and-judgment.json": "PILOT",
        "ch02-reasons-conditions-and-intent.json": "PILOT",
        "ch03-quality-and-degree.json": "PILOT",
        "ch04-everyday-action-extensions.json": "PILOT",
        "ch05-observation-reporting-and-expectation.json": "PILOT",
        "ch06-benefactive-contrast-and-passive.json": "PILOT",
    }

    for filename in CONTENT_FILES_BY_LEVEL["N4"]:
        data = json.loads((CONTENT_ROOT / "n4" / filename).read_text(encoding="utf-8"))
        expected_status = expected_statuses[filename]

        assert data["meta"]["jlpt_level"] == "N4"
        assert data["meta"]["status"] == expected_status
        assert _lesson_is_published(data["meta"]) is (expected_status == "PILOT")
        assert data["meta"]["lesson_count"] == len(data["lessons"])
        lesson_count += len(data["lessons"])

    assert lesson_count == 26


def test_lesson_seed_deduplicates_registered_extra_file() -> None:
    extra_path = _resolve_extra_content_file(Path("n4/ch04-everyday-action-extensions.json"))
    data = json.loads(extra_path.read_text(encoding="utf-8"))

    paths = list(_iter_content_filepaths(["N4"], extra_content_files=[Path("n4/ch04-everyday-action-extensions.json")]))

    assert extra_path == CONTENT_ROOT / "n4" / "ch04-everyday-action-extensions.json"
    assert extra_path in paths
    assert CONTENT_FILES_BY_LEVEL["N4"] == [
        "ch01-core-directions-and-judgment.json",
        "ch02-reasons-conditions-and-intent.json",
        "ch03-quality-and-degree.json",
        "ch04-everyday-action-extensions.json",
        "ch05-observation-reporting-and-expectation.json",
        "ch06-benefactive-contrast-and-passive.json",
    ]
    assert paths.count(extra_path) == 1
    assert data["meta"]["status"] == "PILOT"
    assert _lesson_is_published(data["meta"]) is True


def test_lesson_seed_only_extra_content_file_selection_skips_default_registry() -> None:
    extra_path = _resolve_extra_content_file(Path("n4/ch07-condition-report-and-recency.json"))

    paths = list(
        _iter_content_filepaths(
            ["N4"],
            extra_content_files=[Path("n4/ch07-condition-report-and-recency.json")],
            only_extra_content_files=True,
        )
    )

    assert paths == [extra_path]


def test_lesson_seed_force_unpublished_applies_only_to_unregistered_extra_sources() -> None:
    ch07_path = _resolve_extra_content_file(Path("n4/ch07-condition-report-and-recency.json"))

    forced_paths = _forced_unpublished_filepaths(
        ["N4"],
        extra_content_files=[Path("n4/ch07-condition-report-and-recency.json")],
        force_extra_unpublished=True,
    )

    assert forced_paths == {ch07_path}


def test_lesson_seed_force_unpublished_rejects_registered_duplicate_extra_file() -> None:
    with pytest.raises(ValueError, match="Cannot force registered extra lesson files unpublished"):
        _forced_unpublished_filepaths(
            ["N4"],
            extra_content_files=[Path("n4/ch04-everyday-action-extensions.json")],
            force_extra_unpublished=True,
        )


def test_lesson_seed_cli_accepts_explicit_unpublished_extra_seed_path(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "sys.argv",
        [
            "lessons.py",
            "--level",
            "N4",
            "--only-extra-content-files",
            "--extra-content-file",
            "n4/ch07-condition-report-and-recency.json",
            "--force-extra-unpublished",
        ],
    )

    args = _parse_args()

    assert args.levels == ["N4"]
    assert args.only_extra_content_files is True
    assert args.force_extra_unpublished is True
    assert args.extra_content_file == [Path("n4/ch07-condition-report-and-recency.json")]


def test_lesson_seed_cli_rejects_force_unpublished_without_extra_file(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("sys.argv", ["lessons.py", "--force-extra-unpublished"])

    with pytest.raises(SystemExit):
        _parse_args()


def test_lesson_seed_extra_content_file_must_stay_under_lesson_root(tmp_path) -> None:
    outside = tmp_path / "lesson.json"
    outside.write_text("{}", encoding="utf-8")

    with pytest.raises(ValueError, match="must be under"):
        _resolve_extra_content_file(outside)


@pytest.mark.asyncio
async def test_lesson_seed_force_unpublished_targets_only_unregistered_extra_file(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: list[tuple[str, bool]] = []

    async def fake_seed_one_chapter(db, filepath: Path, *, force_unpublished: bool = False) -> dict[str, int]:
        captured.append((filepath.name, force_unpublished))
        return {"chapters": 1, "lessons": 1, "item_links": 0, "item_links_deleted": 0}

    db = AsyncMock()
    monkeypatch.setattr(lesson_seed, "_seed_one_chapter", fake_seed_one_chapter)

    result = await seed_lessons(
        db,
        levels=["N4"],
        extra_content_files=[Path("n4/ch07-condition-report-and-recency.json")],
        force_extra_unpublished=True,
    )

    assert result == {"chapters": 7, "lessons": 7, "item_links": 0, "item_links_deleted": 0}
    assert captured[:-1] == [
        ("ch01-core-directions-and-judgment.json", False),
        ("ch02-reasons-conditions-and-intent.json", False),
        ("ch03-quality-and-degree.json", False),
        ("ch04-everyday-action-extensions.json", False),
        ("ch05-observation-reporting-and-expectation.json", False),
        ("ch06-benefactive-contrast-and-passive.json", False),
    ]
    assert captured[-1] == ("ch07-condition-report-and-recency.json", True)
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_lesson_seed_only_extra_force_unpublished_processes_ch07_only(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: list[tuple[str, bool]] = []

    async def fake_seed_one_chapter(db, filepath: Path, *, force_unpublished: bool = False) -> dict[str, int]:
        captured.append((filepath.name, force_unpublished))
        return {"chapters": 1, "lessons": 5, "item_links": 38, "item_links_deleted": 0}

    db = AsyncMock()
    monkeypatch.setattr(lesson_seed, "_seed_one_chapter", fake_seed_one_chapter)

    result = await seed_lessons(
        db,
        levels=["N4"],
        extra_content_files=[Path("n4/ch07-condition-report-and-recency.json")],
        only_extra_content_files=True,
        force_extra_unpublished=True,
    )

    assert result == {"chapters": 1, "lessons": 5, "item_links": 38, "item_links_deleted": 0}
    assert captured == [("ch07-condition-report-and-recency.json", True)]
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_seed_one_chapter_force_unpublished_writes_chapter_and_lessons_unpublished(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    chapter_publish_flags: list[bool] = []
    lesson_publish_flags: list[bool] = []

    async def fake_upsert_chapter(db, meta, *, is_published: bool | None = None):
        chapter_publish_flags.append(is_published)
        chapter = MagicMock()
        chapter.id = uuid.uuid4()
        chapter.jlpt_level = meta["jlpt_level"]
        chapter.title = meta["chapter_title"]
        return chapter

    async def fake_upsert_lesson(db, chapter, lesson_data, *, is_published: bool):
        lesson_publish_flags.append(is_published)
        lesson = MagicMock()
        lesson.id = uuid.uuid4()
        lesson.jlpt_level = chapter.jlpt_level
        return lesson

    async def fake_replace_item_links(db, lesson, vocab_orders, grammar_order):
        return {"created": len(vocab_orders) + (1 if grammar_order is not None else 0), "deleted": 0}

    monkeypatch.setattr(lesson_seed, "_upsert_chapter", fake_upsert_chapter)
    monkeypatch.setattr(lesson_seed, "_upsert_lesson", fake_upsert_lesson)
    monkeypatch.setattr(lesson_seed, "_replace_item_links", fake_replace_item_links)

    result = await _seed_one_chapter(
        AsyncMock(),
        CONTENT_ROOT / "n4" / "ch07-condition-report-and-recency.json",
        force_unpublished=True,
    )

    assert result == {"chapters": 1, "lessons": 5, "item_links": 38, "item_links_deleted": 0}
    assert chapter_publish_flags == [False]
    assert lesson_publish_flags == [False, False, False, False, False]


@pytest.mark.asyncio
async def test_lesson_seed_audit_counts_chapter_publish_state_mismatch(monkeypatch: pytest.MonkeyPatch) -> None:
    chapter = MagicMock()
    chapter.is_published = True
    chapter_result = MagicMock()
    chapter_result.scalar_one_or_none.return_value = chapter

    lessons = []
    lesson_results = []
    for _order in range(27, 32):
        lesson = MagicMock()
        lesson.is_published = False
        lesson.content_jsonb = {"reading": {}, "questions": []}
        lesson.item_links = []
        lessons.append(lesson)

        result = MagicMock()
        result.scalar_one_or_none.return_value = lesson
        lesson_results.append(result)

    db = AsyncMock()
    db.execute = AsyncMock(side_effect=[chapter_result, *lesson_results])

    async def fake_build_expected_item_links(db, *, jlpt_level, vocab_orders, grammar_order):
        return []

    monkeypatch.setattr(lesson_seed, "_build_expected_item_links", fake_build_expected_item_links)

    counts = await audit_lesson_seed_sync(
        db,
        levels=["N4"],
        extra_content_files=[Path("n4/ch07-condition-report-and-recency.json")],
        only_extra_content_files=True,
        force_extra_unpublished=True,
    )

    assert counts["publish_state_mismatches"] == 1
    assert counts["missing_lessons"] == 0


@pytest.mark.asyncio
async def test_lesson_seed_replaces_existing_item_links_after_reference_resolution() -> None:
    lesson = MagicMock()
    lesson.id = uuid.uuid4()
    lesson.jlpt_level = "N5"

    vocab_one = MagicMock()
    vocab_one.id = uuid.uuid4()
    vocab_two = MagicMock()
    vocab_two.id = uuid.uuid4()
    grammar = MagicMock()
    grammar.id = uuid.uuid4()

    vocab_one_result = MagicMock()
    vocab_one_result.scalar_one_or_none.return_value = vocab_one
    vocab_two_result = MagicMock()
    vocab_two_result.scalar_one_or_none.return_value = vocab_two
    grammar_result = MagicMock()
    grammar_result.scalar_one_or_none.return_value = grammar
    delete_result = MagicMock()
    delete_result.rowcount = 4

    db = AsyncMock()
    db.execute = AsyncMock(
        side_effect=[
            vocab_one_result,
            vocab_two_result,
            grammar_result,
            delete_result,
            MagicMock(),
            MagicMock(),
            MagicMock(),
        ]
    )

    result = await _replace_item_links(db, lesson, vocab_orders=[1, 2], grammar_order=3)

    assert result == {"created": 3, "deleted": 4}
    assert isinstance(db.execute.await_args_list[3].args[0], Delete)


@pytest.mark.asyncio
async def test_lesson_seed_does_not_delete_links_when_reference_resolution_fails() -> None:
    lesson = MagicMock()
    lesson.id = uuid.uuid4()
    lesson.jlpt_level = "N5"

    missing_vocab_result = MagicMock()
    missing_vocab_result.scalar_one_or_none.return_value = None

    db = AsyncMock()
    db.execute = AsyncMock(return_value=missing_vocab_result)

    with pytest.raises(ValueError, match="Vocabulary order=999 not found for N5"):
        await _replace_item_links(db, lesson, vocab_orders=[999], grammar_order=None)

    assert len(db.execute.await_args_list) == 1
    assert not isinstance(db.execute.await_args.args[0], Delete)


def test_lesson_seed_source_answers_are_not_collapsed_to_first_option() -> None:
    answer_counts: Counter[str] = Counter()

    for filename in CONTENT_FILES:
        data = json.loads((CONTENT_DIR / filename).read_text(encoding="utf-8"))
        for lesson in data["lessons"]:
            for question in lesson["content_jsonb"]["questions"]:
                if question["type"] not in ("VOCAB_MCQ", "CONTEXT_CLOZE"):
                    continue

                option_ids = {option["id"] for option in question["options"]}
                correct_answer = question["correct_answer"]
                assert correct_answer in option_ids
                answer_counts[correct_answer] += 1

    assert set(answer_counts) == {"a", "b", "c", "d"}
    assert len(set(answer_counts.values())) == 1
