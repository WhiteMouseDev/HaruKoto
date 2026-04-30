from __future__ import annotations

import json
from pathlib import Path
from typing import Literal

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.enums import JlptLevel
from app.models import Grammar, Vocabulary
from app.schemas.admin_content import (
    AdminTtsReviewBatchItem,
    AdminTtsReviewBatchListResponse,
    AdminTtsReviewBatchSummary,
    AdminTtsReviewBatchTargetsResponse,
    AdminTtsReviewExecutePreviewItem,
    AdminTtsReviewExecutePreviewResponse,
    AdminTtsReviewExecutePreviewSummary,
    AdminTtsReviewGenerationPlanCandidate,
    AdminTtsReviewGenerationPlanItem,
    AdminTtsReviewGenerationPlanResponse,
    AdminTtsReviewGenerationPlanSummary,
    AdminTtsReviewTargetItem,
    TtsGenerationStatusSummary,
)
from app.services.admin_tts import TTS_FIELDS

TtsReviewSurface = Literal["admin_existing_tts", "admin_extension_required"]


def _default_tts_review_batch_path() -> Path:
    return _default_curriculum_contract_path("tts-review-batches.json")


def _default_tts_target_manifest_path() -> Path:
    return _default_curriculum_contract_path("tts-target-manifest.json")


def _default_topic_grammar_map_path() -> Path:
    return _default_curriculum_contract_path("topic-grammar-map.json")


def _default_topic_vocabulary_map_path() -> Path:
    return _default_curriculum_contract_path("topic-vocabulary-map.json")


def _default_curriculum_contract_path(file_name: str) -> Path:
    service_file = Path(__file__).resolve()
    bundled_path = service_file.parents[1] / "data/curriculum" / file_name
    if bundled_path.exists():
        return bundled_path

    for parent in service_file.parents:
        candidate = parent / "packages/database/data/curriculum" / file_name
        if candidate.exists():
            return candidate
    return bundled_path


CURRICULUM_TTS_REVIEW_BATCH_PATH = _default_tts_review_batch_path()
CURRICULUM_TTS_TARGET_MANIFEST_PATH = _default_tts_target_manifest_path()
CURRICULUM_TOPIC_GRAMMAR_MAP_PATH = _default_topic_grammar_map_path()
CURRICULUM_TOPIC_VOCABULARY_MAP_PATH = _default_topic_vocabulary_map_path()


class AdminTtsReviewBatchServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


def get_admin_tts_review_batches(
    *,
    review_surface: TtsReviewSurface | None = None,
    path: Path = CURRICULUM_TTS_REVIEW_BATCH_PATH,
) -> AdminTtsReviewBatchListResponse:
    """Load generated curriculum TTS review batches for admin read-only review."""
    schema_version, status, batches = _load_tts_review_batches(path)

    filtered_batches = [batch for batch in batches if review_surface is None or batch.review_surface == review_surface]

    return AdminTtsReviewBatchListResponse(
        schema_version=schema_version,
        status=status,
        batches=filtered_batches,
        summary=_build_summary(filtered_batches),
    )


def get_admin_tts_review_batch_targets(
    batch_id: str,
    *,
    batch_path: Path = CURRICULUM_TTS_REVIEW_BATCH_PATH,
    manifest_path: Path = CURRICULUM_TTS_TARGET_MANIFEST_PATH,
) -> AdminTtsReviewBatchTargetsResponse:
    """Return ordered target metadata for one generated TTS review batch."""
    schema_version, status, batches = _load_tts_review_batches(batch_path)
    batch = next((item for item in batches if item.batch_id == batch_id), None)
    if batch is None:
        raise AdminTtsReviewBatchServiceError(status_code=404, detail="TTS review batch not found")

    targets_by_id = _load_tts_target_manifest(manifest_path)
    missing_target_ids = [target_id for target_id in batch.target_ids if target_id not in targets_by_id]
    if missing_target_ids:
        raise AdminTtsReviewBatchServiceError(
            status_code=500,
            detail=f"TTS review batch {batch.batch_id} references missing target ids",
        )

    return AdminTtsReviewBatchTargetsResponse(
        schema_version=schema_version,
        status=status,
        batch=batch,
        targets=[targets_by_id[target_id] for target_id in batch.target_ids],
    )


