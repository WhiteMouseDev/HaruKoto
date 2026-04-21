from __future__ import annotations

import math
import uuid
from typing import Annotated, Any

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import func, literal, or_, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import _decode_token, bearer_scheme
from app.enums import JlptLevel, ReviewStatus, ScenarioCategory
from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary
from app.models.tts import TtsAudio
from app.models.user import User
from app.routers.tts import _upload_to_gcs
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
from app.services.admin_review_queue import AdminReviewQueueServiceError, get_admin_review_queue
from app.services.admin_tts import (
    TTS_FIELDS,
    AdminTtsServiceError,
    regenerate_admin_tts_audio,
)
from app.services.admin_tts import (
    resolve_tts_text as resolve_tts_text,
)
from app.services.ai import generate_tts

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


_VOCAB_SORT_COLS = {
    "created_at": Vocabulary.created_at,
    "review_status": Vocabulary.review_status,
    "jlpt_level": Vocabulary.jlpt_level,
}


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
    q = select(Vocabulary)

    if jlpt_level is not None:
        q = q.where(Vocabulary.jlpt_level == jlpt_level)
    if review_status is not None:
        q = q.where(Vocabulary.review_status == review_status)
    if search:
        q = q.where(
            or_(
                Vocabulary.word.ilike(f"%{search}%"),
                Vocabulary.reading.ilike(f"%{search}%"),
                Vocabulary.meaning_ko.ilike(f"%{search}%"),
            )
        )

    total_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = total_result.scalar_one()

    sort_col = _VOCAB_SORT_COLS.get(sort_by or "", Vocabulary.created_at)
    order_expr = sort_col.asc() if sort_order == "asc" else sort_col.desc()

    offset = (page - 1) * page_size
    items_result = await db.execute(q.order_by(order_expr).offset(offset).limit(page_size))
    items = items_result.scalars().all()

    return PaginatedResponse(
        items=[VocabularyAdminItem.model_validate(item) for item in items],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )


