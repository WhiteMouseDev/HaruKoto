from __future__ import annotations

import uuid
from types import SimpleNamespace

from app.services import kana_quiz_questions
from app.services.kana_quiz_questions import build_kana_quiz_questions, strip_kana_quiz_answers


def test_build_kana_quiz_questions_recognition_payload(monkeypatch):
    monkeypatch.setattr(kana_quiz_questions.random, "shuffle", lambda items: None)
    chars = [
        SimpleNamespace(id=uuid.uuid4(), character="あ", romaji="a"),
        SimpleNamespace(id=uuid.uuid4(), character="い", romaji="i"),
        SimpleNamespace(id=uuid.uuid4(), character="う", romaji="u"),
        SimpleNamespace(id=uuid.uuid4(), character="え", romaji="e"),
    ]

    questions = build_kana_quiz_questions(chars, count=1, quiz_mode="recognition")

    assert len(questions) == 1
    assert questions[0]["id"] == str(chars[0].id)
    assert questions[0]["question"] == "あ"
    assert [option["text"] for option in questions[0]["options"]] == ["a", "i", "u", "e"]
    assert questions[0]["correctOptionId"] == questions[0]["options"][0]["id"]


def test_build_kana_quiz_questions_sound_matching_payload(monkeypatch):
    monkeypatch.setattr(kana_quiz_questions.random, "shuffle", lambda items: None)
    chars = [
        SimpleNamespace(id=uuid.uuid4(), character="あ", romaji="a"),
        SimpleNamespace(id=uuid.uuid4(), character="い", romaji="i"),
    ]

    questions = build_kana_quiz_questions(chars, count=1, quiz_mode="sound_matching")

    assert questions[0]["question"] == "a"
    assert [option["text"] for option in questions[0]["options"]] == ["あ", "い"]
    assert questions[0]["correctOptionId"] == questions[0]["options"][0]["id"]


def test_build_kana_quiz_questions_defaults_unknown_mode_to_recognition(monkeypatch):
    monkeypatch.setattr(kana_quiz_questions.random, "shuffle", lambda items: None)
    chars = [
        SimpleNamespace(id=uuid.uuid4(), character="あ", romaji="a"),
        SimpleNamespace(id=uuid.uuid4(), character="い", romaji="i"),
    ]

    questions = build_kana_quiz_questions(chars, count=1, quiz_mode="kana_matching")

    assert questions[0]["question"] == "あ"
    assert [option["text"] for option in questions[0]["options"]] == ["a", "i"]


def test_build_kana_quiz_questions_respects_count(monkeypatch):
    monkeypatch.setattr(kana_quiz_questions.random, "shuffle", lambda items: None)
    chars = [
        SimpleNamespace(id=uuid.uuid4(), character="あ", romaji="a"),
        SimpleNamespace(id=uuid.uuid4(), character="い", romaji="i"),
        SimpleNamespace(id=uuid.uuid4(), character="う", romaji="u"),
    ]

    questions = build_kana_quiz_questions(chars, count=2, quiz_mode="recognition")

    assert [question["id"] for question in questions] == [str(chars[0].id), str(chars[1].id)]


def test_strip_kana_quiz_answers_removes_correct_option_id():
    questions = [
        {
            "id": "question-1",
            "question": "あ",
            "options": [{"id": "correct", "text": "a"}],
            "correctOptionId": "correct",
        }
    ]

    assert strip_kana_quiz_answers(questions) == [
        {
            "id": "question-1",
            "question": "あ",
            "options": [{"id": "correct", "text": "a"}],
        }
    ]