def get_admin_tts_review_generation_plan(
    batch_id: str,
    *,
    batch_path: Path = CURRICULUM_TTS_REVIEW_BATCH_PATH,
    manifest_path: Path = CURRICULUM_TTS_TARGET_MANIFEST_PATH,
    topic_grammar_map_path: Path = CURRICULUM_TOPIC_GRAMMAR_MAP_PATH,
    topic_vocabulary_map_path: Path = CURRICULUM_TOPIC_VOCABULARY_MAP_PATH,
) -> AdminTtsReviewGenerationPlanResponse:
    """Dry-run existing-admin TTS generation feasibility without writing audio."""
    target_response = get_admin_tts_review_batch_targets(
        batch_id,
        batch_path=batch_path,
        manifest_path=manifest_path,
    )
    grammar_candidates_by_topic = _load_topic_grammar_candidates(topic_grammar_map_path)
    vocabulary_candidates_by_topic = _load_topic_vocabulary_candidates(topic_vocabulary_map_path)
    items = [
        _build_generation_plan_item(
            target,
            batch=target_response.batch,
            grammar_candidates_by_topic=grammar_candidates_by_topic,
            vocabulary_candidates_by_topic=vocabulary_candidates_by_topic,
        )
        for target in target_response.targets
    ]

    return AdminTtsReviewGenerationPlanResponse(
        schema_version=target_response.schema_version,
        status=target_response.status,
        batch=target_response.batch,
        summary=_build_generation_plan_summary(items),
        items=items,
    )


async def get_admin_tts_review_execute_preview(
    db: AsyncSession,
    batch_id: str,
    *,
    batch_path: Path = CURRICULUM_TTS_REVIEW_BATCH_PATH,
    manifest_path: Path = CURRICULUM_TTS_TARGET_MANIFEST_PATH,
    topic_grammar_map_path: Path = CURRICULUM_TOPIC_GRAMMAR_MAP_PATH,
    topic_vocabulary_map_path: Path = CURRICULUM_TOPIC_VOCABULARY_MAP_PATH,
) -> AdminTtsReviewExecutePreviewResponse:
    """Resolve dry-run items to current admin DB rows without generating audio."""
    plan = get_admin_tts_review_generation_plan(
        batch_id,
        batch_path=batch_path,
        manifest_path=manifest_path,
        topic_grammar_map_path=topic_grammar_map_path,
        topic_vocabulary_map_path=topic_vocabulary_map_path,
    )
    items = [await _build_execute_preview_item(db, item) for item in plan.items]

    return AdminTtsReviewExecutePreviewResponse(
        schema_version=plan.schema_version,
        status=plan.status,
        batch=plan.batch,
        summary=_build_execute_preview_summary(items),
        items=items,
    )


def _load_tts_review_batches(path: Path) -> tuple[int, str, list[AdminTtsReviewBatchItem]]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="TTS review batch contract is missing") from exc
    except json.JSONDecodeError as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="TTS review batch contract is invalid JSON") from exc

    try:
        schema_version = int(raw["schemaVersion"])
        status = str(raw["status"])
        batches = [AdminTtsReviewBatchItem.model_validate(batch) for batch in raw["batches"]]
    except (KeyError, TypeError, ValueError, ValidationError) as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="TTS review batch contract is malformed") from exc

    _validate_batch_counts(batches)

    return schema_version, status, batches


def _load_tts_target_manifest(path: Path) -> dict[str, AdminTtsReviewTargetItem]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="TTS target manifest contract is missing") from exc
    except json.JSONDecodeError as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="TTS target manifest contract is invalid JSON") from exc

    try:
        targets = [AdminTtsReviewTargetItem.model_validate(target) for target in raw["targets"]]
    except (KeyError, TypeError, ValueError, ValidationError) as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="TTS target manifest contract is malformed") from exc

    return {target.target_id: target for target in targets}


