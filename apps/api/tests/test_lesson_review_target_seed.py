"""Seed target resolution is level-scoped, explicit, and safe before writes."""

import json
from copy import deepcopy
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock
from uuid import NAMESPACE_URL, uuid4, uuid5

import pytest

from app.models.lesson import Lesson, LessonItemLink
from app.seeds import lessons as seed
from app.seeds.lessons import SeedItemLink
from app.services.lesson_command import _map_questions_to_links


@pytest.mark.parametrize(
    "metadata",
    [
        {},
        {"vocabulary_order": 1, "grammar_order": 1},
        {"vocabulary_order": "1"},
        {"vocabulary_order": 0},
        {"vocabulary_order": -1},
        {"vocabulary_order": True},
        {"grammar_order": 1.0},
        {"grammar_order": None},
        {"srs_skip_reason": "  "},
        {"srs_skip_reason": False},
        {"srs_skip_reason": "복합 평가", "grammar_order": 1},
        {"vocabulary_id": str(uuid4())},
        {"grammar_id": str(uuid4()), "grammar_order": 1},
    ],
)
def test_source_targets_reject_missing_ambiguous_and_invalid_metadata(metadata: dict) -> None:
    with pytest.raises(ValueError):
        seed._question_review_reference(metadata)


def test_source_target_accepts_an_explicit_order_or_reviewed_skip_reason() -> None:
    assert seed._question_review_reference({"vocabulary_order": 7}) == ("WORD", 7)
    assert seed._question_review_reference({"grammar_order": 1}) == ("GRAMMAR", 1)
    assert seed._question_review_reference({"srs_skip_reason": "단일 문법으로 귀속할 수 없는 복합 과제"}) is None


async def test_resolving_question_targets_is_level_scoped_deduplicated_and_does_not_mutate_source(monkeypatch) -> None:
    vocabulary_id, grammar_id = uuid4(), uuid4()
    vocabulary = MagicMock(id=vocabulary_id)
    grammar = MagicMock(id=grammar_id)
    vocabulary_resolver = AsyncMock(return_value=vocabulary)
    grammar_resolver = AsyncMock(return_value=grammar)
    monkeypatch.setattr(seed, "_resolve_vocabulary", vocabulary_resolver)
    monkeypatch.setattr(seed, "_resolve_grammar", grammar_resolver)
    source = {
        "reading": {"script": []},
        "questions": [
            {"order": 1, "vocabulary_order": 7},
            {"order": 2, "grammar_order": 1},
            {"order": 3, "grammar_order": 1},
            {"order": 4, "srs_skip_reason": "複数の挨拶表現"},
        ],
    }
    original = deepcopy(source)
    db = AsyncMock()

    resolved, targets = await seed._resolve_lesson_content(db, jlpt_level="N4", content_jsonb=source)

    assert source == original
    assert resolved["questions"] == [
        {"order": 1, "vocabulary_id": str(vocabulary_id)},
        {"order": 2, "grammar_id": str(grammar_id)},
        {"order": 3, "grammar_id": str(grammar_id)},
        {"order": 4, "srs_skip_reason": "複数の挨拶表現"},
    ]
    vocabulary_resolver.assert_awaited_once_with(db, jlpt_level="N4", order=7)
    grammar_resolver.assert_awaited_once_with(db, jlpt_level="N4", order=1)
    assert len(targets) == 2
    assert all(target.is_core is False for target in targets)
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


