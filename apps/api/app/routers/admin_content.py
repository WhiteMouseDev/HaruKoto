from __future__ import annotations

import uuid
from typing import Annotated, Any

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import _decode_token, bearer_scheme
from app.enums import JlptLevel, ReviewStatus, ScenarioCategory
from app.models.user import User
from app.schemas.admin_content import (
    AdminTtsMapResponse,
    AdminTtsRegenerateRequest,
    AdminTtsResponse,
    AudioFieldInfo,
    AuditLogItem,
    BatchReviewRequest,
    ClozeQuestionDetailResponse,
    ClozeQuestionUpdateRequest,
    ContentStatsItem,
    ContentStatsResponse,
    ConversationAdminItem,
    ConversationDetailResponse,
    ConversationUpdateRequest,
    GrammarAdminItem,
    GrammarDetailResponse,
    GrammarUpdateRequest,
    OkResponse,
    QuizAdminItem,
    ReviewQueueItem,
    ReviewQueueResponse,
    ReviewRequest,
    SentenceArrangeDetailResponse,
    SentenceArrangeUpdateRequest,
    VocabularyAdminItem,
    VocabularyDetailResponse,
    VocabularyUpdateRequest,
)
from app.schemas.common import PaginatedResponse
from app.services.admin_audit_logs import list_admin_audit_logs
from app.services.admin_batch_review import AdminBatchReviewServiceError, batch_review_content
from app.services.admin_content_detail import AdminContentDetailServiceError, get_admin_content_item
from app.services.admin_content_edit import AdminContentEditServiceError, edit_admin_content_item
from app.services.admin_content_responses import (
    to_cloze_detail_response,
    to_conversation_detail_response,
    to_grammar_detail_response,
    to_sentence_arrange_detail_response,
    to_vocabulary_detail_response,
)
from app.services.admin_content_review import AdminContentReviewServiceError, review_admin_content_item
from app.services.admin_content_stats import get_admin_content_stats
from app.services.admin_conversation_list import list_admin_conversation
from app.services.admin_grammar_list import list_admin_grammar
from app.services.admin_quiz_list import list_admin_quiz
from app.services.admin_review_queue import AdminReviewQueueServiceError, get_admin_review_queue
from app.services.admin_tts import (
    AdminTtsServiceError,
    get_admin_tts_map,
    regenerate_admin_tts_audio,
)
from app.services.admin_vocabulary_list import list_admin_vocabulary
from app.services.ai import generate_tts
from app.services.tts_storage import upload_tts_to_gcs

router = APIRouter(prefix="/api/v1/admin/content", tags=["admin-content"])


# ==========================================
# require_reviewer dependency
# ==========================================