def _load_topic_grammar_candidates(path: Path) -> dict[str, list[AdminTtsReviewGenerationPlanCandidate]]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="Topic grammar map contract is missing") from exc
    except json.JSONDecodeError as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="Topic grammar map contract is invalid JSON") from exc

    candidates_by_topic: dict[str, list[AdminTtsReviewGenerationPlanCandidate]] = {}
    try:
        mappings = raw["mappings"]
        for mapping in mappings:
            topic_id = str(mapping["topicId"])
            candidates_by_topic.setdefault(topic_id, []).append(
                AdminTtsReviewGenerationPlanCandidate(
                    content_type="grammar",
                    lookup_type="grammar_level_order",
                    topic_id=topic_id,
                    admin_field="",
                    jlpt_level=str(mapping["grammarLevel"]),
                    grammar_order=int(mapping["grammarOrder"]),
                    match_type=str(mapping["matchType"]),
                    note_ko=str(mapping.get("notesKo") or "Topic grammar map candidate."),
                )
            )
    except (KeyError, TypeError, ValueError, ValidationError) as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="Topic grammar map contract is malformed") from exc

    return candidates_by_topic


def _load_topic_vocabulary_candidates(path: Path) -> dict[str, list[AdminTtsReviewGenerationPlanCandidate]]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="Topic vocabulary map contract is missing") from exc
    except json.JSONDecodeError as exc:
        raise AdminTtsReviewBatchServiceError(
            status_code=500,
            detail="Topic vocabulary map contract is invalid JSON",
        ) from exc

    candidates_by_topic: dict[str, list[AdminTtsReviewGenerationPlanCandidate]] = {}
    try:
        mappings = raw["mappings"]
        for mapping in mappings:
            topic_id = str(mapping["topicId"])
            candidates_by_topic.setdefault(topic_id, []).append(
                AdminTtsReviewGenerationPlanCandidate(
                    content_type="vocabulary",
                    lookup_type="vocabulary_level_order",
                    topic_id=topic_id,
                    admin_field="",
                    jlpt_level=str(mapping["vocabularyLevel"]),
                    vocabulary_order=int(mapping["vocabularyOrder"]),
                    content_label=str(mapping["word"]),
                    content_reading=str(mapping["reading"]),
                    meaning_ko=str(mapping["meaningKo"]),
                    match_type=str(mapping["matchType"]),
                    note_ko=str(mapping.get("notesKo") or "Topic vocabulary map candidate."),
                )
            )
    except (KeyError, TypeError, ValueError, ValidationError) as exc:
        raise AdminTtsReviewBatchServiceError(status_code=500, detail="Topic vocabulary map contract is malformed") from exc

    return candidates_by_topic


