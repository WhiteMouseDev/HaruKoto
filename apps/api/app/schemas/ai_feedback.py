"""Validated provider output, separate from the backward-compatible public schemas."""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import to_camel

Score = Annotated[int, Field(strict=True, ge=0, le=100)] | Annotated[float, Field(strict=True, ge=0, le=100, allow_inf_nan=False)]


class FeedbackOutput(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, strict=True, extra="forbid")

    overall_score: Score
    fluency: Score
    accuracy: Score
    vocabulary_diversity: Score
    naturalness: Score
    strengths: list[str]
    improvements: list[str]


class TextFeedbackOutput(FeedbackOutput):
    recommended_expressions: list[str]


class RecommendedExpression(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    ja: str
    ko: str


class GrammarCorrection(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    original: str
    corrected: str
    explanation: str


class TranslatedMessage(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    role: Literal["user", "assistant"]
    ja: str
    ko: str


class LiveFeedbackOutput(FeedbackOutput):
    recommended_expressions: list[RecommendedExpression]
    corrections: list[GrammarCorrection]
    translated_transcript: list[TranslatedMessage]
