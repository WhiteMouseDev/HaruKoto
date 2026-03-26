from __future__ import annotations

import math
from typing import Annotated

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import _decode_token, bearer_scheme
from app.enums import JlptLevel, ReviewStatus, ScenarioCategory
from app.models import ClozeQuestion, ConversationScenario, Grammar, SentenceArrangeQuestion, Vocabulary
from app.models.user import User
from app.schemas.admin_content import (
    ContentStatsItem,
    ContentStatsResponse,
    ConversationAdminItem,
    GrammarAdminItem,
    QuizAdminItem,
    VocabularyAdminItem,
)
from app.schemas.common import PaginatedResponse

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
# Vocabulary endpoint
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

    offset = (page - 1) * page_size
    items_result = await db.execute(q.order_by(Vocabulary.created_at.desc()).offset(offset).limit(page_size))
    items = items_result.scalars().all()

    return PaginatedResponse(
        items=[VocabularyAdminItem.model_validate(item) for item in items],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )


# ==========================================
# Grammar endpoint
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

    offset = (page - 1) * page_size
    items_result = await db.execute(q.order_by(Grammar.created_at.desc()).offset(offset).limit(page_size))
    items = items_result.scalars().all()

    return PaginatedResponse(
        items=[GrammarAdminItem.model_validate(item) for item in items],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )


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
) -> PaginatedResponse[QuizAdminItem]:
    """List quiz items (cloze + sentence_arrange) with optional filters and search."""
    cloze_items: list[QuizAdminItem] = []
    arrange_items: list[QuizAdminItem] = []

    # Build cloze query
    if quiz_type is None or quiz_type == "cloze":
        cq = select(ClozeQuestion)
        if jlpt_level is not None:
            cq = cq.where(ClozeQuestion.jlpt_level == jlpt_level)
        if review_status is not None:
            cq = cq.where(ClozeQuestion.review_status == review_status)
        if search:
            cq = cq.where(ClozeQuestion.sentence.ilike(f"%{search}%"))
        cloze_result = await db.execute(cq.order_by(ClozeQuestion.created_at.desc()))
        for row in cloze_result.scalars().all():
            cloze_items.append(
                QuizAdminItem(
                    id=row.id,
                    question_text=row.sentence,
                    quiz_type="cloze",
                    jlpt_level=row.jlpt_level.value,
                    review_status=row.review_status.value,
                    created_at=row.created_at,
                )
            )

    # Build sentence_arrange query
    if quiz_type is None or quiz_type == "sentence_arrange":
        aq = select(SentenceArrangeQuestion)
        if jlpt_level is not None:
            aq = aq.where(SentenceArrangeQuestion.jlpt_level == jlpt_level)
        if review_status is not None:
            aq = aq.where(SentenceArrangeQuestion.review_status == review_status)
        if search:
            aq = aq.where(SentenceArrangeQuestion.korean_sentence.ilike(f"%{search}%"))
        arrange_result = await db.execute(aq.order_by(SentenceArrangeQuestion.created_at.desc()))
        for row in arrange_result.scalars().all():
            arrange_items.append(
                QuizAdminItem(
                    id=row.id,
                    question_text=row.korean_sentence,
                    quiz_type="sentence_arrange",
                    jlpt_level=row.jlpt_level.value,
                    review_status=row.review_status.value,
                    created_at=row.created_at,
                )
            )

    # Merge and sort by created_at desc
    all_items = sorted(cloze_items + arrange_items, key=lambda x: x.created_at, reverse=True)
    total = len(all_items)
    offset = (page - 1) * page_size
    page_items = all_items[offset : offset + page_size]

    return PaginatedResponse(
        items=page_items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=math.ceil(total / page_size) if total > 0 else 1,
    )


# ==========================================
# Conversation endpoint
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

    offset = (page - 1) * page_size
    items_result = await db.execute(q.order_by(ConversationScenario.created_at.desc()).offset(offset).limit(page_size))
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