def _build_generation_plan_item(
    target: AdminTtsReviewTargetItem,
    *,
    batch: AdminTtsReviewBatchItem,
    grammar_candidates_by_topic: dict[str, list[AdminTtsReviewGenerationPlanCandidate]],
    vocabulary_candidates_by_topic: dict[str, list[AdminTtsReviewGenerationPlanCandidate]],
) -> AdminTtsReviewGenerationPlanItem:
    admin_content_type = batch.admin_export.content_type
    admin_field = _admin_field_for_target(batch, target)
    existing_admin_tts_supported = admin_field in TTS_FIELDS.get(admin_content_type, [])
    blocker_codes: list[str] = []
    candidates: list[AdminTtsReviewGenerationPlanCandidate] = []

    if batch.admin_export.mode != "existing_admin_tts_fields":
        return AdminTtsReviewGenerationPlanItem(
            target=target,
            admin_content_type=admin_content_type,
            admin_field=admin_field,
            operation_status="blocked",
            existing_admin_tts_supported=False,
            candidates=[],
            blocker_codes=["admin_extension_required"],
            notes_ko="현재 admin TTS surface가 이 batch를 생성할 수 없어 surface 확장이 먼저 필요하다.",
        )

    if admin_field is None:
        blocker_codes.append("missing_admin_field_mapping")
    if not existing_admin_tts_supported:
        blocker_codes.append("unsupported_admin_tts_field")
    if blocker_codes:
        return AdminTtsReviewGenerationPlanItem(
            target=target,
            admin_content_type=admin_content_type,
            admin_field=admin_field,
            operation_status="blocked",
            existing_admin_tts_supported=existing_admin_tts_supported,
            candidates=[],
            blocker_codes=blocker_codes,
            notes_ko="Review batch field mapping이 현재 admin TTS service 필드와 맞지 않는다.",
        )

    if admin_content_type == "vocabulary":
        candidates = [
            candidate.model_copy(update={"admin_field": admin_field})
            for candidate in vocabulary_candidates_by_topic.get(target.topic_id, [])
        ]
        if len(candidates) == 1 and candidates[0].match_type == "exact":
            return AdminTtsReviewGenerationPlanItem(
                target=target,
                admin_content_type=admin_content_type,
                admin_field=admin_field,
                operation_status="ready_after_db_lookup",
                existing_admin_tts_supported=True,
                candidates=candidates,
                blocker_codes=[],
                notes_ko="단일 exact vocabulary mapping이 있어 DB에서 vocabulary id를 조회하면 기존 admin TTS service를 호출할 수 있다.",
            )
        blocker_code = "topic_vocabulary_mapping_required" if not candidates else "ambiguous_or_partial_vocabulary_mapping"
        return AdminTtsReviewGenerationPlanItem(
            target=target,
            admin_content_type=admin_content_type,
            admin_field=admin_field,
            operation_status="manual_mapping_required",
            existing_admin_tts_supported=True,
            candidates=candidates,
            blocker_codes=[blocker_code],
            notes_ko="필드는 지원되지만 topic이 0개 또는 여러/partial vocabulary row에 연결되어 생성 전 수동 매핑 확정이 필요하다.",
        )

    if admin_content_type == "grammar":
        candidates = [
            candidate.model_copy(update={"admin_field": admin_field}) for candidate in grammar_candidates_by_topic.get(target.topic_id, [])
        ]
        if len(candidates) == 1 and candidates[0].match_type == "exact":
            return AdminTtsReviewGenerationPlanItem(
                target=target,
                admin_content_type=admin_content_type,
                admin_field=admin_field,
                operation_status="ready_after_db_lookup",
                existing_admin_tts_supported=True,
                candidates=candidates,
                blocker_codes=[],
                notes_ko="단일 exact grammar mapping이 있어 DB에서 grammar id를 조회하면 기존 admin TTS service를 호출할 수 있다.",
            )

        blocker_code = "topic_grammar_mapping_required" if not candidates else "ambiguous_or_partial_grammar_mapping"
        return AdminTtsReviewGenerationPlanItem(
            target=target,
            admin_content_type=admin_content_type,
            admin_field=admin_field,
            operation_status="manual_mapping_required",
            existing_admin_tts_supported=True,
            candidates=candidates,
            blocker_codes=[blocker_code],
            notes_ko="필드는 지원되지만 topic이 0개 또는 여러/partial grammar row에 연결되어 생성 전 수동 매핑 확정이 필요하다.",
        )

    return AdminTtsReviewGenerationPlanItem(
        target=target,
        admin_content_type=admin_content_type,
        admin_field=admin_field,
        operation_status="blocked",
        existing_admin_tts_supported=False,
        candidates=[],
        blocker_codes=["unsupported_admin_tts_field"],
        notes_ko="현재 admin TTS service가 이 content type을 지원하지 않는다.",
    )


def _admin_field_for_target(batch: AdminTtsReviewBatchItem, target: AdminTtsReviewTargetItem) -> str | None:
    for mapping in batch.admin_export.field_mappings:
        if mapping.audio_field == target.audio_field:
            return mapping.admin_field
    return None


def _build_generation_plan_summary(
    items: list[AdminTtsReviewGenerationPlanItem],
) -> AdminTtsReviewGenerationPlanSummary:
    return AdminTtsReviewGenerationPlanSummary(
        total_targets=len(items),
        supported_targets=sum(1 for item in items if item.existing_admin_tts_supported),
        ready_after_db_lookup_targets=sum(1 for item in items if item.operation_status == "ready_after_db_lookup"),
        manual_mapping_required_targets=sum(1 for item in items if item.operation_status == "manual_mapping_required"),
        blocked_targets=sum(1 for item in items if item.operation_status == "blocked"),
    )


