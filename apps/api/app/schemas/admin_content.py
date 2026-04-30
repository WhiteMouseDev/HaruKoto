from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Literal

from app.schemas.common import CamelModel

# ---------------------------------------------------------------------------
# List view schemas (existing — do not modify)
# ---------------------------------------------------------------------------


class VocabularyAdminItem(CamelModel):
    id: uuid.UUID
    word: str
    reading: str
    meaning_ko: str
    jlpt_level: str
    review_status: str
    created_at: datetime


class GrammarAdminItem(CamelModel):
    id: uuid.UUID
    pattern: str
    explanation: str
    meaning_ko: str
    jlpt_level: str
    review_status: str
    created_at: datetime


class QuizAdminItem(CamelModel):
    id: uuid.UUID
    sentence: str  # sentence for cloze, korean_sentence for sentence_arrange
    quiz_type: str  # "cloze" or "sentence_arrange"
    jlpt_level: str
    review_status: str
    created_at: datetime


class ConversationAdminItem(CamelModel):
    id: uuid.UUID
    title: str
    category: str
    jlpt_level: str | None  # conversation_scenarios has no jlpt_level column
    review_status: str
    created_at: datetime


class ContentStatsItem(CamelModel):
    content_type: str
    needs_review: int
    approved: int
    rejected: int
    total: int


class ContentStatsResponse(CamelModel):
    stats: list[ContentStatsItem]


# ---------------------------------------------------------------------------
# Detail response schemas (for single-item GET)
# ---------------------------------------------------------------------------


class VocabularyDetailResponse(CamelModel):
    id: uuid.UUID
    word: str
    reading: str
    meaning_ko: str
    jlpt_level: str
    part_of_speech: str | None
    example_sentence: str | None
    example_reading: str | None
    example_translation: str | None
    review_status: str
    created_at: datetime
    updated_at: datetime | None


class GrammarDetailResponse(CamelModel):
    id: uuid.UUID
    pattern: str
    meaning_ko: str
    explanation: str | None
    example_sentences: list[Any] | None  # JSON
    jlpt_level: str
    review_status: str
    created_at: datetime
    updated_at: datetime | None


class ClozeQuestionDetailResponse(CamelModel):
    id: uuid.UUID
    sentence: str
    translation: str
    correct_answer: str
    options: list[Any] | None  # JSON
    explanation: str | None
    jlpt_level: str
    review_status: str
    created_at: datetime
    updated_at: datetime | None


class SentenceArrangeDetailResponse(CamelModel):
    id: uuid.UUID
    korean_sentence: str
    japanese_sentence: str
    tokens: list[Any] | None  # JSON
    explanation: str | None
    jlpt_level: str
    review_status: str
    created_at: datetime
    updated_at: datetime | None


class ConversationDetailResponse(CamelModel):
    id: uuid.UUID
    title: str
    title_ja: str | None
    description: str | None
    situation: str | None
    your_role: str | None
    ai_role: str | None
    system_prompt: str | None
    key_expressions: list[Any] | None  # JSON
    category: str
    review_status: str
    created_at: datetime
    updated_at: datetime | None


# ---------------------------------------------------------------------------
# Update request schemas (all fields Optional for PATCH — D-11)
# ---------------------------------------------------------------------------


class VocabularyUpdateRequest(CamelModel):
    word: str | None = None
    reading: str | None = None
    meaning_ko: str | None = None
    part_of_speech: str | None = None
    example_sentence: str | None = None
    example_reading: str | None = None
    example_translation: str | None = None


class GrammarUpdateRequest(CamelModel):
    pattern: str | None = None
    meaning_ko: str | None = None
    explanation: str | None = None


class ClozeQuestionUpdateRequest(CamelModel):
    sentence: str | None = None
    translation: str | None = None
    correct_answer: str | None = None
    options: list[Any] | None = None
    explanation: str | None = None


class SentenceArrangeUpdateRequest(CamelModel):
    korean_sentence: str | None = None
    japanese_sentence: str | None = None
    tokens: list[Any] | None = None
    explanation: str | None = None


