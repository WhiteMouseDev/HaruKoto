from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.models import Vocabulary
from app.services import quiz_smart_questions
from app.services.quiz_smart_questions import load_smart_questions


def _scalars_result(items: list[object]) -> MagicMock:
    result = MagicMock()
    result.scalars.return_value.all.return_value = items
    return result


@pytest.mark.asyncio
async def test_load_smart_questions_vocabulary_builds_distractor_options(monkeypatch):
    monkeypatch.setattr(quiz_smart_questions.random, "shuffle", lambda items: None)
    distractor_calls: list[uuid.UUID] = []

    async def fake_generate_distractors(_db, **kwargs):
        distractor_calls.append(kwargs["correct_item_id"])
        return [{"text": "마시다"}]

    monkeypatch.setattr(quiz_smart_questions, "generate_distractors", fake_generate_distractors)

    user_id = uuid.uuid4()
    review_vocab = SimpleNamespace(id=uuid.uuid4(), word="食べる", reading="たべる", meaning_ko="먹다")
    new_vocab = SimpleNamespace(id=uuid.uuid4(), word="見る", reading="みる", meaning_ko="보다")
    duplicate_new_vocab = SimpleNamespace(id=uuid.uuid4(), word="観る", reading="みる", meaning_ko="보다")
    db = AsyncMock()
    db.execute = AsyncMock(
        side_effect=[
            _scalars_result([review_vocab]),
            _scalars_result([review_vocab.id]),
            _scalars_result([new_vocab, duplicate_new_vocab]),
            _scalars_result(["먹다", "보다", "마시다", "자다", "읽다"]),
            _scalars_result([review_vocab, new_vocab]),
            MagicMock(all=MagicMock(return_value=[(review_vocab.id,)])),
        ]
    )

    questions = await load_smart_questions(
        db,
        user_id=user_id,
        category="VOCABULARY",
        jlpt_level="N5",
        distribution={"review": 1, "retry": 0, "new": 2},
        now=datetime(2026, 4, 20, tzinfo=UTC),
    )

    assert db.execute.await_count == 6
    assert distractor_calls == [review_vocab.id, new_vocab.id]
    assert [question["question"] for question in questions] == ["食べる", "見る"]
    assert questions[0]["type"] == "VOCABULARY"
    assert {option["text"] for option in questions[0]["options"]} == {"먹다", "마시다", "보다", "자다"}


@pytest.mark.asyncio
async def test_load_smart_questions_grammar_builds_question_payload(monkeypatch):
    monkeypatch.setattr(quiz_smart_questions.random, "shuffle", lambda items: None)

    grammar = SimpleNamespace(id=uuid.uuid4(), pattern="〜てもいい", meaning_ko="~해도 된다")
    db = AsyncMock()
    db.execute = AsyncMock(
        side_effect=[
            _scalars_result([]),
            _scalars_result([grammar]),
            _scalars_result(["~해도 된다", "~하면 안 된다", "~해야 한다", "~하지 않아도 된다"]),
        ]
    )

    questions = await load_smart_questions(
        db,
        user_id=uuid.uuid4(),
        category="GRAMMAR",
        jlpt_level="N5",
        distribution={"review": 0, "retry": 0, "new": 1},
        now=datetime(2026, 4, 20, tzinfo=UTC),
    )

    assert db.execute.await_count == 3
    assert questions == [
        {
            "id": str(grammar.id),
            "type": "GRAMMAR",
            "question": "〜てもいい",
            "options": questions[0]["options"],
            "correctOptionId": questions[0]["correctOptionId"],
            "pattern": "〜てもいい",
            "meaningKo": "~해도 된다",
        }
    ]
    assert [option["text"] for option in questions[0]["options"]] == ["~해도 된다", "~하면 안 된다", "~해야 한다", "~하지 않아도 된다"]


@pytest.mark.asyncio
@pytest.mark.parametrize("question_count", [2, 10])
async def test_smart_vocabulary_loads_candidate_and_seen_pools_once_for_all_questions(monkeypatch, question_count):
    monkeypatch.setattr(quiz_smart_questions.random, "shuffle", lambda items: None)
    vocabularies = [
        Vocabulary(
            id=uuid.uuid4(),
            word=f"単語{index}",
            reading=f"たんご{index}",
            meaning_ko=f"의미{index}",
            meaning_glosses_ko=[f"의미{index}"],
            category_tag="daily",
        )
        for index in range(question_count + 3)
    ]
    seen_result = MagicMock()
    seen_result.all.return_value = [(vocabularies[-1].id,)]
    db = AsyncMock()
    db.execute.side_effect = [
        _scalars_result([]),
        _scalars_result(vocabularies[:question_count]),
        _scalars_result([item.meaning_ko for item in vocabularies]),
        _scalars_result(vocabularies),
        seen_result,
    ]

    questions = await load_smart_questions(
        db,
        user_id=uuid.uuid4(),
        category="VOCABULARY",
        jlpt_level="N5",
        distribution={"review": 0, "retry": 0, "new": question_count},
        now=datetime(2026, 10, 15, tzinfo=UTC),
    )

    assert len(questions) == question_count
    assert db.execute.await_count == 5
    db.get.assert_not_awaited()
    for question, vocabulary in zip(questions, vocabularies, strict=False):
        options = question["options"]
        assert len(options) == 4
        assert len({option["text"] for option in options}) == 4
        assert options[0]["text"] == vocabulary.meaning_ko
        assert options[0]["id"] == question["correctOptionId"]
        assert options[1]["text"] == vocabularies[-1].meaning_ko