async def _build_execute_preview_item(
    db: AsyncSession,
    item: AdminTtsReviewGenerationPlanItem,
) -> AdminTtsReviewExecutePreviewItem:
    if item.operation_status == "blocked":
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="blocked",
            can_generate_with_current_service=False,
            candidate=None,
            notes_ko=item.notes_ko,
        )

    if item.operation_status != "ready_after_db_lookup" or not item.candidates:
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="not_lookup_ready",
            can_generate_with_current_service=False,
            candidate=item.candidates[0] if item.candidates else None,
            notes_ko=item.notes_ko,
        )

    candidate = item.candidates[0]
    if candidate.content_type == "vocabulary":
        return await _build_vocabulary_execute_preview_item(db, item, candidate)

    if candidate.content_type == "grammar":
        return await _build_grammar_execute_preview_item(db, item, candidate)

    return AdminTtsReviewExecutePreviewItem(
        target=item.target,
        admin_content_type=item.admin_content_type,
        admin_field=item.admin_field,
        lookup_status="not_lookup_ready",
        can_generate_with_current_service=False,
        candidate=candidate,
        notes_ko="DB lookup candidate가 현재 execute preview에서 지원하는 content type이 아니다.",
    )


async def _build_grammar_execute_preview_item(
    db: AsyncSession,
    item: AdminTtsReviewGenerationPlanItem,
    candidate: AdminTtsReviewGenerationPlanCandidate,
) -> AdminTtsReviewExecutePreviewItem:
    if candidate.jlpt_level is None or candidate.grammar_order is None:
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="not_lookup_ready",
            can_generate_with_current_service=False,
            candidate=candidate,
            notes_ko="DB lookup candidate가 현재 execute preview에서 지원하는 grammar level/order 형태가 아니다.",
        )

    try:
        jlpt_level = JlptLevel(candidate.jlpt_level)
    except ValueError:
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="not_lookup_ready",
            can_generate_with_current_service=False,
            candidate=candidate,
            notes_ko="지원하지 않는 JLPT level이라 DB lookup을 실행하지 않았다.",
        )

    result = await db.execute(
        select(Grammar)
        .where(
            Grammar.jlpt_level == jlpt_level,
            Grammar.order == candidate.grammar_order,
        )
        .limit(2)
    )
    matches = list(result.scalars().all())

    if len(matches) == 1:
        grammar = matches[0]
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="resolved",
            can_generate_with_current_service=True,
            candidate=candidate,
            content_item_id=str(grammar.id),
            content_label=str(grammar.pattern),
            notes_ko="현재 DB grammar row로 해석되며 기존 admin TTS service 호출 입력을 만들 수 있다.",
        )

    if len(matches) == 0:
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="missing",
            can_generate_with_current_service=False,
            candidate=candidate,
            notes_ko="정확한 grammar level/order 후보가 있지만 현재 DB에서 row를 찾지 못했다.",
        )

    return AdminTtsReviewExecutePreviewItem(
        target=item.target,
        admin_content_type=item.admin_content_type,
        admin_field=item.admin_field,
        lookup_status="ambiguous",
        can_generate_with_current_service=False,
        candidate=candidate,
        notes_ko="grammar level/order lookup 결과가 여러 개라 자동 생성 입력으로 사용할 수 없다.",
    )


