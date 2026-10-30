from __future__ import annotations

import uuid
from copy import deepcopy

import pytest

from app.services.quiz_resume_snapshot import decode_quiz_resume_snapshot


def matching_questions(category="VOCABULARY", count=3):
    field = "word" if category == "VOCABULARY" else "pattern"
    return [
        {
            "id": str(uuid.uuid4()),
            "type": category,
            "question": f"単語{index}",
            field: f"単語{index}",
            "meaningKo": f"뜻{index}",
            "options": [],
            "correctOptionId": str(uuid.uuid4()),
        }
        for index in range(count)
    ]


def arrange_questions(count=3):
    return [
        {
            "id": str(uuid.uuid4()),
            "type": "SENTENCE_ARRANGE",
            "question": f"저는 학생{index}입니다.",
            "japaneseSentence": f"私は学生{index}です。",
            "tokens": ["私", "は", f"学生{index}", "です"],
            "options": [],
            "correctOptionId": "",
            "explanation": "기본 어순",
        }
        for index in range(count)
    ]


def choice_questions(count=3):
    return [
        {
            "id": str(uuid.uuid4()),
            "type": "VOCABULARY",
            "question": f"単語{index}",
            "options": [{"id": "right", "text": "정답"}, {"id": "wrong", "text": "오답"}],
            "correctOptionId": "right",
        }
        for index in range(count)
    ]


@pytest.mark.parametrize("category", ["VOCABULARY", "GRAMMAR"])
@pytest.mark.parametrize("stored", [False, True], ids=["legacy", "metadata"])
def test_matching_resume_keeps_both_sides_original_ids_and_snapshot_immutable(category, stored):
    questions = matching_questions(category)
    expected_pairs = [{"id": q["correctOptionId"], "word": q["question"], "meaning": q["meaningKo"]} for q in questions]
    raw = {"mode": "matching", "questions": questions, "matchingPairs": expected_pairs} if stored else questions
    original = deepcopy(raw)
    result = decode_quiz_resume_snapshot(raw, total_questions=3, quiz_type=category)
    assert result.status == "available" and result.mode == "matching"
    assert [p.model_dump() for p in result.matching_pairs] == expected_pairs
    assert result.questions == questions and raw == original
    assert result.source == ("stored" if stored else "legacy_snapshot")


@pytest.mark.parametrize("stored", [False, True], ids=["legacy", "metadata"])
def test_arrange_resume_keeps_tokens_and_original_japanese_without_content_lookup(stored):
    questions = arrange_questions()
    raw = {"mode": "arrange", "questions": questions} if stored else questions
    original = deepcopy(raw)
    result = decode_quiz_resume_snapshot(raw, total_questions=3, quiz_type="SENTENCE_ARRANGE")
    assert result.status == "available" and result.mode == "arrange"
    assert result.questions == questions and raw == original
    assert result.matching_pairs is None


def test_legacy_sentence_matching_is_unavailable_instead_of_fabricating_missing_japanese():
    question = {
        "id": str(uuid.uuid4()),
        "type": "SENTENCE_ARRANGE",
        "question": "저는 학생입니다.",
        "options": [],
        "correctOptionId": str(uuid.uuid4()),
    }
    raw = [question]
    original = deepcopy(raw)
    result = decode_quiz_resume_snapshot(raw, total_questions=1)
    assert (result.mode, result.status) == ("matching", "legacy_unavailable")
    assert raw == original


def test_new_sentence_matching_resumes_only_its_complete_original_display_snapshot():
    question = {
        "id": str(uuid.uuid4()),
        "type": "SENTENCE_ARRANGE",
        "question": "저는 학생입니다.",
        "options": [],
        "correctOptionId": str(uuid.uuid4()),
        "japaneseSentence": "私は学生です。",
    }
    raw = {
        "mode": "matching",
        "questions": [question],
        "matchingPairs": [{"id": question["correctOptionId"], "word": question["question"], "meaning": question["japaneseSentence"]}],
    }
    result = decode_quiz_resume_snapshot(raw, total_questions=1)
    assert result.status == "available" and result.mode == "matching"
    assert result.matching_pairs[0].meaning == "私は学生です。"


