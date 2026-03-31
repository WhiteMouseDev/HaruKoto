from __future__ import annotations

import math
import uuid
from typing import Annotated

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import delete as sa_delete
from sqlalchemy import func, literal, or_, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import _decode_token, bearer_scheme
from app.enums import JlptLevel, ReviewStatus, ScenarioCategory
from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary
from app.models.admin import AuditLog
from app.models.tts import TtsAudio
from app.models.user import User
from app.routers.tts import _upload_to_gcs
from app.schemas.admin_content import (
    AdminTtsRegenerateRequest,
    AdminTtsResponse,
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


# ==========================================
# Content type model map (for batch operations)
# ==========================================

MODEL_MAP: dict[str, type] = {
    "vocabulary": Vocabulary,
    "grammar": Grammar,
    "cloze": ClozeQuestion,
    "sentence_arrange": SentenceArrangeQuestion,
    "conversation": ConversationScenario,
}


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


@router.patch("/vocabulary/{item_id}", response_model=VocabularyDetailResponse)
async def patch_vocabulary(
    item_id: uuid.UUID,
    body: VocabularyUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> VocabularyDetailResponse:
    """Partial update vocabulary item. Only sent fields are updated."""
    result = await db.execute(select(Vocabulary).where(Vocabulary.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    updates = body.model_dump(exclude_unset=True, by_alias=False)
    changes: dict = {}
    for field, new_value in updates.items():
        old_value = getattr(item, field, None)
        if old_value != new_value:
            changes[field] = {"before": old_value, "after": new_value}
            setattr(item, field, new_value)

    if changes:
        audit = AuditLog(
            content_type="vocabulary",
            content_id=item_id,
            action="edit",
            changes=changes,
            reviewer_id=reviewer.id,
        )
        db.add(audit)

    await db.commit()
    await db.refresh(item)
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


@router.post("/vocabulary/{item_id}/review", response_model=VocabularyDetailResponse)
async def review_vocabulary(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> VocabularyDetailResponse:
    """Approve or reject a vocabulary item."""
    if body.action == "reject" and not body.reason:
        raise HTTPException(status_code=422, detail="reason required for reject")

    result = await db.execute(select(Vocabulary).where(Vocabulary.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    item.review_status = ReviewStatus.APPROVED if body.action == "approve" else ReviewStatus.REJECTED
    audit = AuditLog(
        content_type="vocabulary",
        content_id=item_id,
        action=body.action,
        reason=body.reason,
        reviewer_id=reviewer.id,
    )
    db.add(audit)
    await db.commit()
    await db.refresh(item)
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


@router.patch("/grammar/{item_id}", response_model=GrammarDetailResponse)
async def patch_grammar(
    item_id: uuid.UUID,
    body: GrammarUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> GrammarDetailResponse:
    """Partial update grammar item. Only sent fields are updated."""
    result = await db.execute(select(Grammar).where(Grammar.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    updates = body.model_dump(exclude_unset=True, by_alias=False)
    changes: dict = {}
    for field, new_value in updates.items():
        old_value = getattr(item, field, None)
        if old_value != new_value:
            changes[field] = {"before": old_value, "after": new_value}
            setattr(item, field, new_value)

    if changes:
        audit = AuditLog(
            content_type="grammar",
            content_id=item_id,
            action="edit",
            changes=changes,
            reviewer_id=reviewer.id,
        )
        db.add(audit)

    await db.commit()
    await db.refresh(item)
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


@router.post("/grammar/{item_id}/review", response_model=GrammarDetailResponse)
async def review_grammar(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> GrammarDetailResponse:
    """Approve or reject a grammar item."""
    if body.action == "reject" and not body.reason:
        raise HTTPException(status_code=422, detail="reason required for reject")

    result = await db.execute(select(Grammar).where(Grammar.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    item.review_status = ReviewStatus.APPROVED if body.action == "approve" else ReviewStatus.REJECTED
    audit = AuditLog(
        content_type="grammar",
        content_id=item_id,
        action=body.action,
        reason=body.reason,
        reviewer_id=reviewer.id,
    )
    db.add(audit)
    await db.commit()
    await db.refresh(item)
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


@router.patch("/quiz/cloze/{item_id}", response_model=ClozeQuestionDetailResponse)
async def patch_cloze(
    item_id: uuid.UUID,
    body: ClozeQuestionUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> ClozeQuestionDetailResponse:
    """Partial update cloze question. Only sent fields are updated."""
    result = await db.execute(select(ClozeQuestion).where(ClozeQuestion.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    updates = body.model_dump(exclude_unset=True, by_alias=False)
    changes: dict = {}
    for field, new_value in updates.items():
        old_value = getattr(item, field, None)
        if old_value != new_value:
            changes[field] = {"before": old_value, "after": new_value}
            setattr(item, field, new_value)

    if changes:
        audit = AuditLog(
            content_type="cloze",
            content_id=item_id,
            action="edit",
            changes=changes,
            reviewer_id=reviewer.id,
        )
        db.add(audit)

    await db.commit()
    await db.refresh(item)
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


@router.post("/quiz/cloze/{item_id}/review", response_model=ClozeQuestionDetailResponse)
async def review_cloze(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> ClozeQuestionDetailResponse:
    """Approve or reject a cloze question."""
    if body.action == "reject" and not body.reason:
        raise HTTPException(status_code=422, detail="reason required for reject")

    result = await db.execute(select(ClozeQuestion).where(ClozeQuestion.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    item.review_status = ReviewStatus.APPROVED if body.action == "approve" else ReviewStatus.REJECTED
    audit = AuditLog(
        content_type="cloze",
        content_id=item_id,
        action=body.action,
        reason=body.reason,
        reviewer_id=reviewer.id,
    )
    db.add(audit)
    await db.commit()
    await db.refresh(item)
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


@router.patch("/quiz/sentence-arrange/{item_id}", response_model=SentenceArrangeDetailResponse)
async def patch_sentence_arrange(
    item_id: uuid.UUID,
    body: SentenceArrangeUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> SentenceArrangeDetailResponse:
    """Partial update sentence arrange question. Only sent fields are updated."""
    result = await db.execute(select(SentenceArrangeQuestion).where(SentenceArrangeQuestion.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    updates = body.model_dump(exclude_unset=True, by_alias=False)
    changes: dict = {}
    for field, new_value in updates.items():
        old_value = getattr(item, field, None)
        if old_value != new_value:
            changes[field] = {"before": old_value, "after": new_value}
            setattr(item, field, new_value)

    if changes:
        audit = AuditLog(
            content_type="sentence_arrange",
            content_id=item_id,
            action="edit",
            changes=changes,
            reviewer_id=reviewer.id,
        )
        db.add(audit)

    await db.commit()
    await db.refresh(item)
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


@router.post("/quiz/sentence-arrange/{item_id}/review", response_model=SentenceArrangeDetailResponse)
async def review_sentence_arrange(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> SentenceArrangeDetailResponse:
    """Approve or reject a sentence arrange question."""
    if body.action == "reject" and not body.reason:
        raise HTTPException(status_code=422, detail="reason required for reject")

    result = await db.execute(select(SentenceArrangeQuestion).where(SentenceArrangeQuestion.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    item.review_status = ReviewStatus.APPROVED if body.action == "approve" else ReviewStatus.REJECTED
    audit = AuditLog(
        content_type="sentence_arrange",
        content_id=item_id,
        action=body.action,
        reason=body.reason,
        reviewer_id=reviewer.id,
    )
    db.add(audit)
    await db.commit()
    await db.refresh(item)
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


@router.patch("/conversation/{item_id}", response_model=ConversationDetailResponse)
async def patch_conversation(
    item_id: uuid.UUID,
    body: ConversationUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> ConversationDetailResponse:
    """Partial update conversation scenario. Only sent fields are updated."""
    result = await db.execute(select(ConversationScenario).where(ConversationScenario.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    updates = body.model_dump(exclude_unset=True, by_alias=False)
    changes: dict = {}
    for field, new_value in updates.items():
        old_value = getattr(item, field, None)
        if old_value != new_value:
            changes[field] = {"before": old_value, "after": new_value}
            setattr(item, field, new_value)

    if changes:
        audit = AuditLog(
            content_type="conversation",
            content_id=item_id,
            action="edit",
            changes=changes,
            reviewer_id=reviewer.id,
        )
        db.add(audit)

    await db.commit()
    await db.refresh(item)
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


@router.post("/conversation/{item_id}/review", response_model=ConversationDetailResponse)
async def review_conversation(
    item_id: uuid.UUID,
    body: ReviewRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    reviewer: Annotated[User, Depends(require_reviewer)],
) -> ConversationDetailResponse:
    """Approve or reject a conversation scenario."""
    if body.action == "reject" and not body.reason:
        raise HTTPException(status_code=422, detail="reason required for reject")

    result = await db.execute(select(ConversationScenario).where(ConversationScenario.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Not found")

    item.review_status = ReviewStatus.APPROVED if body.action == "approve" else ReviewStatus.REJECTED
    audit = AuditLog(
        content_type="conversation",
        content_id=item_id,
        action=body.action,
        reason=body.reason,
        reviewer_id=reviewer.id,
    )
    db.add(audit)
    await db.commit()
    await db.refresh(item)
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
    if body.action == "reject" and not body.reason:
        raise HTTPException(status_code=422, detail="reason required for reject")

    model_class = MODEL_MAP.get(body.content_type)
    if model_class is None:
        raise HTTPException(status_code=400, detail=f"Unknown content_type: {body.content_type}")

    new_status = ReviewStatus.APPROVED if body.action == "approve" else ReviewStatus.REJECTED

    for item_id in body.ids:
        result = await db.execute(select(model_class).where(model_class.id == item_id))  # type: ignore[attr-defined]
        item = result.scalar_one_or_none()
        if item is None:
            raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
        item.review_status = new_status
        audit = AuditLog(
            content_type=body.content_type,
            content_id=item_id,
            action=body.action,
            reason=body.reason,
            reviewer_id=reviewer.id,
        )
        db.add(audit)

    await db.commit()
    return OkResponse(ok=True, count=len(body.ids))


# ==========================================
# TTS endpoints (Phase 4 + Phase 6 per-field TTS)
# ==========================================

TTS_FIELDS: dict[str, list[str]] = {
    "vocabulary": ["reading", "word", "example_sentence"],
    "grammar": ["pattern", "example_sentences"],
    "cloze": ["sentence"],
    "sentence_arrange": ["japanese_sentence"],
    "conversation": ["situation"],
}

_CONTENT_MODEL_MAP: dict[str, type] = {
    "vocabulary": Vocabulary,
    "grammar": Grammar,
    "cloze": ClozeQuestion,
    "sentence_arrange": SentenceArrangeQuestion,
    "conversation": ConversationScenario,
}


def resolve_tts_text(content_type: str, field: str, obj: object) -> str:
    """Extract text value for TTS from a content model instance by field name."""
    if content_type == "grammar" and field == "example_sentences":
        sentences = getattr(obj, "example_sentences", None) or []
        if sentences and isinstance(sentences[0], dict):
            return sentences[0].get("japanese", "") or sentences[0].get("sentence", "")
        return getattr(obj, "pattern", "") or ""
    value = getattr(obj, field, None)
    if not value:
        raise HTTPException(status_code=422, detail=f"Field '{field}' is empty or unavailable")
    return str(value)


@router.post("/tts/regenerate", response_model=AdminTtsResponse)
async def regenerate_admin_tts(
    body: AdminTtsRegenerateRequest,
    reviewer: Annotated[User, Depends(require_reviewer)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AdminTtsResponse:
    """Regenerate TTS for a content item (no cooldown — admin tool for 1-3 reviewers)."""
    # 1. Fetch the content item
    model_cls = _CONTENT_MODEL_MAP.get(body.content_type)
    if not model_cls:
        raise HTTPException(status_code=400, detail=f"Unknown content_type: {body.content_type}")
    result = await db.execute(select(model_cls).where(model_cls.id == body.item_id))  # type: ignore[attr-defined]
    obj = result.scalar_one_or_none()
    if not obj:
        raise HTTPException(status_code=404, detail="Content item not found")

    # 3. Resolve text from field
    text = resolve_tts_text(body.content_type, body.field, obj)

    # 4. Delete existing TtsAudio row (avoid UniqueConstraint violation)
    await db.execute(
        sa_delete(TtsAudio).where(
            TtsAudio.target_type == body.content_type,
            TtsAudio.target_id == body.item_id,
            TtsAudio.speed == 1.0,
        )
    )

    # 5. Generate TTS + upload to GCS
    try:
        tts_result = await generate_tts(text)
    except RuntimeError:
        raise HTTPException(status_code=502, detail="TTS生成に失敗しました") from None
    gcs_path = f"tts/admin/{body.content_type}/{body.item_id}.mp3"
    audio_url = await _upload_to_gcs(gcs_path, tts_result.audio)

    # 6. Save new TtsAudio row
    db.add(
        TtsAudio(
            target_type=body.content_type,
            target_id=body.item_id,
            text=text,
            speed=1.0,
            provider=tts_result.provider,
            model=tts_result.model,
            audio_url=audio_url,
        )
    )
    await db.commit()

    return AdminTtsResponse(audio_url=audio_url, field=text, provider=tts_result.provider)


# ==========================================
# Review queue endpoint (Phase 5)
# ==========================================

REVIEW_QUEUE_LIMIT = 200


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
    if content_type == "quiz":
        return await _get_quiz_review_queue(db, jlpt_level)

    model = MODEL_MAP.get(content_type)
    if model is None:
        raise HTTPException(status_code=400, detail=f"Unknown content type: {content_type}")

    q = select(model.id).where(model.review_status == ReviewStatus.NEEDS_REVIEW)  # type: ignore[attr-defined]
    if jlpt_level is not None:
        q = q.where(model.jlpt_level == jlpt_level)  # type: ignore[attr-defined]
    if category is not None and content_type == "conversation":
        q = q.where(ConversationScenario.category == category)

    q = q.order_by(model.created_at.asc()).limit(REVIEW_QUEUE_LIMIT + 1)  # type: ignore[attr-defined]
    result = await db.execute(q)
    all_ids = [str(row[0]) for row in result.all()]

    capped = len(all_ids) > REVIEW_QUEUE_LIMIT
    ids = all_ids[:REVIEW_QUEUE_LIMIT]

    return ReviewQueueResponse(
        ids=[ReviewQueueItem(id=item_id) for item_id in ids],
        total=len(ids),
        capped=capped,
    )


async def _get_quiz_review_queue(
    db: AsyncSession,
    jlpt_level: JlptLevel | None,
) -> ReviewQueueResponse:
    """Build review queue for quiz by merging cloze + sentence_arrange, sorted by created_at ASC."""
    items: list[tuple[str, str, object]] = []  # (id, quiz_type, created_at)

    # Cloze questions
    cq = select(ClozeQuestion.id, ClozeQuestion.created_at).where(ClozeQuestion.review_status == ReviewStatus.NEEDS_REVIEW)
    if jlpt_level is not None:
        cq = cq.where(ClozeQuestion.jlpt_level == jlpt_level)
    cloze_result = await db.execute(cq)
    for row in cloze_result.all():
        items.append((str(row[0]), "cloze", row[1]))

    # Sentence arrange questions
    aq = select(SentenceArrangeQuestion.id, SentenceArrangeQuestion.created_at).where(
        SentenceArrangeQuestion.review_status == ReviewStatus.NEEDS_REVIEW
    )
    if jlpt_level is not None:
        aq = aq.where(SentenceArrangeQuestion.jlpt_level == jlpt_level)
    arrange_result = await db.execute(aq)
    for row in arrange_result.all():
        items.append((str(row[0]), "sentence_arrange", row[1]))

    # Sort by created_at ASC (oldest first)
    items.sort(key=lambda x: x[2])

    capped = len(items) > REVIEW_QUEUE_LIMIT
    items = items[:REVIEW_QUEUE_LIMIT]

    return ReviewQueueResponse(
        ids=[ReviewQueueItem(id=item_id, quiz_type=qt) for item_id, qt, _ in items],
        total=len(items),
        capped=capped,
    )


@router.get("/{content_type}/{item_id}/tts", response_model=AdminTtsResponse)
async def get_admin_tts(
    content_type: str,
    item_id: str,
    reviewer: Annotated[User, Depends(require_reviewer)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AdminTtsResponse:
    """Return existing TTS audio URL for a content item, or null if none exists."""
    result = await db.execute(
        select(TtsAudio).where(
            TtsAudio.target_type == content_type,
            TtsAudio.target_id == item_id,
            TtsAudio.speed == 1.0,
        )
    )
    record = result.scalar_one_or_none()
    if record:
        return AdminTtsResponse(audio_url=record.audio_url, field=record.text, provider=record.provider)
    return AdminTtsResponse(audio_url=None, field=None, provider=None)


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
    result = await db.execute(
        select(AuditLog).where(AuditLog.content_type == content_type, AuditLog.content_id == item_id).order_by(AuditLog.created_at.desc())
    )
    logs = result.scalars().all()
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
    stats: list[ContentStatsItem] = []

    content_types: list[tuple[str, type]] = [
        ("vocabulary", Vocabulary),
        ("grammar", Grammar),
        ("cloze", ClozeQuestion),
        ("sentence_arrange", SentenceArrangeQuestion),
        ("conversation", ConversationScenario),
    ]

    for content_type, model in content_types:
        count_q = select(model.review_status, func.count().label("cnt")).group_by(model.review_status)  # type: ignore[attr-defined]
        result = await db.execute(count_q)
        counts: dict[str, int] = {row[0].value: row[1] for row in result.all()}

        needs_review = counts.get(ReviewStatus.NEEDS_REVIEW.value, 0)
        approved = counts.get(ReviewStatus.APPROVED.value, 0)
        rejected = counts.get(ReviewStatus.REJECTED.value, 0)

        stats.append(
            ContentStatsItem(
                content_type=content_type,
                needs_review=needs_review,
                approved=approved,
                rejected=rejected,
                total=needs_review + approved + rejected,
            )
        )

    return ContentStatsResponse(stats=stats)
