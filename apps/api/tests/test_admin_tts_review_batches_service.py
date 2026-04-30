from __future__ import annotations

import json
import uuid
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest

from app.services.admin_tts_review_batches import (
    CURRICULUM_TTS_REVIEW_BATCH_PATH,
    AdminTtsReviewBatchServiceError,
    _default_topic_grammar_map_path,
    _default_topic_vocabulary_map_path,
    _default_tts_review_batch_path,
    _default_tts_target_manifest_path,
    get_admin_tts_review_batch_targets,
    get_admin_tts_review_batches,
    get_admin_tts_review_execute_preview,
    get_admin_tts_review_generation_plan,
)


def test_default_tts_review_batch_path_uses_api_bundle() -> None:
    path = _default_tts_review_batch_path()

    assert path == CURRICULUM_TTS_REVIEW_BATCH_PATH
    assert path.exists()
    assert path.parts[-4:] == ("app", "data", "curriculum", "tts-review-batches.json")


def test_default_tts_target_manifest_path_uses_api_bundle() -> None:
    path = _default_tts_target_manifest_path()

    assert path.exists()
    assert path.parts[-4:] == ("app", "data", "curriculum", "tts-target-manifest.json")


def test_default_topic_grammar_map_path_uses_api_bundle() -> None:
    path = _default_topic_grammar_map_path()

    assert path.exists()
    assert path.parts[-4:] == ("app", "data", "curriculum", "topic-grammar-map.json")


def test_default_topic_vocabulary_map_path_uses_api_bundle() -> None:
    path = _default_topic_vocabulary_map_path()

    assert path.exists()
    assert path.parts[-4:] == ("app", "data", "curriculum", "topic-vocabulary-map.json")


def test_get_admin_tts_review_batches_summarizes_contract(tmp_path: Path) -> None:
    path = _write_contract(tmp_path)

    result = get_admin_tts_review_batches(path=path)

    assert result.schema_version == 1
    assert result.summary.total_batches == 2
    assert result.summary.total_targets == 3
    assert result.summary.admin_ready_targets == 2
    assert result.summary.extension_required_targets == 1
    assert result.summary.required_before_publish_targets == 2
    assert result.summary.generation_status_summary.missing == 3


def test_get_admin_tts_review_batches_filters_review_surface(tmp_path: Path) -> None:
    path = _write_contract(tmp_path)

    result = get_admin_tts_review_batches(review_surface="admin_existing_tts", path=path)

    assert [batch.batch_id for batch in result.batches] == ["tts-review-admin-vocabulary-fields"]
    assert result.summary.total_targets == 2
    assert result.summary.extension_required_targets == 0


def test_get_admin_tts_review_batch_targets_returns_ordered_targets(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path)
    manifest_path = _write_manifest(tmp_path)

    result = get_admin_tts_review_batch_targets(
        "tts-review-admin-vocabulary-fields",
        batch_path=batch_path,
        manifest_path=manifest_path,
    )

    assert result.batch.batch_id == "tts-review-admin-vocabulary-fields"
    assert [target.target_id for target in result.targets] == ["tts-vocabulary-word", "tts-vocabulary-reading"]
    assert result.targets[0].audio_field == "word"
    assert result.targets[0].required_before_publish is True


def test_get_admin_tts_review_batch_targets_rejects_missing_batch(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path)
    manifest_path = _write_manifest(tmp_path)

    with pytest.raises(AdminTtsReviewBatchServiceError) as exc_info:
        get_admin_tts_review_batch_targets(
            "missing-batch",
            batch_path=batch_path,
            manifest_path=manifest_path,
        )

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "TTS review batch not found"


def test_get_admin_tts_review_batch_targets_rejects_missing_manifest_target(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path)
    manifest_path = _write_manifest(tmp_path, targets=[])

    with pytest.raises(AdminTtsReviewBatchServiceError) as exc_info:
        get_admin_tts_review_batch_targets(
            "tts-review-admin-vocabulary-fields",
            batch_path=batch_path,
            manifest_path=manifest_path,
        )

    assert exc_info.value.status_code == 500
    assert "references missing target ids" in exc_info.value.detail


