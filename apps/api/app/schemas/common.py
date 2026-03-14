from __future__ import annotations

from typing import TypeVar

from pydantic import BaseModel, ConfigDict

T = TypeVar("T")


def to_camel(s: str) -> str:
    parts = s.split("_")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


class CamelModel(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        alias_generator=to_camel,
        populate_by_name=True,
    )


class ErrorResponse(BaseModel):
    detail: str


class PaginatedResponse[T](BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
    )

    items: list[T]
    total: int
    page: int
    page_size: int
    total_pages: int


class OkResponse(BaseModel):
    ok: bool = True


# Keep SuccessResponse as alias for backward compatibility
SuccessResponse = OkResponse