async def _build_vocabulary_execute_preview_item(
    db: AsyncSession,
    item: AdminTtsReviewGenerationPlanItem,
    candidate: AdminTtsReviewGenerationPlanCandidate,
) -> AdminTtsReviewExecutePreviewItem:
    if candidate.jlpt_level is None or candidate.vocabulary_order is None:
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="not_lookup_ready",
            can_generate_with_current_service=False,
            candidate=candidate,
            notes_ko="DB lookup candidate가 현재 execute preview에서 지원하는 vocabulary level/order 형태가 아니다.",
        )

    try:
        jlpt_level = JlptLevel(candidate.jlpt_level)
    except ValueError:
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="not_lookup_ready",
            can_generate_with_current_service=False,
            candidate=candidate,
            notes_ko="지원하지 않는 JLPT level이라 DB lookup을 실행하지 않았다.",
        )

    result = await db.execute(
        select(Vocabulary)
        .where(
            Vocabulary.jlpt_level == jlpt_level,
            Vocabulary.order == candidate.vocabulary_order,
        )
        .limit(2)
    )
    matches = list(result.scalars().all())

    if len(matches) == 1:
        vocabulary = matches[0]
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="resolved",
            can_generate_with_current_service=True,
            candidate=candidate,
            content_item_id=str(vocabulary.id),
            content_label=str(vocabulary.word),
            notes_ko="현재 DB vocabulary row로 해석되며 기존 admin TTS service 호출 입력을 만들 수 있다.",
        )

    if len(matches) == 0:
        return AdminTtsReviewExecutePreviewItem(
            target=item.target,
            admin_content_type=item.admin_content_type,
            admin_field=item.admin_field,
            lookup_status="missing",
            can_generate_with_current_service=False,
            candidate=candidate,
            notes_ko="정확한 vocabulary level/order 후보가 있지만 현재 DB에서 row를 찾지 못했다.",
        )

    return AdminTtsReviewExecutePreviewItem(
        target=item.target,
        admin_content_type=item.admin_content_type,
        admin_field=item.admin_field,
        lookup_status="ambiguous",
        can_generate_with_current_service=False,
        candidate=candidate,
        notes_ko="vocabulary level/order lookup 결과가 여러 개라 자동 생성 입력으로 사용할 수 없다.",
    )


def _build_execute_preview_summary(
    items: list[AdminTtsReviewExecutePreviewItem],
) -> AdminTtsReviewExecutePreviewSummary:
    return AdminTtsReviewExecutePreviewSummary(
        total_targets=len(items),
        resolved_targets=sum(1 for item in items if item.lookup_status == "resolved"),
        missing_targets=sum(1 for item in items if item.lookup_status == "missing"),
        ambiguous_targets=sum(1 for item in items if item.lookup_status == "ambiguous"),
        not_lookup_ready_targets=sum(1 for item in items if item.lookup_status == "not_lookup_ready"),
        blocked_targets=sum(1 for item in items if item.lookup_status == "blocked"),
        generatable_targets=sum(1 for item in items if item.can_generate_with_current_service),
    )


def _validate_batch_counts(batches: list[AdminTtsReviewBatchItem]) -> None:
    for batch in batches:
        if batch.target_count != len(batch.target_ids):
            raise AdminTtsReviewBatchServiceError(
                status_code=500,
                detail=f"TTS review batch {batch.batch_id} has mismatched targetCount",
            )
        if _generation_total(batch.generation_status_summary) != batch.target_count:
            raise AdminTtsReviewBatchServiceError(
                status_code=500,
                detail=f"TTS review batch {batch.batch_id} has mismatched generationStatusSummary",
            )


def _build_summary(batches: list[AdminTtsReviewBatchItem]) -> AdminTtsReviewBatchSummary:
    generation_summary = TtsGenerationStatusSummary(
        missing=0,
        generated=0,
        approved=0,
        rejected=0,
        stale=0,
    )
    admin_ready_targets = 0
    extension_required_targets = 0
    required_before_publish_targets = 0

    for batch in batches:
        if batch.review_surface == "admin_existing_tts":
            admin_ready_targets += batch.target_count
        if batch.review_surface == "admin_extension_required":
            extension_required_targets += batch.target_count
        required_before_publish_targets += batch.required_before_publish_count
        generation_summary.missing += batch.generation_status_summary.missing
        generation_summary.generated += batch.generation_status_summary.generated
        generation_summary.approved += batch.generation_status_summary.approved
        generation_summary.rejected += batch.generation_status_summary.rejected
        generation_summary.stale += batch.generation_status_summary.stale

    return AdminTtsReviewBatchSummary(
        total_batches=len(batches),
        total_targets=sum(batch.target_count for batch in batches),
        admin_ready_targets=admin_ready_targets,
        extension_required_targets=extension_required_targets,
        required_before_publish_targets=required_before_publish_targets,
        generation_status_summary=generation_summary,
    )


def _generation_total(summary: TtsGenerationStatusSummary) -> int:
    return summary.missing + summary.generated + summary.approved + summary.rejected + summary.stale