def test_get_admin_tts_review_generation_plan_marks_vocabulary_topics_manual(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path)
    manifest_path = _write_manifest(tmp_path)
    grammar_map_path = _write_topic_grammar_map(tmp_path)
    vocabulary_map_path = _write_topic_vocabulary_map(tmp_path)

    result = get_admin_tts_review_generation_plan(
        "tts-review-admin-vocabulary-fields",
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=grammar_map_path,
        topic_vocabulary_map_path=vocabulary_map_path,
    )

    assert result.summary.supported_targets == 2
    assert result.summary.ready_after_db_lookup_targets == 0
    assert result.summary.manual_mapping_required_targets == 2
    assert result.items[0].operation_status == "manual_mapping_required"
    assert result.items[0].blocker_codes == ["topic_vocabulary_mapping_required"]
    assert result.items[0].candidates == []


def test_get_admin_tts_review_generation_plan_marks_exact_vocabulary_ready(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path, _vocabulary_contract())
    manifest_path = _write_manifest(tmp_path, _vocabulary_manifest_targets())
    grammar_map_path = _write_topic_grammar_map(tmp_path)
    vocabulary_map_path = _write_topic_vocabulary_map(
        tmp_path,
        _topic_vocabulary_mappings(match_type="exact"),
    )

    result = get_admin_tts_review_generation_plan(
        "tts-review-admin-vocabulary-fields",
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=grammar_map_path,
        topic_vocabulary_map_path=vocabulary_map_path,
    )

    assert result.summary.supported_targets == 1
    assert result.summary.ready_after_db_lookup_targets == 1
    assert result.summary.manual_mapping_required_targets == 0
    assert result.items[0].operation_status == "ready_after_db_lookup"
    assert result.items[0].candidates[0].lookup_type == "vocabulary_level_order"
    assert result.items[0].candidates[0].vocabulary_order == 309


def test_get_admin_tts_review_generation_plan_marks_exact_grammar_ready(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path, _grammar_contract())
    manifest_path = _write_manifest(tmp_path, _grammar_manifest_targets())
    grammar_map_path = _write_topic_grammar_map(tmp_path, _topic_grammar_mappings(match_type="exact"))
    vocabulary_map_path = _write_topic_vocabulary_map(tmp_path)

    result = get_admin_tts_review_generation_plan(
        "tts-review-admin-grammar-fields",
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=grammar_map_path,
        topic_vocabulary_map_path=vocabulary_map_path,
    )

    assert result.summary.supported_targets == 1
    assert result.summary.ready_after_db_lookup_targets == 1
    assert result.summary.manual_mapping_required_targets == 0
    assert result.items[0].operation_status == "ready_after_db_lookup"
    assert result.items[0].candidates[0].lookup_type == "grammar_level_order"
    assert result.items[0].candidates[0].grammar_order == 1


def test_get_admin_tts_review_generation_plan_blocks_extension_required_batch(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path)
    manifest_path = _write_manifest(tmp_path)
    grammar_map_path = _write_topic_grammar_map(tmp_path)
    vocabulary_map_path = _write_topic_vocabulary_map(tmp_path)

    result = get_admin_tts_review_generation_plan(
        "tts-review-gap-seed-script-lines",
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=grammar_map_path,
        topic_vocabulary_map_path=vocabulary_map_path,
    )

    assert result.summary.blocked_targets == 1
    assert result.items[0].operation_status == "blocked"
    assert result.items[0].blocker_codes == ["admin_extension_required"]


@pytest.mark.asyncio
async def test_get_admin_tts_review_execute_preview_resolves_exact_grammar(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path, _grammar_contract())
    manifest_path = _write_manifest(tmp_path, _grammar_manifest_targets())
    grammar_map_path = _write_topic_grammar_map(tmp_path, _topic_grammar_mappings(match_type="exact"))
    vocabulary_map_path = _write_topic_vocabulary_map(tmp_path)
    grammar_id = uuid.uuid4()
    db = _FakeDb([_ScalarsResult([SimpleNamespace(id=grammar_id, pattern="〜です")])])

    result = await get_admin_tts_review_execute_preview(
        db,  # type: ignore[arg-type]
        "tts-review-admin-grammar-fields",
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=grammar_map_path,
        topic_vocabulary_map_path=vocabulary_map_path,
    )

    assert result.summary.resolved_targets == 1
    assert result.summary.generatable_targets == 1
    assert result.items[0].lookup_status == "resolved"
    assert result.items[0].content_item_id == str(grammar_id)
    assert result.items[0].content_label == "〜です"
    assert db.execute_calls == 1


