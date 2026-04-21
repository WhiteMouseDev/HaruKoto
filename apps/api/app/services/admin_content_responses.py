from __future__ import annotations

from typing import Any

from app.schemas.admin_content import (
    ClozeQuestionDetailResponse,
    ConversationDetailResponse,
    GrammarDetailResponse,
    SentenceArrangeDetailResponse,
    VocabularyDetailResponse,
)


def to_vocabulary_detail_response(item: Any) -> VocabularyDetailResponse:
    return VocabularyDetailResponse(
        id=item.id,
        word=item.word,
        reading=item.reading,
        meaning_ko=item.meaning_ko,
        jlpt_level=item.jlpt_level.value,
        part_of_speech=item.part_of_speech.value if item.part_of_speech else None,
        example_sentence=item.example_sentence,
        example_reading=item.example_reading,
        example_translation=item.example_translation,
        review_status=item.review_status.value,
        created_at=item.created_at,
        updated_at=None,
    )


def to_grammar_detail_response(item: Any) -> GrammarDetailResponse:
    return GrammarDetailResponse(
        id=item.id,
        pattern=item.pattern,
        meaning_ko=item.meaning_ko,
        explanation=item.explanation,
        example_sentences=item.example_sentences,
        jlpt_level=item.jlpt_level.value,
        review_status=item.review_status.value,
        created_at=item.created_at,
        updated_at=None,
    )


def to_cloze_detail_response(item: Any) -> ClozeQuestionDetailResponse:
    return ClozeQuestionDetailResponse(
        id=item.id,
        sentence=item.sentence,
        translation=item.translation,
        correct_answer=item.correct_answer,
        options=item.options,
        explanation=item.explanation,
        jlpt_level=item.jlpt_level.value,
        review_status=item.review_status.value,
        created_at=item.created_at,
        updated_at=None,
    )


def to_sentence_arrange_detail_response(item: Any) -> SentenceArrangeDetailResponse:
    return SentenceArrangeDetailResponse(
        id=item.id,
        korean_sentence=item.korean_sentence,
        japanese_sentence=item.japanese_sentence,
        tokens=item.tokens,
        explanation=item.explanation,
        jlpt_level=item.jlpt_level.value,
        review_status=item.review_status.value,
        created_at=item.created_at,
        updated_at=None,
    )


def to_conversation_detail_response(item: Any) -> ConversationDetailResponse:
    return ConversationDetailResponse(
        id=item.id,
        title=item.title,
        title_ja=item.title_ja,
        description=item.description,
        situation=item.situation,
        your_role=item.your_role,
        ai_role=item.ai_role,
        system_prompt=item.system_prompt,
        key_expressions=list(item.key_expressions) if item.key_expressions else None,
        category=item.category.value,
        review_status=item.review_status.value,
        created_at=item.created_at,
        updated_at=None,
    )
