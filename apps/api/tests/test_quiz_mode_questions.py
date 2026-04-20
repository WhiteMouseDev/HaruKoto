from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.quiz_mode_questions import (
    load_cloze_questions,
    load_normal_questions,
    load_review_questions,
    load_sentence_arrange_questions,
)


def _scalars_result(items: list[object]) -> MagicMock:
    result = MagicMock()
    result.scalars.return_value.all.return_value = items
    return result


@pytest.mark.asyncio
async def test_load_cloze_questions_builds_payloads():
    item = SimpleNamespace(
        id=uuid.uuid4(),
        sentence="これは___です。",
        translation="이것은 책입니다.",
        correct_answer="本",
        options=["本", "水"],
        explanation="명사 보충 문제",
    )
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_scalars_result([item]))

    questions = await load_cloze_questions(db, jlpt_level="N5", count=1, stage_content_ids=[])

    assert db.execute.await_count == 1
    assert questions[0]["type"] == "CLOZE"
    assert questions[0]["question"] == "これは___です。"
    assert questions[0]["translation"] == "이것은 책입니다."
    assert questions[0]["correctOptionId"] == questions[0]["options"][0]["id"]


@pytest.mark.asyncio
async def test_load_sentence_arrange_questions_builds_payloads():
    item = SimpleNamespace(
        id=uuid.uuid4(),
        korean_sentence="저는 학생입니다.",
        japanese_sentence="私は学生です。",
        tokens=[{"text": "私"}, "は", {"text": "学生"}, "です"],
        explanation="기본 문장 배열",
    )
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_scalars_result([item]))

    questions = await load_sentence_arrange_questions(db, jlpt_level="N5", count=1, stage_content_ids=[])

    assert db.execute.await_count == 1
    assert questions == [
        {
            "id": str(item.id),
            "type": "SENTENCE_ARRANGE",
            "question": "저는 학생입니다.",
            "japaneseSentence": "私は学生です。",
            "tokens": ["私", "は", "学生", "です"],
            "explanation": "기본 문장 배열",
            "correctOptionId": "",
            "options": [],
        }
    ]


@pytest.mark.asyncio
async def test_load_normal_questions_builds_vocab_payloads():
    item = SimpleNamespace(
        id=uuid.uuid4(),
        word="食べる",
        reading="たべる",
        meaning_ko="먹다",
    )
    db = AsyncMock()
    db.execute = AsyncMock(side_effect=[_scalars_result([item]), _scalars_result(["먹다", "마시다", "자다", "가다"])])

    questions = await load_normal_questions(db, quiz_type="VOCABULARY", jlpt_level="N5", count=1, stage_content_ids=[])

    assert db.execute.await_count == 2
    assert questions[0]["type"] == "VOCABULARY"
    assert questions[0]["question"] == "食べる"
    assert questions[0]["reading"] == "たべる"
    assert questions[0]["meaningKo"] == "먹다"


@pytest.mark.asyncio
async def test_load_review_questions_builds_grammar_payloads():
    item = SimpleNamespace(
        id=uuid.uuid4(),
        pattern="〜てもいい",
        meaning_ko="~해도 된다",
    )
    db = AsyncMock()
    db.execute = AsyncMock(side_effect=[_scalars_result([item]), _scalars_result(["~해도 된다", "~하면 안 된다", "~해야 한다"])])

    questions = await load_review_questions(
        db,
        user_id=uuid.uuid4(),
        quiz_type="GRAMMAR",
        jlpt_level="N5",
        count=1,
        stage_content_ids=[],
    )

    assert db.execute.await_count == 2
    assert questions[0]["type"] == "GRAMMAR"
    assert questions[0]["question"] == "〜てもいい"
    assert questions[0]["pattern"] == "〜てもいい"
    assert questions[0]["meaningKo"] == "~해도 된다"
