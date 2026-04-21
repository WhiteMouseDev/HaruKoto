from __future__ import annotations

import uuid
from datetime import UTC, datetime
from types import SimpleNamespace

from app.enums import JlptLevel, PartOfSpeech, ReviewStatus, ScenarioCategory
from app.services.admin_content_responses import (
    to_cloze_detail_response,
    to_conversation_detail_response,
    to_grammar_detail_response,
    to_sentence_arrange_detail_response,
    to_vocabulary_detail_response,
)


def test_to_vocabulary_detail_response_maps_enum_values() -> None:
    created_at = datetime(2026, 4, 21, 12, 0, tzinfo=UTC)
    item = SimpleNamespace(
        id=uuid.uuid4(),
        word="食べる",
        reading="たべる",
        meaning_ko="먹다",
        jlpt_level=JlptLevel.N5,
        part_of_speech=PartOfSpeech.VERB,
        example_sentence="寿司を食べる。",
        example_reading="すしをたべる。",
        example_translation="초밥을 먹다.",
        review_status=ReviewStatus.APPROVED,
        created_at=created_at,
    )

    response = to_vocabulary_detail_response(item)

    assert response.id == item.id
    assert response.jlpt_level == "N5"
    assert response.part_of_speech == "VERB"
    assert response.review_status == "approved"
    assert response.updated_at is None


def test_to_grammar_detail_response_preserves_example_sentences() -> None:
    item = SimpleNamespace(
        id=uuid.uuid4(),
        pattern="ている",
        meaning_ko="하고 있다",
        explanation="진행 표현",
        example_sentences=[{"japanese": "勉強している"}],
        jlpt_level=JlptLevel.N5,
        review_status=ReviewStatus.NEEDS_REVIEW,
        created_at=datetime(2026, 4, 21, 12, 0, tzinfo=UTC),
    )

    response = to_grammar_detail_response(item)

    assert response.example_sentences == [{"japanese": "勉強している"}]
    assert response.review_status == "needs_review"


def test_to_quiz_detail_responses_map_shared_fields() -> None:
    created_at = datetime(2026, 4, 21, 12, 0, tzinfo=UTC)
    cloze = SimpleNamespace(
        id=uuid.uuid4(),
        sentence="私は___を食べます。",
        translation="나는 밥을 먹습니다.",
        correct_answer="ご飯",
        options=["ご飯", "水"],
        explanation="목적어 선택",
        jlpt_level=JlptLevel.N5,
        review_status=ReviewStatus.REJECTED,
        created_at=created_at,
    )
    arrange = SimpleNamespace(
        id=uuid.uuid4(),
        korean_sentence="나는 일본어를 공부합니다.",
        japanese_sentence="私は日本語を勉強します。",
        tokens=["私", "は", "日本語", "を", "勉強します"],
        explanation="기본 어순",
        jlpt_level=JlptLevel.N5,
        review_status=ReviewStatus.APPROVED,
        created_at=created_at,
    )

    cloze_response = to_cloze_detail_response(cloze)
    arrange_response = to_sentence_arrange_detail_response(arrange)

    assert cloze_response.correct_answer == "ご飯"
    assert cloze_response.review_status == "rejected"
    assert arrange_response.japanese_sentence == "私は日本語を勉強します。"
    assert arrange_response.review_status == "approved"


def test_to_conversation_detail_response_normalizes_key_expressions() -> None:
    item = SimpleNamespace(
        id=uuid.uuid4(),
        title="카페 주문",
        title_ja="カフェで注文",
        description="카페에서 주문하기",
        situation="카페",
        your_role="손님",
        ai_role="점원",
        system_prompt="대화하세요",
        key_expressions=("お願いします", "ください"),
        category=ScenarioCategory.DAILY,
        review_status=ReviewStatus.APPROVED,
        created_at=datetime(2026, 4, 21, 12, 0, tzinfo=UTC),
    )

    response = to_conversation_detail_response(item)

    assert response.key_expressions == ["お願いします", "ください"]
    assert response.category == "DAILY"
    assert response.updated_at is None
