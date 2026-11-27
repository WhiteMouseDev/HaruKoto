from __future__ import annotations

from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import Field, StringConstraints

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


class WordbookEntryDetailResponse(WordbookEntryResponse):
    example_sentence: str | None = Field(default=None, json_schema_extra=omit_schema_default)
    example_translation: str | None = Field(default=None, json_schema_extra=omit_schema_default)


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


type WordbookEditableText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]


class WordbookUpdateRequest(CamelModel):
    note: str | None = None
    word: WordbookEditableText | None = Field(default=None, json_schema_extra=omit_schema_default)
    reading: WordbookEditableText | None = Field(default=None, json_schema_extra=omit_schema_default)
    meaning_ko: WordbookEditableText | None = Field(default=None, json_schema_extra=omit_schema_default)


class WordbookListResponse(CamelModel):
    entries: list[WordbookEntryResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
