from __future__ import annotations

import math
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import WordbookEntry
from app.models.user import User
from app.schemas.wordbook import (
    WordbookCreateRequest,
    WordbookEntryResponse,
    WordbookListResponse,
    WordbookUpdateRequest,
)

router = APIRouter(prefix="/api/v1/wordbook", tags=["wordbook"])


@router.get("/", response_model=WordbookListResponse, status_code=200)
async def list_wordbook(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, le=100),
    sort: str = Query(default="recent"),
    search: str | None = None,
    source: str | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WordbookListResponse:
    query = select(WordbookEntry).where(WordbookEntry.user_id == user.id)
    count_query = select(func.count(WordbookEntry.id)).where(WordbookEntry.user_id == user.id)

    if search:
        search_filter = or_(
            WordbookEntry.word.ilike(f"%{search}%"),
            WordbookEntry.reading.ilike(f"%{search}%"),
            WordbookEntry.meaning_ko.ilike(f"%{search}%"),
        )
        query = query.where(search_filter)
        count_query = count_query.where(search_filter)

    if source:
        query = query.where(WordbookEntry.source == source.upper())
        count_query = count_query.where(WordbookEntry.source == source.upper())

    total = (await db.execute(count_query)).scalar() or 0

    query = query.order_by(WordbookEntry.word) if sort == "alphabetical" else query.order_by(WordbookEntry.created_at.desc())

    query = query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    entries = result.scalars().all()

    return WordbookListResponse(
        entries=[WordbookEntryResponse.model_validate(e) for e in entries],
        total=total,
        page=page,
        page_size=limit,
        total_pages=math.ceil(total / limit) if total > 0 else 0,
    )


@router.post("/", response_model=WordbookEntryResponse, status_code=201)
async def create_wordbook_entry(
    body: WordbookCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WordbookEntryResponse:
    stmt = pg_insert(WordbookEntry).values(
        user_id=user.id,
        word=body.word,
        reading=body.reading,
        meaning_ko=body.meaning_ko,
        source=body.source,
        note=body.note,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "word"],
        set_={"reading": body.reading, "meaning_ko": body.meaning_ko, "note": body.note},
    )
    await db.execute(stmt)
    await db.commit()

    result = await db.execute(select(WordbookEntry).where(WordbookEntry.user_id == user.id, WordbookEntry.word == body.word))
    entry = result.scalar_one()
    return WordbookEntryResponse.model_validate(entry)


@router.get("/{entry_id}", response_model=WordbookEntryResponse, status_code=200)
async def get_wordbook_entry(
    entry_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WordbookEntryResponse:
    entry = await db.get(WordbookEntry, entry_id)
    if not entry or entry.user_id != user.id:
        raise HTTPException(status_code=404, detail="단어장 항목을 찾을 수 없습니다")
    return WordbookEntryResponse.model_validate(entry)


@router.patch("/{entry_id}", response_model=WordbookEntryResponse, status_code=200)
async def update_wordbook_entry(
    entry_id: uuid.UUID,
    body: WordbookUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WordbookEntryResponse:
    entry = await db.get(WordbookEntry, entry_id)
    if not entry or entry.user_id != user.id:
        raise HTTPException(status_code=404, detail="단어장 항목을 찾을 수 없습니다")

    if body.note is not None:
        entry.note = body.note

    await db.commit()
    await db.refresh(entry)
    return WordbookEntryResponse.model_validate(entry)


@router.delete("/{entry_id}", status_code=200)
async def delete_wordbook_entry(
    entry_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, bool]:
    entry = await db.get(WordbookEntry, entry_id)
    if not entry or entry.user_id != user.id:
        raise HTTPException(status_code=404, detail="단어장 항목을 찾을 수 없습니다")

    await db.delete(entry)
    await db.commit()
    return {"ok": True}
