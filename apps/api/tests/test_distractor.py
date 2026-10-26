from __future__ import annotations

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models import Grammar, Vocabulary
from app.services import distractor
from app.services.distractor import DistractorPool, generate_distractors, load_distractor_pool


def _vocab(meaning: str, *, category: str | None = None, glosses: list[str] | None = None) -> Vocabulary:
    return Vocabulary(
        id=uuid.uuid4(),
        word=meaning,
        reading=meaning,
        meaning_ko=meaning,
        meaning_glosses_ko=glosses if glosses is not None else [meaning],
        category_tag=category,
    )


@pytest.mark.asyncio
async def test_pool_preserves_category_seen_and_meaning_safety(monkeypatch):
    monkeypatch.setattr(distractor.random, "shuffle", lambda items: None)
    user_id = uuid.uuid4()
    correct = _vocab("식사", category="daily", glosses=["밥 먹기"])
    overlaps_correct = _vocab("간식", category="daily", glosses=["먹기"])
    seen_other_category = _vocab("걷다", category="travel")
    unseen_same_category = _vocab("자다", category="daily")
    seen_same_category = _vocab("운동", category="daily", glosses=["몸 움직이기"])
    overlaps_selected = _vocab("체조", category="daily", glosses=["움직이기"])
    third = _vocab("읽다", category="daily")
    pool = DistractorPool(
        "WORD",
        "N5",
        user_id,
        (correct, overlaps_correct, seen_other_category, unseen_same_category, seen_same_category, overlaps_selected, third),
        frozenset({overlaps_correct.id, seen_other_category.id, seen_same_category.id}),
    )
    db = AsyncMock()

    options = await generate_distractors(db, correct.id, "WORD", "N5", user_id=user_id, pool=pool)

    assert [option["id"] for option in options] == [str(seen_same_category.id), str(unseen_same_category.id), str(third.id)]
    db.execute.assert_not_awaited()
    db.get.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("item_type", ["WORD", "GRAMMAR"])
async def test_standalone_and_pooled_generation_keep_the_same_options(monkeypatch, item_type):
    monkeypatch.setattr(distractor.random, "shuffle", lambda items: None)
    user_id = uuid.uuid4()
    if item_type == "WORD":
        items = [_vocab(meaning, glosses=[]) for meaning in ["먹다, 식사하다", "보다", "읽다", "자다"]]
    else:
        items = [
            Grammar(id=uuid.uuid4(), pattern=meaning, meaning_ko=meaning, meaning_glosses_ko=[])
            for meaning in ["허가", "금지", "의무", "희망"]
        ]
    result = MagicMock()
    result.scalars.return_value.all.return_value = items
    seen_result = MagicMock()
    seen_result.all.return_value = [(items[-1].id,)]
    db = AsyncMock()
    db.get.return_value = items[0]
    db.execute.side_effect = [result, seen_result]

    standalone = await generate_distractors(db, items[0].id, item_type, "N5", user_id=user_id)
    pool = DistractorPool(item_type, "N5", user_id, tuple(items), frozenset({items[-1].id}))
    pooled = await generate_distractors(db, items[0].id, item_type, "N5", user_id=user_id, pool=pool)

    assert standalone == pooled
    assert [option["text"] for option in pooled] == [items[-1].meaning_ko, items[1].meaning_ko, items[2].meaning_ko]
    assert db.execute.await_count == 2
    assert db.get.await_count == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("mismatch", ["user", "level", "type"])
async def test_pool_cannot_be_reused_for_a_different_user_level_or_content(mismatch):
    item = _vocab("먹다")
    user_id = uuid.uuid4()
    pool = DistractorPool("WORD", "N5", user_id, (item,), frozenset())

    with pytest.raises(ValueError, match="does not match"):
        await generate_distractors(
            AsyncMock(),
            item.id,
            "GRAMMAR" if mismatch == "type" else "WORD",
            "N4" if mismatch == "level" else "N5",
            user_id=uuid.uuid4() if mismatch == "user" else user_id,
            pool=pool,
        )


@pytest.mark.asyncio
async def test_missing_correct_item_and_empty_pool_return_no_options():
    db = AsyncMock()
    db.get.return_value = None
    assert await generate_distractors(db, uuid.uuid4(), "WORD", "N5") == []
    assert await generate_distractors(db, uuid.uuid4(), "WORD", "N5", pool=DistractorPool("WORD", "N5", None, (), frozenset())) == []
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_loading_pool_without_user_skips_progress_query():
    db = AsyncMock()
    result = MagicMock()
    result.scalars.return_value.all.return_value = [_vocab("먹다")]
    db.execute.return_value = result

    pool = await load_distractor_pool(db, item_type="WORD", jlpt_level="N5")

    assert len(pool.candidates) == 1
    assert pool.seen_ids == frozenset()
    assert db.execute.await_count == 1


@pytest.mark.asyncio
async def test_unknown_item_type_is_rejected_before_querying():
    db = AsyncMock()
    with pytest.raises(ValueError, match="Unknown item_type"):
        await load_distractor_pool(db, item_type="INVALID", jlpt_level="N5")
    db.execute.assert_not_awaited()