class ConversationUpdateRequest(CamelModel):
    title: str | None = None
    title_ja: str | None = None
    description: str | None = None
    situation: str | None = None
    your_role: str | None = None
    ai_role: str | None = None
    system_prompt: str | None = None
    key_expressions: list[Any] | None = None


# ---------------------------------------------------------------------------
# Review and audit log schemas
# ---------------------------------------------------------------------------


class ReviewRequest(CamelModel):
    action: Literal["approve", "reject"]
    reason: str | None = None


class BatchReviewRequest(CamelModel):
    content_type: Literal["vocabulary", "grammar", "cloze", "sentence_arrange", "conversation"]
    ids: list[uuid.UUID]
    action: Literal["approve", "reject"]
    reason: str | None = None


class AuditLogItem(CamelModel):
    id: uuid.UUID
    action: str
    changes: dict[str, Any] | None
    reason: str | None
    reviewer_id: uuid.UUID
    reviewer_email: str
    created_at: datetime


class OkResponse(CamelModel):
    ok: bool = True
    count: int = 0


# ---------------------------------------------------------------------------
# TTS schemas (Phase 4 + Phase 6 per-field TTS)
# ---------------------------------------------------------------------------


class AdminTtsResponse(CamelModel):
    audio_url: str | None
    field: str | None
    provider: str | None


class AudioFieldInfo(CamelModel):
    audio_url: str
    provider: str
    created_at: datetime


class AdminTtsMapResponse(CamelModel):
    audios: dict[str, AudioFieldInfo | None]


class AdminTtsRegenerateRequest(CamelModel):
    content_type: Literal["vocabulary", "grammar", "cloze", "sentence_arrange", "conversation"]
    item_id: str
    field: str  # "reading", "word", "example_sentence", "pattern", "sentence", "japanese_sentence", "situation"


class TtsGenerationStatusSummary(CamelModel):
    missing: int
    generated: int
    approved: int
    rejected: int
    stale: int


class AdminTtsReviewFieldMapping(CamelModel):
    audio_field: Literal[
        "word",
        "reading",
        "japanese",
        "pattern",
        "example_sentence",
        "script_line",
        "question_prompt",
    ]
    admin_field: str


class AdminTtsReviewExportInfo(CamelModel):
    mode: Literal["existing_admin_tts_fields", "requires_admin_extension"]
    content_type: Literal["vocabulary", "grammar", "kana", "example_sentence_pool", "lesson_seed_candidate"]
    field_mappings: list[AdminTtsReviewFieldMapping]
    blockers: list[Literal["admin_tts_field_gap", "admin_content_type_gap", "lesson_seed_admin_surface_gap"]]


class AdminTtsReviewBatchItem(CamelModel):
    batch_id: str
    status: Literal["draft", "review", "approved"]
    review_surface: Literal["admin_existing_tts", "admin_extension_required"]
    source_kind: Literal[
        "topic_vocabulary_fields",
        "topic_grammar_fields",
        "topic_grammar_question_prompts",
        "topic_kana_fields",
        "example_sentence_fields",
        "seed_candidate_script_lines",
        "seed_candidate_question_prompts",
    ]
    target_ids: list[str]
    target_count: int
    required_before_publish_count: int
    generation_status_summary: TtsGenerationStatusSummary
    admin_export: AdminTtsReviewExportInfo
    reviewer_checklist: list[str]
    notes_ko: str


class AdminTtsReviewTargetItem(CamelModel):
    target_id: str
    topic_id: str
    audio_target_type: Literal[
        "vocabulary",
        "grammar",
        "kana",
        "lesson_script",
        "example_sentence",
        "question_prompt",
    ]
    audio_field: Literal[
        "word",
        "reading",
        "japanese",
        "pattern",
        "example_sentence",
        "script_line",
        "question_prompt",
    ]
    text_source: str
    default_speed: float
    required_before_publish: bool
    preferred_voice_id: str | None = None
    generation_status: Literal["missing", "generated", "approved", "rejected", "stale"]
    cache_key_strategy: Literal["provider-model-speed-field-text-hash-v1"]
    notes_ko: str


