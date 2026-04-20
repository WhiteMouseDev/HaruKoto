from __future__ import annotations

import uuid
from types import SimpleNamespace

from app.services import quiz_question_builder
from app.services.quiz_question_builder import (
    build_cloze_question,
    build_grammar_question,
    build_options,
    build_sentence_arrange_question,
    build_vocab_question,
)


def test_build_options_marks_correct_option(monkeypatch):
    monkeypatch.setattr(quiz_question_builder.random, "shuffle", lambda options: None)

    options, correct_id = build_options("먹다", ["마시다", "자다", "가다"])

    assert options[0] == {"id": correct_id, "text": "먹다"}
    assert [option["text"] for option in options] == ["먹다", "마시다", "자다", "가다"]
    assert len({option["id"] for option in options}) == 4


def test_build_vocab_question_keeps_api_payload_shape():
    vocab_id = uuid.uuid4()
    vocab = SimpleNamespace(
        id=vocab_id,
        word="食べる",
        reading="たべる",
        meaning_ko="먹다",
    )
    options = [{"id": "correct", "text": "먹다"}]

    question = build_vocab_question(vocab, "VOCABULARY", options, "correct")

    assert question == {
        "id": str(vocab_id),
        "type": "VOCABULARY",
        "question": "食べる",
        "reading": "たべる",
        "questionSubText": "たべる",
        "options": options,
        "correctOptionId": "correct",
        "word": "食べる",
        "meaningKo": "먹다",
    }


def test_build_grammar_question_keeps_api_payload_shape():
    grammar_id = uuid.uuid4()
    grammar = SimpleNamespace(
        id=grammar_id,
        pattern="〜てもいい",
        meaning_ko="~해도 된다",
    )
    options = [{"id": "correct", "text": "~해도 된다"}]

    question = build_grammar_question(grammar, "GRAMMAR", options, "correct")

    assert question == {
        "id": str(grammar_id),
        "type": "GRAMMAR",
        "question": "〜てもいい",
        "options": options,
        "correctOptionId": "correct",
        "pattern": "〜てもいい",
        "meaningKo": "~해도 된다",
    }


def test_build_cloze_question_keeps_api_payload_shape(monkeypatch):
    item_id = uuid.uuid4()
    ids = iter(["correct", "wrong"])
    monkeypatch.setattr(quiz_question_builder.uuid, "uuid4", lambda: next(ids))
    item = SimpleNamespace(
        id=item_id,
        sentence="これは___です。",
        translation="이것은 책입니다.",
        correct_answer="本",
        options=["本", "水"],
        explanation="명사 보충 문제",
    )

    question = build_cloze_question(item)

    assert question == {
        "id": str(item_id),
        "type": "CLOZE",
        "question": "これは___です。",
        "translation": "이것은 책입니다.",
        "options": [{"id": "correct", "text": "本"}, {"id": "wrong", "text": "水"}],
        "correctOptionId": "correct",
        "explanation": "명사 보충 문제",
    }


def test_build_sentence_arrange_question_keeps_api_payload_shape():
    item_id = uuid.uuid4()
    item = SimpleNamespace(
        id=item_id,
        korean_sentence="저는 학생입니다.",
        japanese_sentence="私は学生です。",
        tokens=[{"text": "私"}, "は", {"text": "学生"}, "です"],
        explanation="기본 문장 배열",
    )

    question = build_sentence_arrange_question(item)

    assert question == {
        "id": str(item_id),
        "type": "SENTENCE_ARRANGE",
        "question": "저는 학생입니다.",
        "japaneseSentence": "私は学生です。",
        "tokens": ["私", "は", "学生", "です"],
        "explanation": "기본 문장 배열",
        "correctOptionId": "",
        "options": [],
    }
