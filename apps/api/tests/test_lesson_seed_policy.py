import json
import uuid
from collections import Counter
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy.sql.dml import Delete

from app.seeds.lessons import (
    CONTENT_DIR,
    CONTENT_FILES,
    CONTENT_FILES_BY_LEVEL,
    CONTENT_ROOT,
    DEFAULT_LESSON_LEVEL,
    _lesson_is_published,
    _normalize_lesson_level,
    _replace_item_links,
    _selected_lesson_levels,
)


@pytest.mark.parametrize("status", ["PILOT", "PUBLISHED"])
def test_lesson_seed_publishes_reviewed_statuses(status: str) -> None:
    assert _lesson_is_published({"status": status}) is True


def test_lesson_seed_does_not_publish_draft_status() -> None:
    assert _lesson_is_published({"status": "DRAFT"}) is False


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

    for filename in CONTENT_FILES_BY_LEVEL["N4"]:
        data = json.loads((CONTENT_ROOT / "n4" / filename).read_text(encoding="utf-8"))

        assert data["meta"]["jlpt_level"] == "N4"
        assert data["meta"]["status"] == "PILOT"
        assert _lesson_is_published(data["meta"]) is True
        assert data["meta"]["lesson_count"] == len(data["lessons"])
        lesson_count += len(data["lessons"])

    assert lesson_count == 10


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
