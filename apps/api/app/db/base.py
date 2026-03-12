import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from app.enums import (
    ConversationType,
    Difficulty,
    JlptLevel,
    KanaType,
    PartOfSpeech,
    PaymentStatus,
    QuizType,
    ScenarioCategory,
    SubscriptionPlan,
    SubscriptionStatus,
    UserGoal,
    WordbookSource,
)


class Base(DeclarativeBase):
    type_annotation_map = {
        JlptLevel: Enum(JlptLevel, name="JlptLevel", create_constraint=False, native_enum=True),
        PartOfSpeech: Enum(PartOfSpeech, name="PartOfSpeech", create_constraint=False, native_enum=True),
        QuizType: Enum(QuizType, name="QuizType", create_constraint=False, native_enum=True),
        KanaType: Enum(KanaType, name="KanaType", create_constraint=False, native_enum=True),
        ScenarioCategory: Enum(ScenarioCategory, name="ScenarioCategory", create_constraint=False, native_enum=True),
        Difficulty: Enum(Difficulty, name="Difficulty", create_constraint=False, native_enum=True),
        UserGoal: Enum(UserGoal, name="UserGoal", create_constraint=False, native_enum=True),
        WordbookSource: Enum(WordbookSource, name="WordbookSource", create_constraint=False, native_enum=True),
        SubscriptionPlan: Enum(SubscriptionPlan, name="SubscriptionPlan", create_constraint=False, native_enum=True),
        SubscriptionStatus: Enum(SubscriptionStatus, name="SubscriptionStatus", create_constraint=False, native_enum=True),
        PaymentStatus: Enum(PaymentStatus, name="PaymentStatus", create_constraint=False, native_enum=True),
        ConversationType: Enum(ConversationType, name="ConversationType", create_constraint=False, native_enum=True),
    }


class UUIDMixin:
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