async def require_reviewer(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    """Decode JWT and verify app_metadata.reviewer == True. Returns User or raises 403."""
    try:
        payload = _decode_token(credentials.credentials)
    except (jwt.InvalidTokenError, jwt.ExpiredSignatureError, jwt.DecodeError) as err:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from err

    # Check reviewer flag in app_metadata
    app_metadata = payload.get("app_metadata", {})
    if not app_metadata.get("reviewer", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Reviewer role required",
        )

    sub = payload.get("sub")
    if sub is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
        )

    from uuid import UUID

    try:
        user_id = UUID(sub)
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid subject claim",
        ) from err

    from sqlalchemy import select as sa_select

    result = await db.execute(sa_select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return user


async def _review_admin_content_or_http(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: uuid.UUID,
    body: ReviewRequest,
    reviewer_id: uuid.UUID,
) -> Any:
    try:
        return await review_admin_content_item(
            db,
            content_type=content_type,
            item_id=item_id,
            action=body.action,
            reviewer_id=reviewer_id,
            reason=body.reason,
        )
    except AdminContentReviewServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc


async def _get_admin_content_or_http(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: uuid.UUID,
) -> Any:
    try:
        return await get_admin_content_item(
            db,
            content_type=content_type,
            item_id=item_id,
        )
    except AdminContentDetailServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc


async def _edit_admin_content_or_http(
    db: AsyncSession,
    *,
    content_type: str,
    item_id: uuid.UUID,
    updates: dict[str, Any],
    reviewer_id: uuid.UUID,
) -> Any:
    try:
        return await edit_admin_content_item(
            db,
            content_type=content_type,
            item_id=item_id,
            updates=updates,
            reviewer_id=reviewer_id,
        )
    except AdminContentEditServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc


# ==========================================
# Vocabulary endpoints
# ==========================================


@router.get("/vocabulary", response_model=PaginatedResponse[VocabularyAdminItem])
async def list_vocabulary(
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    jlpt_level: JlptLevel | None = Query(default=None),
    review_status: ReviewStatus | None = Query(default=None),
    search: str | None = Query(default=None),
    sort_by: str | None = Query(default=None, description="Column to sort by: created_at, review_status, jlpt_level"),
    sort_order: str = Query(default="desc", description="Sort direction: asc or desc"),
) -> PaginatedResponse[VocabularyAdminItem]:
    """List vocabulary items with optional filters and search."""
    result = await list_admin_vocabulary(
        db,
        page=page,
        page_size=page_size,
        jlpt_level=jlpt_level,
        review_status=review_status,
        search=search,
        sort_by=sort_by,
        sort_order=sort_order,
    )

    return PaginatedResponse(
        items=[VocabularyAdminItem.model_validate(item) for item in result.items],
        total=result.total,
        page=result.page,
        page_size=result.page_size,
        total_pages=result.total_pages,
    )


@router.get("/vocabulary/{item_id}", response_model=VocabularyDetailResponse)
async def get_vocabulary_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> VocabularyDetailResponse:
    """Return full detail for a single vocabulary item."""
    item = await _get_admin_content_or_http(db, content_type="vocabulary", item_id=item_id)
    return to_vocabulary_detail_response(item)


@router.patch("/vocabulary/{item_id}", response_model=VocabularyDetailResponse)
async def patch_vocabulary(
    item_id: uuid.UUID,
    body: VocabularyUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> VocabularyDetailResponse:
    """Partial update vocabulary item. Only sent fields are updated."""
    item = await _edit_admin_content_or_http(
        db,
        content_type="vocabulary",
        item_id=item_id,
        updates=body.model_dump(exclude_unset=True, by_alias=False),
        reviewer_id=reviewer.id,
    )
    return to_vocabulary_detail_response(item)


@router.post("/vocabulary/{item_id}/review", response_model=VocabularyDetailResponse)
async def review_vocabulary(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> VocabularyDetailResponse:
    """Approve or reject a vocabulary item."""
    item = await _review_admin_content_or_http(
        db,
        content_type="vocabulary",
        item_id=item_id,
        body=body,
        reviewer_id=reviewer.id,
    )
    return to_vocabulary_detail_response(item)


# ==========================================
# Grammar endpoints
# ==========================================


@router.get("/grammar", response_model=PaginatedResponse[GrammarAdminItem])
async def list_grammar(
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    jlpt_level: JlptLevel | None = Query(default=None),
    review_status: ReviewStatus | None = Query(default=None),
    search: str | None = Query(default=None),
    sort_by: str | None = Query(default=None, description="Column to sort by: created_at, review_status, jlpt_level"),
    sort_order: str = Query(default="desc", description="Sort direction: asc or desc"),
) -> PaginatedResponse[GrammarAdminItem]:
    """List grammar items with optional filters and search."""
    result = await list_admin_grammar(
        db,
        page=page,
        page_size=page_size,
        jlpt_level=jlpt_level,
        review_status=review_status,
        search=search,
        sort_by=sort_by,
        sort_order=sort_order,
    )

    return PaginatedResponse(
        items=[GrammarAdminItem.model_validate(item) for item in result.items],
        total=result.total,
        page=result.page,
        page_size=result.page_size,
        total_pages=result.total_pages,
    )


@router.get("/grammar/{item_id}", response_model=GrammarDetailResponse)
async def get_grammar_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> GrammarDetailResponse:
    """Return full detail for a single grammar item."""
    item = await _get_admin_content_or_http(db, content_type="grammar", item_id=item_id)
    return to_grammar_detail_response(item)


@router.patch("/grammar/{item_id}", response_model=GrammarDetailResponse)
async def patch_grammar(
    item_id: uuid.UUID,
    body: GrammarUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> GrammarDetailResponse:
    """Partial update grammar item. Only sent fields are updated."""
    item = await _edit_admin_content_or_http(
        db,
        content_type="grammar",
        item_id=item_id,
        updates=body.model_dump(exclude_unset=True, by_alias=False),
        reviewer_id=reviewer.id,
    )
    return to_grammar_detail_response(item)


@router.post("/grammar/{item_id}/review", response_model=GrammarDetailResponse)
async def review_grammar(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> GrammarDetailResponse:
    """Approve or reject a grammar item."""
    item = await _review_admin_content_or_http(
        db,
        content_type="grammar",
        item_id=item_id,
        body=body,
        reviewer_id=reviewer.id,
    )
    return to_grammar_detail_response(item)


# ==========================================
# Quiz endpoint (ClozeQuestion + SentenceArrangeQuestion merged)
# ==========================================


@router.get("/quiz", response_model=PaginatedResponse[QuizAdminItem])
async def list_quiz(
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    jlpt_level: JlptLevel | None = Query(default=None),
    review_status: ReviewStatus | None = Query(default=None),
    search: str | None = Query(default=None),
    quiz_type: str | None = Query(default=None, description="Filter by quiz type: 'cloze' or 'sentence_arrange'"),
    sort_by: str | None = Query(default=None, description="Column to sort by: created_at, review_status, jlpt_level"),
    sort_order: str = Query(default="desc", description="Sort direction: asc or desc"),
) -> PaginatedResponse[QuizAdminItem]:
    """List quiz items (cloze + sentence_arrange) with SQL UNION ALL pagination."""
    result = await list_admin_quiz(
        db,
        page=page,
        page_size=page_size,
        jlpt_level=jlpt_level,
        review_status=review_status,
        search=search,
        quiz_type=quiz_type,
        sort_by=sort_by,
        sort_order=sort_order,
    )

    return PaginatedResponse(
        items=[
            QuizAdminItem(
                id=item.id,
                sentence=item.sentence,
                quiz_type=item.quiz_type,
                jlpt_level=item.jlpt_level,
                review_status=item.review_status,
                created_at=item.created_at,
            )
            for item in result.items
        ],
        total=result.total,
        page=result.page,
        page_size=result.page_size,
        total_pages=result.total_pages,
    )


@router.get("/quiz/cloze/{item_id}", response_model=ClozeQuestionDetailResponse)
async def get_cloze_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> ClozeQuestionDetailResponse:
    """Return full detail for a single cloze question."""
    item = await _get_admin_content_or_http(db, content_type="cloze", item_id=item_id)
    return to_cloze_detail_response(item)


@router.patch("/quiz/cloze/{item_id}", response_model=ClozeQuestionDetailResponse)
async def patch_cloze(
    item_id: uuid.UUID,
    body: ClozeQuestionUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> ClozeQuestionDetailResponse:
    """Partial update cloze question. Only sent fields are updated."""
    item = await _edit_admin_content_or_http(
        db,
        content_type="cloze",
        item_id=item_id,
        updates=body.model_dump(exclude_unset=True, by_alias=False),
        reviewer_id=reviewer.id,
    )
    return to_cloze_detail_response(item)


@router.post("/quiz/cloze/{item_id}/review", response_model=ClozeQuestionDetailResponse)
async def review_cloze(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> ClozeQuestionDetailResponse:
    """Approve or reject a cloze question."""
    item = await _review_admin_content_or_http(
        db,
        content_type="cloze",
        item_id=item_id,
        body=body,
        reviewer_id=reviewer.id,
    )
    return to_cloze_detail_response(item)


@router.get("/quiz/sentence-arrange/{item_id}", response_model=SentenceArrangeDetailResponse)
async def get_sentence_arrange_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> SentenceArrangeDetailResponse:
    """Return full detail for a single sentence arrange question."""
    item = await _get_admin_content_or_http(db, content_type="sentence_arrange", item_id=item_id)
    return to_sentence_arrange_detail_response(item)


@router.patch("/quiz/sentence-arrange/{item_id}", response_model=SentenceArrangeDetailResponse)
async def patch_sentence_arrange(
    item_id: uuid.UUID,
    body: SentenceArrangeUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> SentenceArrangeDetailResponse:
    """Partial update sentence arrange question. Only sent fields are updated."""
    item = await _edit_admin_content_or_http(
        db,
        content_type="sentence_arrange",
        item_id=item_id,
        updates=body.model_dump(exclude_unset=True, by_alias=False),
        reviewer_id=reviewer.id,
    )
    return to_sentence_arrange_detail_response(item)


@router.post("/quiz/sentence-arrange/{item_id}/review", response_model=SentenceArrangeDetailResponse)
async def review_sentence_arrange(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> SentenceArrangeDetailResponse:
    """Approve or reject a sentence arrange question."""
    item = await _review_admin_content_or_http(
        db,
        content_type="sentence_arrange",
        item_id=item_id,
        body=body,
        reviewer_id=reviewer.id,
    )
    return to_sentence_arrange_detail_response(item)


# ==========================================
# Conversation endpoints
# ==========================================


@router.get("/conversation", response_model=PaginatedResponse[ConversationAdminItem])
async def list_conversation(
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    jlpt_level: JlptLevel | None = Query(default=None),
    review_status: ReviewStatus | None = Query(default=None),
    search: str | None = Query(default=None),
    category: ScenarioCategory | None = Query(default=None),
    sort_by: str | None = Query(default=None, description="Column to sort by: created_at, review_status, category"),
    sort_order: str = Query(default="desc", description="Sort direction: asc or desc"),
) -> PaginatedResponse[ConversationAdminItem]:
    """List conversation scenario items with optional filters and search.

    Note: ConversationScenario has no jlpt_level column; jlpt_level filter is ignored.
    jlpt_level in response is always None.
    """
    result = await list_admin_conversation(
        db,
        page=page,
        page_size=page_size,
        jlpt_level=jlpt_level,
        review_status=review_status,
        search=search,
        category=category,
        sort_by=sort_by,
        sort_order=sort_order,
    )

    return PaginatedResponse(
        items=[
            ConversationAdminItem(
                id=item.id,
                title=item.title,
                category=item.category,
                jlpt_level=item.jlpt_level,
                review_status=item.review_status,
                created_at=item.created_at,
            )
            for item in result.items
        ],
        total=result.total,
        page=result.page,
        page_size=result.page_size,
        total_pages=result.total_pages,
    )


@router.get("/conversation/{item_id}", response_model=ConversationDetailResponse)
async def get_conversation_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> ConversationDetailResponse:
    """Return full detail for a single conversation scenario."""
    item = await _get_admin_content_or_http(db, content_type="conversation", item_id=item_id)
    return to_conversation_detail_response(item)


@router.patch("/conversation/{item_id}", response_model=ConversationDetailResponse)
async def patch_conversation(
    item_id: uuid.UUID,
    body: ConversationUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> ConversationDetailResponse:
    """Partial update conversation scenario. Only sent fields are updated."""
    item = await _edit_admin_content_or_http(
        db,
        content_type="conversation",
        item_id=item_id,
        updates=body.model_dump(exclude_unset=True, by_alias=False),
        reviewer_id=reviewer.id,
    )
    return to_conversation_detail_response(item)


@router.post("/conversation/{item_id}/review", response_model=ConversationDetailResponse)
async def review_conversation(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> ConversationDetailResponse:
    """Approve or reject a conversation scenario."""
    item = await _review_admin_content_or_http(
        db,
        content_type="conversation",
        item_id=item_id,
        body=body,
        reviewer_id=reviewer.id,
    )
    return to_conversation_detail_response(item)


# ==========================================
# Batch review endpoint
# ==========================================


@router.post("/batch-review", response_model=OkResponse)
async def batch_review(
    body: BatchReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> OkResponse:
    """Batch approve or reject multiple content items in a single transaction."""
    try:
        result = await batch_review_content(
            db,
            content_type=body.content_type,
            item_ids=body.ids,
            action=body.action,
            reviewer_id=reviewer.id,
            reason=body.reason,
        )
    except AdminBatchReviewServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return OkResponse(ok=True, count=result.count)


@router.post("/tts/regenerate", response_model=AdminTtsResponse)
async def regenerate_admin_tts(
    body: AdminTtsRegenerateRequest,
    reviewer: Annotated[User, Depends(require_reviewer)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AdminTtsResponse:
    """Regenerate TTS for a content item (no cooldown — admin tool for 1-3 reviewers)."""
    try:
        result = await regenerate_admin_tts_audio(
            db,
            content_type=body.content_type,
            item_id=body.item_id,
            field=body.field,
            tts_generator=generate_tts,
            upload_to_gcs=upload_tts_to_gcs,
        )
    except AdminTtsServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return AdminTtsResponse(audio_url=result.audio_url, field=result.field, provider=result.provider)


@router.get("/review-queue/{content_type}", response_model=ReviewQueueResponse)
async def get_review_queue(
    content_type: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
    jlpt_level: JlptLevel | None = Query(default=None),
    category: str | None = Query(default=None),
) -> ReviewQueueResponse:
    """Return ordered list of needs_review item IDs for sequential review.

    Items are ordered by created_at ASC (oldest first = natural queue order).
    Capped at 200 items to avoid URL length limits on the frontend.
    """
    try:
        result = await get_admin_review_queue(
            db,
            content_type,
            jlpt_level=jlpt_level,
            category=category,
        )
    except AdminReviewQueueServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return ReviewQueueResponse(
        ids=[ReviewQueueItem(id=item.id, quiz_type=item.quiz_type) for item in result.items],
        total=result.total,
        capped=result.capped,
    )


@router.get("/{content_type}/{item_id}/tts", response_model=AdminTtsMapResponse)
async def get_admin_tts(
    content_type: str,
    item_id: str,
    _reviewer: Annotated[User, Depends(require_reviewer)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AdminTtsMapResponse:
    """Return per-field TTS audio map for a content item."""
    try:
        result = await get_admin_tts_map(db, content_type=content_type, item_id=item_id)
    except AdminTtsServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return AdminTtsMapResponse(
        audios={
            field: (
                AudioFieldInfo(
                    audio_url=audio.audio_url,
                    provider=audio.provider,
                    created_at=audio.created_at,
                )
                if audio is not None
                else None
            )
            for field, audio in result.audios.items()
        }
    )


# ==========================================
# Audit logs endpoint
# ==========================================


@router.get("/{content_type}/{item_id}/audit-logs", response_model=list[AuditLogItem])
async def get_audit_logs(
    content_type: str,
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> list[AuditLogItem]:
    """Return audit log entries for a content item, ordered by created_at DESC."""
    logs = await list_admin_audit_logs(db, content_type=content_type, item_id=item_id)
    return [AuditLogItem.model_validate(log) for log in logs]


# ==========================================
# Stats endpoint
# ==========================================


@router.get("/stats", response_model=ContentStatsResponse)
async def get_content_stats(
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> ContentStatsResponse:
    """Return review_status counts for all content types."""
    stats = await get_admin_content_stats(db)
    return ContentStatsResponse(
        stats=[
            ContentStatsItem(
                content_type=item.content_type,
                needs_review=item.needs_review,
                approved=item.approved,
                rejected=item.rejected,
                total=item.total,
            )
            for item in stats
        ]
    )