@pytest.mark.parametrize("mode", [None, "normal", "smart", "wrong_answer_review", "review"])
def test_choice_legacy_array_and_metadata_remain_compatible(mode):
    questions = choice_questions()
    raw = {"mode": mode, "questions": questions} if mode else questions
    result = decode_quiz_resume_snapshot(raw, total_questions=3)
    assert result.status == "available" and result.mode == (mode or "normal")
    assert result.questions == questions and result.matching_pairs is None


def test_legacy_cloze_category_keeps_its_renderer_when_question_type_was_omitted():
    questions = choice_questions()
    for question in questions:
        del question["type"]
    result = decode_quiz_resume_snapshot(questions, total_questions=3, quiz_type="CLOZE")
    assert result.status == "available" and result.mode == "cloze"


@pytest.mark.parametrize("category", ["KANJI", "LISTENING"])
def test_matching_preserves_vocabulary_catalog_categories(category):
    result = decode_quiz_resume_snapshot(matching_questions(), total_questions=3, quiz_type=category)
    assert result.status == "available" and result.mode == "matching"


def test_matching_cannot_reinterpret_vocabulary_as_grammar_progress():
    result = decode_quiz_resume_snapshot(matching_questions(), total_questions=3, quiz_type="GRAMMAR")
    assert result.status == "invalid_snapshot"


@pytest.mark.parametrize("category", ["VOCABULARY", "GRAMMAR"])
def test_legacy_arrange_cannot_silently_change_original_srs_category(category):
    raw = arrange_questions()
    original = deepcopy(raw)
    result = decode_quiz_resume_snapshot(raw, total_questions=3, quiz_type=category)
    assert result.status == "legacy_unavailable" and result.mode == "arrange"
    assert raw == original


@pytest.mark.parametrize(
    "mutation",
    [
        "unknown-mode",
        "non-string-mode",
        "count",
        "duplicate-question",
        "missing-side",
        "mismatched-word",
        "duplicate-pair",
        "foreign-pair",
        "mixed-kind",
        "wrong-token",
        "missing-japanese",
        "malformed-option",
        "wrong-option-id",
        "special-with-options",
    ],
)
def test_invalid_snapshot_is_explicit_and_never_repaired(mutation):
    questions = matching_questions()
    raw = {"mode": "matching", "questions": questions}
    total = 3
    if mutation == "unknown-mode":
        raw["mode"] = "future-mode"
    elif mutation == "non-string-mode":
        raw["mode"] = ["matching"]
    elif mutation == "count":
        total = 4
    elif mutation == "duplicate-question":
        questions[1]["id"] = questions[0]["id"]
    elif mutation == "missing-side":
        del questions[0]["meaningKo"]
    elif mutation == "mismatched-word":
        questions[0]["word"] = "別の単語"
    elif mutation == "duplicate-pair":
        questions[1]["correctOptionId"] = questions[0]["correctOptionId"]
    elif mutation == "foreign-pair":
        raw["matchingPairs"] = [{"id": str(uuid.uuid4()), "word": q["question"], "meaning": q["meaningKo"]} for q in questions]
    elif mutation == "mixed-kind":
        questions[1] = arrange_questions(1)[0]
    elif mutation in {"wrong-token", "missing-japanese"}:
        raw = {"mode": "arrange", "questions": arrange_questions()}
        if mutation == "wrong-token":
            raw["questions"][0]["tokens"] = [42]
        else:
            del raw["questions"][0]["japaneseSentence"]
    else:
        raw = {"questions": choice_questions()}
        if mutation == "malformed-option":
            raw["questions"][0]["options"][0]["text"] = None
        elif mutation == "wrong-option-id":
            raw["questions"][0]["correctOptionId"] = "absent"
        else:
            raw["questions"][0]["type"] = "SENTENCE_ARRANGE"
    original = deepcopy(raw)
    result = decode_quiz_resume_snapshot(raw, total_questions=total)
    assert result.status == "invalid_snapshot" and result.matching_pairs is None
    assert raw == original