@pytest.mark.asyncio
async def test_get_admin_tts_review_execute_preview_marks_missing_grammar(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path, _grammar_contract())
    manifest_path = _write_manifest(tmp_path, _grammar_manifest_targets())
    grammar_map_path = _write_topic_grammar_map(tmp_path, _topic_grammar_mappings(match_type="exact"))
    vocabulary_map_path = _write_topic_vocabulary_map(tmp_path)
    db = _FakeDb([_ScalarsResult([])])

    result = await get_admin_tts_review_execute_preview(
        db,  # type: ignore[arg-type]
        "tts-review-admin-grammar-fields",
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=grammar_map_path,
        topic_vocabulary_map_path=vocabulary_map_path,
    )

    assert result.summary.missing_targets == 1
    assert result.summary.generatable_targets == 0
    assert result.items[0].lookup_status == "missing"
    assert result.items[0].content_item_id is None


@pytest.mark.asyncio
async def test_get_admin_tts_review_execute_preview_resolves_exact_vocabulary(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path, _vocabulary_contract())
    manifest_path = _write_manifest(tmp_path, _vocabulary_manifest_targets())
    grammar_map_path = _write_topic_grammar_map(tmp_path)
    vocabulary_map_path = _write_topic_vocabulary_map(
        tmp_path,
        _topic_vocabulary_mappings(match_type="exact"),
    )
    vocabulary_id = uuid.uuid4()
    db = _FakeDb([_ScalarsResult([SimpleNamespace(id=vocabulary_id, word="漢字")])])

    result = await get_admin_tts_review_execute_preview(
        db,  # type: ignore[arg-type]
        "tts-review-admin-vocabulary-fields",
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=grammar_map_path,
        topic_vocabulary_map_path=vocabulary_map_path,
    )

    assert result.summary.resolved_targets == 1
    assert result.summary.generatable_targets == 1
    assert result.items[0].lookup_status == "resolved"
    assert result.items[0].content_item_id == str(vocabulary_id)
    assert result.items[0].content_label == "漢字"
    assert db.execute_calls == 1


@pytest.mark.asyncio
async def test_get_admin_tts_review_execute_preview_skips_manual_vocabulary_lookup(tmp_path: Path) -> None:
    batch_path = _write_contract(tmp_path)
    manifest_path = _write_manifest(tmp_path)
    grammar_map_path = _write_topic_grammar_map(tmp_path)
    vocabulary_map_path = _write_topic_vocabulary_map(tmp_path)
    db = _FakeDb([])

    result = await get_admin_tts_review_execute_preview(
        db,  # type: ignore[arg-type]
        "tts-review-admin-vocabulary-fields",
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=grammar_map_path,
        topic_vocabulary_map_path=vocabulary_map_path,
    )

    assert result.summary.not_lookup_ready_targets == 2
    assert result.summary.generatable_targets == 0
    assert result.items[0].lookup_status == "not_lookup_ready"
    assert db.execute_calls == 0


def test_get_admin_tts_review_batches_rejects_mismatched_counts(tmp_path: Path) -> None:
    path = tmp_path / "tts-review-batches.json"
    contract = _contract()
    contract["batches"][0]["targetCount"] = 99
    path.write_text(json.dumps(contract), encoding="utf-8")

    with pytest.raises(AdminTtsReviewBatchServiceError) as exc_info:
        get_admin_tts_review_batches(path=path)

    assert exc_info.value.status_code == 500
    assert "mismatched targetCount" in exc_info.value.detail


def test_get_admin_tts_review_batches_rejects_missing_contract(tmp_path: Path) -> None:
    with pytest.raises(AdminTtsReviewBatchServiceError) as exc_info:
        get_admin_tts_review_batches(path=tmp_path / "missing.json")

    assert exc_info.value.status_code == 500
    assert exc_info.value.detail == "TTS review batch contract is missing"


def _write_contract(tmp_path: Path, contract: dict[str, object] | None = None) -> Path:
    path = tmp_path / "tts-review-batches.json"
    path.write_text(json.dumps(contract or _contract()), encoding="utf-8")
    return path


