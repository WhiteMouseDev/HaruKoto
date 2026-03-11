from __future__ import annotations

from datetime import datetime
from uuid import UUID

from app.models.enums import WordbookSource
from app.schemas.common import CamelModel


class WordbookEntryResponse(CamelModel):
    id: UUID
    word: str
    reading: str
    meaning_ko: str
    source: WordbookSource
    note: str | None = None
    created_at: datetime


class WordbookCreateRequest(CamelModel):
    word: str
    reading: str
    meaning_ko: str
    source: WordbookSource = WordbookSource.MANUAL
    note: str | None = None


class WordbookUpdateRequest(CamelModel):
    note: str | None = None


class WordbookListResponse(CamelModel):
    entries: list[WordbookEntryResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
