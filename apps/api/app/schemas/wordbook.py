from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import Field

from app.models.enums import WordbookSource
from app.schemas.common import CamelModel, omit_schema_default


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
    preserve_existing: bool = Field(
        default=False,
        description="생략하면 기존 항목을 갱신합니다. true이면 이미 저장한 항목을 그대로 반환합니다.",
        json_schema_extra=omit_schema_default,
    )


class WordbookUpdateRequest(CamelModel):
    note: str | None = None


class WordbookListResponse(CamelModel):
    entries: list[WordbookEntryResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
