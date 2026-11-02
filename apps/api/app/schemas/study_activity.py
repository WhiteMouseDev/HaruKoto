"""Strict private lesson activity protocol; answers are not graded here."""

from datetime import date, datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import UUID4, ConfigDict, Field, StrictInt, StrictStr

from app.schemas.common import CamelModel


class RecognitionActivityAnswer(CamelModel):
    model_config = ConfigDict(extra="forbid")
    question_order: Annotated[StrictInt, Field(ge=1)]
    selected_answer: Annotated[StrictStr, Field(min_length=1, max_length=4096)]


class ReorderActivityAnswer(CamelModel):
    model_config = ConfigDict(extra="forbid")
    question_order: Annotated[StrictInt, Field(ge=1)]
    submitted_order: Annotated[list[Annotated[StrictStr, Field(min_length=1, max_length=4096)]], Field(min_length=1, max_length=256)]


class MatchingActivityAnswer(CamelModel):
    model_config = ConfigDict(extra="forbid")
    left_vocabulary_id: UUID
    right_vocabulary_id: UUID


class _ActivityRequest(CamelModel):
    model_config = ConfigDict(extra="forbid")
    expected_user_id: UUID
    attempt_id: UUID4
    activity_id: UUID4
    content_version: Annotated[StrictStr, Field(pattern="^[0-9a-f]{64}$")]


class RecognitionStudyActivityRequest(_ActivityRequest):
    kind: Literal["RECOGNITION"]
    answer: RecognitionActivityAnswer


class ReorderStudyActivityRequest(_ActivityRequest):
    kind: Literal["SENTENCE_REORDER"]
    answer: ReorderActivityAnswer


class MatchingStudyActivityRequest(_ActivityRequest):
    kind: Literal["MATCHING"]
    answer: MatchingActivityAnswer


type LessonStudyActivityRequest = Annotated[
    RecognitionStudyActivityRequest | ReorderStudyActivityRequest | MatchingStudyActivityRequest,
    Field(discriminator="kind"),
]


class LessonStudyActivityResponse(CamelModel):
    model_config = ConfigDict(extra="forbid")
    activity_id: UUID4
    processed_at: datetime
    study_date: date