def _write_manifest(tmp_path: Path, targets: list[dict[str, object]] | None = None) -> Path:
    path = tmp_path / "tts-target-manifest.json"
    path.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "status": "draft",
                "targets": targets if targets is not None else _manifest_targets(),
            }
        ),
        encoding="utf-8",
    )
    return path


def _write_topic_grammar_map(tmp_path: Path, mappings: list[dict[str, object]] | None = None) -> Path:
    path = tmp_path / "topic-grammar-map.json"
    path.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "status": "draft",
                "mappings": mappings if mappings is not None else [],
            }
        ),
        encoding="utf-8",
    )
    return path


def _write_topic_vocabulary_map(tmp_path: Path, mappings: list[dict[str, object]] | None = None) -> Path:
    path = tmp_path / "topic-vocabulary-map.json"
    path.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "status": "draft",
                "mappings": mappings if mappings is not None else [],
            }
        ),
        encoding="utf-8",
    )
    return path


def _manifest_targets() -> list[dict[str, object]]:
    return [
        {
            "targetId": "tts-vocabulary-word",
            "topicId": "topic-personal-pronouns",
            "audioTargetType": "vocabulary",
            "audioField": "word",
            "textSource": "curriculum-topics:topic-personal-pronouns:word",
            "defaultSpeed": 0.9,
            "requiredBeforePublish": True,
            "generationStatus": "missing",
            "cacheKeyStrategy": "provider-model-speed-field-text-hash-v1",
            "notesKo": "Manifest target.",
        },
        {
            "targetId": "tts-vocabulary-reading",
            "topicId": "topic-personal-pronouns",
            "audioTargetType": "vocabulary",
            "audioField": "reading",
            "textSource": "curriculum-topics:topic-personal-pronouns:reading",
            "defaultSpeed": 0.9,
            "requiredBeforePublish": True,
            "preferredVoiceId": "japanese_female_1",
            "generationStatus": "missing",
            "cacheKeyStrategy": "provider-model-speed-field-text-hash-v1",
            "notesKo": "Manifest target.",
        },
        {
            "targetId": "tts-seed-script-1",
            "topicId": "topic-personal-pronouns",
            "audioTargetType": "lesson_script",
            "audioField": "script_line",
            "textSource": "lesson-seed-candidates:lsc-personal-pronouns-001:script:1",
            "defaultSpeed": 0.9,
            "requiredBeforePublish": True,
            "generationStatus": "missing",
            "cacheKeyStrategy": "provider-model-speed-field-text-hash-v1",
            "notesKo": "Manifest target.",
        },
    ]


def _grammar_manifest_targets() -> list[dict[str, object]]:
    return [
        {
            "targetId": "tts-desu-copula-pattern",
            "topicId": "topic-desu-copula",
            "audioTargetType": "grammar",
            "audioField": "pattern",
            "textSource": "curriculum-topics:topic-desu-copula:pattern",
            "defaultSpeed": 0.9,
            "requiredBeforePublish": False,
            "generationStatus": "missing",
            "cacheKeyStrategy": "provider-model-speed-field-text-hash-v1",
            "notesKo": "Manifest target.",
        }
    ]


def _vocabulary_manifest_targets() -> list[dict[str, object]]:
    return [
        {
            "targetId": "tts-kanji-reading-basics-word",
            "topicId": "topic-kanji-reading-basics",
            "audioTargetType": "vocabulary",
            "audioField": "word",
            "textSource": "curriculum-topics:topic-kanji-reading-basics:word",
            "defaultSpeed": 0.9,
            "requiredBeforePublish": True,
            "generationStatus": "missing",
            "cacheKeyStrategy": "provider-model-speed-field-text-hash-v1",
            "notesKo": "Manifest target.",
        }
    ]


def _topic_grammar_mappings(*, match_type: str) -> list[dict[str, object]]:
    return [
        {
            "topicId": "topic-desu-copula",
            "grammarLevel": "N5",
            "grammarOrder": 1,
            "matchType": match_type,
            "notesKo": "PDF 008 です coverage anchor",
        }
    ]


def _topic_vocabulary_mappings(*, match_type: str) -> list[dict[str, object]]:
    return [
        {
            "topicId": "topic-kanji-reading-basics",
            "vocabularyLevel": "N5",
            "vocabularyOrder": 309,
            "matchType": match_type,
            "notesKo": "PDF 017 한자 읽기 coverage anchor",
        }
    ]