async def test_extra_assessment_target_is_appended_as_non_core_without_reordering_intro_items(monkeypatch) -> None:
    vocabulary_id, primary_grammar_id, extra_grammar_id = uuid4(), uuid4(), uuid4()
    monkeypatch.setattr(seed, "_resolve_vocabulary", AsyncMock(return_value=MagicMock(id=vocabulary_id)))
    monkeypatch.setattr(seed, "_resolve_grammar", AsyncMock(return_value=MagicMock(id=primary_grammar_id)))
    extra = SeedItemLink(item_type="GRAMMAR", vocabulary_id=None, grammar_id=extra_grammar_id, item_order=0, is_core=False)
    duplicate_core = SeedItemLink(item_type="WORD", vocabulary_id=vocabulary_id, grammar_id=None, item_order=0, is_core=False)

    links = await seed._build_expected_item_links(
        AsyncMock(), jlpt_level="N5", vocab_orders=[7], grammar_order=1, review_targets=[extra, extra, duplicate_core]
    )

    assert [(link.item_type, link.vocabulary_id, link.grammar_id, link.item_order, link.is_core) for link in links] == [
        ("WORD", vocabulary_id, None, 1, True),
        ("GRAMMAR", None, primary_grammar_id, 2, True),
        ("GRAMMAR", None, extra_grammar_id, 3, False),
    ]


async def test_seed_rejects_missing_question_target_before_any_chapter_or_lesson_write(tmp_path: Path, monkeypatch) -> None:
    source = tmp_path / "invalid-lesson.json"
    source.write_text(
        json.dumps({"meta": {"status": "PILOT"}, "lessons": [{"content_jsonb": {"questions": [{"order": 1, "type": "VOCAB_MCQ"}]}}]}),
        encoding="utf-8",
    )
    upsert = AsyncMock()
    monkeypatch.setattr(seed, "_upsert_chapter", upsert)
    db = AsyncMock()

    with pytest.raises(ValueError, match="exactly one review target"):
        await seed._seed_one_chapter(db, source)

    upsert.assert_not_awaited()
    db.execute.assert_not_awaited()
    db.commit.assert_not_awaited()


async def test_all_405_reviewed_source_questions_resolve_to_explicit_linked_targets_or_exclusions(monkeypatch) -> None:
    """Exercise the API consumer of shared content, including the unpublished extra chapter."""
    data_root = seed.CONTENT_ROOT.parent
    catalogs = {}
    for item_type, directory, suffix in (("WORD", "vocabulary", "words"), ("GRAMMAR", "grammar", "grammar")):
        for level in ("N5", "N4"):
            rows = json.loads((data_root / directory / f"{level.lower()}-{suffix}.json").read_text(encoding="utf-8"))
            catalogs[item_type, level] = {row["order"] for row in rows if row["jlptLevel"] == level}

    def resolver(item_type):
        async def resolve(db, *, jlpt_level, order):
            assert order in catalogs[item_type, jlpt_level]
            return MagicMock(id=uuid5(NAMESPACE_URL, f"synthetic-lesson-target:{item_type}:{jlpt_level}:{order}"))

        return resolve

    monkeypatch.setattr(seed, "_resolve_vocabulary", resolver("WORD"))
    monkeypatch.setattr(seed, "_resolve_grammar", resolver("GRAMMAR"))
    lessons = questions = mapped = extras = 0
    for path in sorted(seed.CONTENT_ROOT.glob("*/*.json")):
        source = json.loads(path.read_text(encoding="utf-8"))
        level = source["meta"]["jlpt_level"]
        for lesson in source["lessons"]:
            content, targets = await seed._resolve_lesson_content(AsyncMock(), jlpt_level=level, content_jsonb=lesson["content_jsonb"])
            links = await seed._build_expected_item_links(
                AsyncMock(),
                jlpt_level=level,
                vocab_orders=lesson["vocab_orders"],
                grammar_order=lesson["grammar"]["grammar_order"],
                review_targets=targets,
            )
            runtime_lesson = Lesson(
                item_links=[
                    LessonItemLink(
                        item_type=link.item_type,
                        vocabulary_id=link.vocabulary_id,
                        grammar_id=link.grammar_id,
                        item_order=link.item_order,
                        is_core=link.is_core,
                    )
                    for link in links
                ]
            )
            resolved = _map_questions_to_links(runtime_lesson, content["questions"])
            lessons += 1
            questions += len(content["questions"])
            mapped += len(resolved)
            extras += sum(not link.is_core for link in links)

    assert (lessons, questions, mapped, questions - mapped, extras) == (81, 405, 400, 5, 17)
