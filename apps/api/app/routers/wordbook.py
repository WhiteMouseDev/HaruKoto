from __future__ import annotations

import math
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models import UserVocabProgress, Vocabulary, WordbookEntry
from app.models.enums import WordbookSource
from app.models.user import User
from app.schemas.wordbook import (
    WordbookCreateRequest,
    WordbookEntryDetailResponse,
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

    if sort == "most-wrong":
        # Use the wrong-answer notebook's counter only if one catalog entry matches.
        incorrect_count = (
            select(case((func.count(Vocabulary.id) == 1, func.coalesce(func.max(UserVocabProgress.incorrect_count), 0)), else_=0))
            .select_from(Vocabulary)
            .outerjoin(
                UserVocabProgress,
                and_(UserVocabProgress.vocabulary_id == Vocabulary.id, UserVocabProgress.user_id == WordbookEntry.user_id),
            )
            .where(
                Vocabulary.word == WordbookEntry.word,
                Vocabulary.reading == WordbookEntry.reading,
                Vocabulary.meaning_ko == WordbookEntry.meaning_ko,
            )
            .correlate(WordbookEntry)
            .scalar_subquery()
        )
        query = query.order_by(incorrect_count.desc(), WordbookEntry.created_at.desc(), WordbookEntry.id.asc())
    elif sort == "alphabetical":
        query = query.order_by(WordbookEntry.word)
    else:
        query = query.order_by(WordbookEntry.created_at.desc())

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
    if body.preserve_existing:
        stmt = stmt.on_conflict_do_nothing(index_elements=["user_id", "word"])
    else:
        updates: dict[str, str | None] = {"reading": body.reading, "meaning_ko": body.meaning_ko}
        if "note" in body.model_fields_set:
            updates["note"] = body.note
        # Older quiz clients save without preserveExisting. Keep any manual edits.
        update_condition = WordbookEntry.source != WordbookSource.MANUAL if body.source != WordbookSource.MANUAL else None
        stmt = stmt.on_conflict_do_update(index_elements=["user_id", "word"], set_=updates, where=update_condition)
    await db.execute(stmt)
    await db.commit()

    result = await db.execute(select(WordbookEntry).where(WordbookEntry.user_id == user.id, WordbookEntry.word == body.word))
    entry = result.scalar_one()
    return WordbookEntryResponse.model_validate(entry)


@router.get("/{entry_id}", response_model=WordbookEntryDetailResponse, status_code=200)
async def get_wordbook_entry(
    entry_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WordbookEntryDetailResponse:
    entry = await db.get(WordbookEntry, entry_id)
    if not entry or entry.user_id != user.id:
        raise HTTPException(status_code=404, detail="단어장 항목을 찾을 수 없습니다")

    examples = await db.execute(
        select(Vocabulary.example_sentence, Vocabulary.example_translation)
        .where(
            Vocabulary.word == entry.word,
            Vocabulary.reading == entry.reading,
            Vocabulary.meaning_ko == entry.meaning_ko,
            func.btrim(Vocabulary.example_sentence) != "",
        )
        .distinct()
        .limit(2)
    )
    matches = examples.tuples().all()
    detail = WordbookEntryDetailResponse.model_validate(entry)
    if len(matches) == 1:
        sentence, translation = matches[0]
        if sentence and sentence.strip():
            detail.example_sentence = sentence
            detail.example_translation = translation if translation and translation.strip() else None
    return detail


@router.patch(
    "/{entry_id}",
    response_model=WordbookEntryResponse,
    status_code=200,
    responses={
        403: {"description": "Only manually added words can be edited"},
        409: {"description": "The word already exists in your wordbook"},
    },
)
async def update_wordbook_entry(
    entry_id: uuid.UUID,
    body: WordbookUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WordbookEntryResponse:
    entry = await db.scalar(select(WordbookEntry).where(WordbookEntry.id == entry_id, WordbookEntry.user_id == user.id).with_for_update())
    if entry is None:
        raise HTTPException(status_code=404, detail="단어장 항목을 찾을 수 없습니다")

    updates = body.model_dump(exclude_none=True)
    if entry.source != WordbookSource.MANUAL and updates.keys() - {"note"}:
        raise HTTPException(status_code=403, detail="직접 추가한 단어만 수정할 수 있습니다")
    for field, value in updates.items():
        setattr(entry, field, value)

    response = WordbookEntryResponse.model_validate(entry)
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        # SQLAlchemy's asyncpg adapter preserves the driver error as the cause.
        cause = exc.orig.__cause__ if exc.orig else None
        if getattr(cause, "sqlstate", None) == "23505" and getattr(cause, "constraint_name", None) == "wordbook_entries_user_id_word_key":
            raise HTTPException(status_code=409, detail="이미 단어장에 있는 단어입니다") from exc
        raise
    return response


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