@router.get("/vocabulary/{item_id}", response_model=VocabularyDetailResponse)
async def get_vocabulary_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> VocabularyDetailResponse:
    """Return full detail for a single vocabulary item."""
    result = await db.execute(select(Vocabulary).where(Vocabulary.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")
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


_GRAMMAR_SORT_COLS = {
    "created_at": Grammar.created_at,
    "review_status": Grammar.review_status,
    "jlpt_level": Grammar.jlpt_level,
}


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
    q = select(Grammar)

    if jlpt_level is not None:
        q = q.where(Grammar.jlpt_level == jlpt_level)
    if review_status is not None:
        q = q.where(Grammar.review_status == review_status)
    if search:
        q = q.where(
            or_(
                Grammar.pattern.ilike(f"%{search}%"),
                Grammar.meaning_ko.ilike(f"%{search}%"),
            )
        )

    total_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = total_result.scalar_one()

    sort_col = _GRAMMAR_SORT_COLS.get(sort_by or "", Grammar.created_at)
    order_expr = sort_col.asc() if sort_order == "asc" else sort_col.desc()

    offset = (page - 1) * page_size
    items_result = await db.execute(q.order_by(order_expr).offset(offset).limit(page_size))
    items = items_result.scalars().all()

    return PaginatedResponse(
        items=[GrammarAdminItem.model_validate(item) for item in items],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )


@router.get("/grammar/{item_id}", response_model=GrammarDetailResponse)
async def get_grammar_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> GrammarDetailResponse:
    """Return full detail for a single grammar item."""
    result = await db.execute(select(Grammar).where(Grammar.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")
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


_QUIZ_SORT_COLS = {"created_at", "review_status", "jlpt_level"}


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
    # Build projected cloze query
    cloze_proj = select(
        ClozeQuestion.id,
        ClozeQuestion.sentence.label("sentence"),
        literal("cloze").label("quiz_type"),
        ClozeQuestion.jlpt_level.label("jlpt_level"),
        ClozeQuestion.review_status.label("review_status"),
        ClozeQuestion.created_at,
    )
    if jlpt_level is not None:
        cloze_proj = cloze_proj.where(ClozeQuestion.jlpt_level == jlpt_level)
    if review_status is not None:
        cloze_proj = cloze_proj.where(ClozeQuestion.review_status == review_status)
    if search:
        cloze_proj = cloze_proj.where(ClozeQuestion.sentence.ilike(f"%{search}%"))

    # Build projected sentence_arrange query
    arrange_proj = select(
        SentenceArrangeQuestion.id,
        SentenceArrangeQuestion.korean_sentence.label("sentence"),
        literal("sentence_arrange").label("quiz_type"),
        SentenceArrangeQuestion.jlpt_level.label("jlpt_level"),
        SentenceArrangeQuestion.review_status.label("review_status"),
        SentenceArrangeQuestion.created_at,
    )
    if jlpt_level is not None:
        arrange_proj = arrange_proj.where(SentenceArrangeQuestion.jlpt_level == jlpt_level)
    if review_status is not None:
        arrange_proj = arrange_proj.where(SentenceArrangeQuestion.review_status == review_status)
    if search:
        arrange_proj = arrange_proj.where(SentenceArrangeQuestion.korean_sentence.ilike(f"%{search}%"))

    # Build UNION subquery based on quiz_type filter
    if quiz_type == "cloze":
        combined = cloze_proj.subquery()
    elif quiz_type == "sentence_arrange":
        combined = arrange_proj.subquery()
    else:
        combined = union_all(cloze_proj, arrange_proj).subquery()

    # Count total via SQL
    total_result = await db.execute(select(func.count()).select_from(combined))
    total = total_result.scalar_one()

    # Determine sort column on the subquery
    effective_sort_by = sort_by if sort_by in _QUIZ_SORT_COLS else "created_at"
    sort_col = combined.c[effective_sort_by]
    order_expr = sort_col.asc() if sort_order == "asc" else sort_col.desc()

    offset = (page - 1) * page_size
    items_result = await db.execute(select(combined).order_by(order_expr).offset(offset).limit(page_size))
    rows = items_result.all()

    items = [
        QuizAdminItem(
            id=row.id,
            sentence=row.sentence,
            quiz_type=row.quiz_type,
            jlpt_level=row.jlpt_level.value if hasattr(row.jlpt_level, "value") else str(row.jlpt_level),
            review_status=row.review_status.value if hasattr(row.review_status, "value") else str(row.review_status),
            created_at=row.created_at,
        )
        for row in rows
    ]

    return PaginatedResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )


@router.get("/quiz/cloze/{item_id}", response_model=ClozeQuestionDetailResponse)
async def get_cloze_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> ClozeQuestionDetailResponse:
    """Return full detail for a single cloze question."""
    result = await db.execute(select(ClozeQuestion).where(ClozeQuestion.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")
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
    result = await db.execute(select(SentenceArrangeQuestion).where(SentenceArrangeQuestion.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")
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


_CONVERSATION_SORT_COLS = {
    "created_at": ConversationScenario.created_at,
    "review_status": ConversationScenario.review_status,
    "category": ConversationScenario.category,
}


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
    q = select(ConversationScenario)

    # jlpt_level filter not applicable to conversation_scenarios
    if category is not None:
        q = q.where(ConversationScenario.category == category)
    if review_status is not None:
        q = q.where(ConversationScenario.review_status == review_status)
    if search:
        q = q.where(
            or_(
                ConversationScenario.title.ilike(f"%{search}%"),
                ConversationScenario.title_ja.ilike(f"%{search}%"),
                ConversationScenario.description.ilike(f"%{search}%"),
            )
        )

    total_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = total_result.scalar_one()

    sort_col = _CONVERSATION_SORT_COLS.get(sort_by or "", ConversationScenario.created_at)
    order_expr = sort_col.asc() if sort_order == "asc" else sort_col.desc()

    offset = (page - 1) * page_size
    items_result = await db.execute(q.order_by(order_expr).offset(offset).limit(page_size))
    items = items_result.scalars().all()

    return PaginatedResponse(
        items=[
            ConversationAdminItem(
                id=item.id,
                title=item.title,
                category=item.category.value,
                jlpt_level=None,  # no jlpt_level on conversation_scenarios
                review_status=item.review_status.value,
                created_at=item.created_at,
            )
            for item in items
        ],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )


@router.get("/conversation/{item_id}", response_model=ConversationDetailResponse)
async def get_conversation_detail(
    item_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _reviewer: Annotated[User, Depends(require_reviewer)],
) -> ConversationDetailResponse:
    """Return full detail for a single conversation scenario."""
    result = await db.execute(select(ConversationScenario).where(ConversationScenario.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")
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
            upload_to_gcs=_upload_to_gcs,
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
    reviewer: Annotated[User, Depends(require_reviewer)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AdminTtsMapResponse:
    """Return per-field TTS audio map for a content item."""
    fields = TTS_FIELDS.get(content_type)
    if fields is None:
        raise HTTPException(status_code=400, detail=f"Unknown content_type: {content_type}")

    result = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == content_type,
            TtsAudio.target_id == item_id,
            TtsAudio.speed == 1.0,
        )
    )
    records = result.scalars().all()

    # Build audios map: all fields default to None, then populate from records
    audios: dict[str, AudioFieldInfo | None] = {f: None for f in fields}
    for record in records:
        if record.field in audios:
            audios[record.field] = AudioFieldInfo(
                audio_url=record.audio_url,
                provider=record.provider,
                created_at=record.created_at,
            )

    return AdminTtsMapResponse(audios=audios)


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