class AdminTtsReviewBatchSummary(CamelModel):
    total_batches: int
    total_targets: int
    admin_ready_targets: int
    extension_required_targets: int
    required_before_publish_targets: int
    generation_status_summary: TtsGenerationStatusSummary


class AdminTtsReviewBatchListResponse(CamelModel):
    schema_version: int
    status: str
    batches: list[AdminTtsReviewBatchItem]
    summary: AdminTtsReviewBatchSummary


class AdminTtsReviewBatchTargetsResponse(CamelModel):
    schema_version: int
    status: str
    batch: AdminTtsReviewBatchItem
    targets: list[AdminTtsReviewTargetItem]


class AdminTtsReviewGenerationPlanCandidate(CamelModel):
    content_type: Literal["vocabulary", "grammar"]
    lookup_type: Literal["topic_id", "grammar_level_order", "vocabulary_level_order"]
    topic_id: str
    admin_field: str
    jlpt_level: str | None = None
    grammar_order: int | None = None
    vocabulary_order: int | None = None
    content_label: str | None = None
    content_reading: str | None = None
    meaning_ko: str | None = None
    match_type: Literal["exact", "partial", "related"] | None = None
    note_ko: str


class AdminTtsReviewGenerationPlanItem(CamelModel):
    target: AdminTtsReviewTargetItem
    admin_content_type: str
    admin_field: str | None
    operation_status: Literal["ready_after_db_lookup", "manual_mapping_required", "blocked"]
    existing_admin_tts_supported: bool
    candidates: list[AdminTtsReviewGenerationPlanCandidate]
    blocker_codes: list[
        Literal[
            "admin_extension_required",
            "unsupported_admin_tts_field",
            "missing_admin_field_mapping",
            "topic_vocabulary_mapping_required",
            "ambiguous_or_partial_vocabulary_mapping",
            "topic_grammar_mapping_required",
            "ambiguous_or_partial_grammar_mapping",
        ]
    ]
    notes_ko: str


class AdminTtsReviewGenerationPlanSummary(CamelModel):
    total_targets: int
    supported_targets: int
    ready_after_db_lookup_targets: int
    manual_mapping_required_targets: int
    blocked_targets: int


class AdminTtsReviewGenerationPlanResponse(CamelModel):
    schema_version: int
    status: str
    batch: AdminTtsReviewBatchItem
    summary: AdminTtsReviewGenerationPlanSummary
    items: list[AdminTtsReviewGenerationPlanItem]


class AdminTtsReviewExecutePreviewItem(CamelModel):
    target: AdminTtsReviewTargetItem
    admin_content_type: str
    admin_field: str | None
    lookup_status: Literal["resolved", "missing", "ambiguous", "not_lookup_ready", "blocked"]
    can_generate_with_current_service: bool
    candidate: AdminTtsReviewGenerationPlanCandidate | None
    content_item_id: str | None = None
    content_label: str | None = None
    notes_ko: str


class AdminTtsReviewExecutePreviewSummary(CamelModel):
    total_targets: int
    resolved_targets: int
    missing_targets: int
    ambiguous_targets: int
    not_lookup_ready_targets: int
    blocked_targets: int
    generatable_targets: int


class AdminTtsReviewExecutePreviewResponse(CamelModel):
    schema_version: int
    status: str
    batch: AdminTtsReviewBatchItem
    summary: AdminTtsReviewExecutePreviewSummary
    items: list[AdminTtsReviewExecutePreviewItem]


# ---------------------------------------------------------------------------
# Review queue schemas (Phase 5)
# ---------------------------------------------------------------------------


class ReviewQueueItem(CamelModel):
    id: str
    quiz_type: str | None = None  # only for quiz content type: "cloze" or "sentence_arrange"


class ReviewQueueResponse(CamelModel):
    ids: list[ReviewQueueItem]
    total: int
    capped: bool