def _grammar_contract() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "status": "draft",
        "batches": [
            {
                "batchId": "tts-review-admin-grammar-fields",
                "status": "draft",
                "reviewSurface": "admin_existing_tts",
                "sourceKind": "topic_grammar_fields",
                "targetIds": ["tts-desu-copula-pattern"],
                "targetCount": 1,
                "requiredBeforePublishCount": 0,
                "generationStatusSummary": {
                    "missing": 1,
                    "generated": 0,
                    "approved": 0,
                    "rejected": 0,
                    "stale": 0,
                },
                "adminExport": {
                    "mode": "existing_admin_tts_fields",
                    "contentType": "grammar",
                    "fieldMappings": [{"audioField": "pattern", "adminField": "pattern"}],
                    "blockers": [],
                },
                "reviewerChecklist": ["Check current admin grammar fields."],
                "notesKo": "현재 admin grammar TTS 필드와 매핑된다.",
            }
        ],
    }


def _vocabulary_contract() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "status": "draft",
        "batches": [
            {
                "batchId": "tts-review-admin-vocabulary-fields",
                "status": "draft",
                "reviewSurface": "admin_existing_tts",
                "sourceKind": "topic_vocabulary_fields",
                "targetIds": ["tts-kanji-reading-basics-word"],
                "targetCount": 1,
                "requiredBeforePublishCount": 1,
                "generationStatusSummary": {
                    "missing": 1,
                    "generated": 0,
                    "approved": 0,
                    "rejected": 0,
                    "stale": 0,
                },
                "adminExport": {
                    "mode": "existing_admin_tts_fields",
                    "contentType": "vocabulary",
                    "fieldMappings": [{"audioField": "word", "adminField": "word"}],
                    "blockers": [],
                },
                "reviewerChecklist": ["Check current admin vocabulary fields."],
                "notesKo": "현재 admin vocabulary TTS 필드와 매핑된다.",
            }
        ],
    }


def _contract() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "status": "draft",
        "batches": [
            {
                "batchId": "tts-review-admin-vocabulary-fields",
                "status": "draft",
                "reviewSurface": "admin_existing_tts",
                "sourceKind": "topic_vocabulary_fields",
                "targetIds": ["tts-vocabulary-word", "tts-vocabulary-reading"],
                "targetCount": 2,
                "requiredBeforePublishCount": 2,
                "generationStatusSummary": {
                    "missing": 2,
                    "generated": 0,
                    "approved": 0,
                    "rejected": 0,
                    "stale": 0,
                },
                "adminExport": {
                    "mode": "existing_admin_tts_fields",
                    "contentType": "vocabulary",
                    "fieldMappings": [
                        {"audioField": "word", "adminField": "word"},
                        {"audioField": "reading", "adminField": "reading"},
                    ],
                    "blockers": [],
                },
                "reviewerChecklist": ["Check current admin vocabulary fields."],
                "notesKo": "현재 admin vocabulary TTS 필드와 매핑된다.",
            },
            {
                "batchId": "tts-review-gap-seed-script-lines",
                "status": "draft",
                "reviewSurface": "admin_extension_required",
                "sourceKind": "seed_candidate_script_lines",
                "targetIds": ["tts-seed-script-1"],
                "targetCount": 1,
                "requiredBeforePublishCount": 0,
                "generationStatusSummary": {
                    "missing": 1,
                    "generated": 0,
                    "approved": 0,
                    "rejected": 0,
                    "stale": 0,
                },
                "adminExport": {
                    "mode": "requires_admin_extension",
                    "contentType": "lesson_seed_candidate",
                    "fieldMappings": [{"audioField": "script_line", "adminField": "script_line"}],
                    "blockers": ["lesson_seed_admin_surface_gap"],
                },
                "reviewerChecklist": ["Check lesson seed admin surface."],
                "notesKo": "Seed candidate script line 오디오는 별도 surface가 필요하다.",
            },
        ],
    }


class _FakeDb:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.execute_calls = 0

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)


class _ScalarsResult:
    def __init__(self, items: list[Any]) -> None:
        self._items = items

    def scalars(self) -> _ScalarsResult:
        return self

    def all(self) -> list[Any]:
        return self._items
