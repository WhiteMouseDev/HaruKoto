from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace

from app.models.enums import KanaType
from app.services.kana_query import (
    build_kana_character_payload,
    build_kana_progress_response,
    build_kana_stage_payload,
)


def test_build_kana_character_payload_includes_progress():
    kana_id = uuid.uuid4()
    reviewed_at = datetime(2026, 4, 21, 9, 0, tzinfo=UTC)
    character = SimpleNamespace(
        id=kana_id,
        kana_type=KanaType.HIRAGANA,
        character="あ",
        romaji="a",
        pronunciation="a",
        row="a",
        column="1",
        stroke_count=3,
        stroke_order=["1", "2", "3"],
        audio_url=None,
        example_word="あめ",
        example_reading="ame",
        example_meaning="비",
        category="basic",
        order=1,
    )
    progress = SimpleNamespace(
        correct_count=2,
        streak=1,
        mastered=False,
        last_reviewed_at=reviewed_at,
    )

    assert build_kana_character_payload(character, progress) == {
        "id": str(kana_id),
        "kanaType": "HIRAGANA",
        "character": "あ",
        "romaji": "a",
        "pronunciation": "a",
        "row": "a",
        "column": "1",
        "strokeCount": 3,
        "strokeOrder": ["1", "2", "3"],
        "audioUrl": None,
        "exampleWord": "あめ",
        "exampleReading": "ame",
        "exampleMeaning": "비",
        "category": "basic",
        "order": 1,
        "progress": {
            "correctCount": 2,
            "streak": 1,
            "mastered": False,
            "lastReviewedAt": reviewed_at.isoformat(),
        },
    }


def test_build_kana_character_payload_defaults_progress_to_none():
    character = SimpleNamespace(
        id=uuid.uuid4(),
        kana_type=KanaType.KATAKANA,
        character="ア",
        romaji="a",
        pronunciation="a",
        row="a",
        column="1",
        stroke_count=2,
        stroke_order=None,
        audio_url=None,
        example_word=None,
        example_reading=None,
        example_meaning=None,
        category="basic",
        order=1,
    )

    assert build_kana_character_payload(character, None)["progress"] is None


def test_build_kana_stage_payload_defaults_first_stage_unlocked():
    first_stage = SimpleNamespace(
        id=uuid.uuid4(),
        kana_type=KanaType.HIRAGANA,
        stage_number=1,
        title="기본 모음",
        description="あいうえお",
        characters=["あ", "い"],
    )
    second_stage = SimpleNamespace(
        id=uuid.uuid4(),
        kana_type=KanaType.HIRAGANA,
        stage_number=2,
        title="K행",
        description="かきくけこ",
        characters=["か", "き"],
    )

    assert build_kana_stage_payload(first_stage, None)["isUnlocked"] is True
    assert build_kana_stage_payload(second_stage, None)["isUnlocked"] is False
    assert build_kana_stage_payload(second_stage, None)["isCompleted"] is False
    assert build_kana_stage_payload(second_stage, None)["quizScore"] is None


def test_build_kana_stage_payload_uses_user_stage_progress():
    stage = SimpleNamespace(
        id=uuid.uuid4(),
        kana_type=KanaType.KATAKANA,
        stage_number=3,
        title="S행",
        description="サシスセソ",
        characters=["サ", "シ"],
    )
    user_stage = SimpleNamespace(
        is_unlocked=True,
        is_completed=True,
        quiz_score=95,
    )

    payload = build_kana_stage_payload(stage, user_stage)

    assert payload["isUnlocked"] is True
    assert payload["isCompleted"] is True
    assert payload["quizScore"] == 95


def test_build_kana_progress_response_uses_zero_for_missing_counts():
    response = build_kana_progress_response(
        totals={KanaType.HIRAGANA: 46},
        learned_map={KanaType.HIRAGANA: 10},
        mastered_map={},
    )

    assert response.hiragana.learned == 10
    assert response.hiragana.mastered == 0
    assert response.hiragana.total == 46
    assert response.katakana.learned == 0
    assert response.katakana.mastered == 0
    assert response.katakana.total == 0
