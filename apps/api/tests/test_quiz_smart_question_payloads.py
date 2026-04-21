from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.quiz_smart_question_payloads import build_smart_grammar_questions, build_smart_vocab_question


@pytest.mark.asyncio
async def test_build_smart_vocab_question_uses_distractors_and_fallback_meanings():
    vocab = SimpleNamespace(id=uuid.uuid4(), word="食べる", reading="たべる", meaning_ko="먹다")
    db = AsyncMock()
    distractor_calls: list[uuid.UUID] = []

    async def fake_distractor_generator(_db, **kwargs):
        distractor_calls.append(kwargs["correct_item_id"])
        return [{"text": "마시다"}]

    question = await build_smart_vocab_question(
        db,
        vocab,
        jlpt_level="N5",
        user_id=uuid.uuid4(),
        fallback_meanings=["먹다", "마시다", "보다", "자다", "읽다"],
        distractor_generator=fake_distractor_generator,
        shuffle=lambda items: None,
    )

    assert distractor_calls == [vocab.id]
    assert question["question"] == "食べる"
    assert question["type"] == "VOCABULARY"
    assert [option["text"] for option in question["options"]] == ["먹다", "마시다", "보다", "자다"]


def test_build_smart_grammar_questions_keeps_payload_shape():
    grammar = SimpleNamespace(id=uuid.uuid4(), pattern="〜てもいい", meaning_ko="~해도 된다")

    questions = build_smart_grammar_questions(
        [grammar],
        all_meanings=["~해도 된다", "~하면 안 된다", "~해야 한다", "~하지 않아도 된다"],
        shuffle=lambda items: None,
    )

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
    assert {option["text"] for option in questions[0]["options"]} == {"~해도 된다", "~하면 안 된다", "~해야 한다", "~하지 않아도 된다"}
