from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

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

    assert db.execute.await_count == 4
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
