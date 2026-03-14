"""Seed study stages for N5 level.

Usage:
    cd apps/api
    python -m app.seeds.study_stages
"""
from __future__ import annotations

import asyncio
import math
import uuid

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings
from app.models.content import Grammar, SentenceArrangeQuestion, Vocabulary
from app.models.stage import StudyStage

# Stage definitions for N5 vocabulary (title, description, optional tag filter)
VOCAB_STAGE_DEFS = [
    ("기본 인사말", "일상에서 자주 쓰는 인사 표현"),
    ("숫자와 시간", "숫자, 날짜, 시간 관련 단어"),
    ("가족과 사람", "가족 호칭과 사람 관련 단어"),
    ("음식과 음료", "일본 음식과 음료 관련 단어"),
    ("장소와 방향", "위치, 방향, 장소 관련 단어"),
    ("일상 동사 1", "매일 쓰는 기본 동사"),
    ("일상 동사 2", "자주 쓰는 동사 추가"),
    ("형용사 기초", "기본 い형용사와 な형용사"),
    ("학교와 직장", "학교, 직장 관련 단어"),
    ("쇼핑과 교통", "쇼핑, 교통 관련 단어"),
    ("날씨와 계절", "날씨, 계절, 자연 관련 단어"),
    ("몸과 건강", "신체, 건강 관련 단어"),
    ("취미와 여가", "취미, 스포츠, 여가 관련 단어"),
    ("기본 부사/접속사", "자주 쓰는 부사와 접속사"),
    ("종합 복습", "N5 단어 종합 복습"),
]

GRAMMAR_STAGE_DEFS = [
    ("~です/~ます", "정중체 기본 문형"),
    ("조사 기초 (は/が/を)", "기본 조사 사용법"),
    ("조사 심화 (に/で/へ/と)", "장소, 방향, 수단 조사"),
    ("형용사 활용", "い형용사/な형용사 활용"),
    ("동사 활용 기초", "동사 て형, ない형"),
    ("~たい/~ましょう", "희망, 권유 표현"),
    ("~から/~まで", "이유, 범위 표현"),
    ("존재 표현", "いる/ある 사용법"),
    ("비교 표현", "~より/~のほうが 비교"),
    ("종합 복습", "N5 문법 종합 복습"),
]

SENTENCE_STAGE_DEFS = [
    ("기본 어순 연습", "주어-목적어-동사 기본 어순"),
    ("조사 배치 연습", "올바른 조사 위치 연습"),
    ("시제 표현 연습", "과거/현재/미래 문장 배열"),
    ("의문문 만들기", "의문사를 활용한 문장 배열"),
    ("복합 문장 연습", "접속사를 활용한 문장 배열"),
    ("종합 복습", "N5 문장배열 종합 복습"),
]

ITEMS_PER_STAGE = 12


async def _chunk_and_create_stages(
    db: AsyncSession,
    items: list,
    category: str,
    jlpt_level: str,
    stage_defs: list[tuple[str, str]],
) -> list[StudyStage]:
    """Chunk items into stages and create StudyStage records."""
    if not items:
        return []

    # Calculate chunk size based on available items and stage definitions
    num_stages = min(len(stage_defs), max(1, math.ceil(len(items) / ITEMS_PER_STAGE)))
    chunk_size = max(1, math.ceil(len(items) / num_stages))

    stages: list[StudyStage] = []
    prev_stage_id: uuid.UUID | None = None

    for i in range(num_stages):
        start = i * chunk_size
        end = min(start + chunk_size, len(items))
        chunk = items[start:end]
        if not chunk:
            break

        title, description = stage_defs[i] if i < len(stage_defs) else (f"스테이지 {i + 1}", "")
        content_id_list = [str(item.id) for item in chunk]

        stage_id = uuid.uuid4()
        stmt = pg_insert(StudyStage).values(
            id=stage_id,
            category=category,
            jlpt_level=jlpt_level,
            stage_number=i + 1,
            title=title,
            description=description,
            content_ids=content_id_list,
            unlock_after=prev_stage_id,
            order=i,
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=["category", "jlpt_level", "stage_number"],
            set_={
                "title": title,
                "description": description,
                "content_ids": content_id_list,
                "unlock_after": prev_stage_id,
                "order": i,
            },
        )
        result = await db.execute(stmt)  # noqa: F841

        # Re-fetch the stage to get actual id (in case of upsert)
        fetch_result = await db.execute(
            select(StudyStage).where(
                StudyStage.category == category,
                StudyStage.jlpt_level == jlpt_level,
                StudyStage.stage_number == i + 1,
            )
        )
        stage = fetch_result.scalar_one()
        stages.append(stage)
        prev_stage_id = stage.id

    return stages


async def seed_study_stages(db: AsyncSession) -> dict[str, int]:
    """Seed study stages for N5 level. Returns count of stages created per category."""
    jlpt_level = "N5"
    counts: dict[str, int] = {}

    # 1. Vocabulary stages
    vocab_result = await db.execute(
        select(Vocabulary)
        .where(Vocabulary.jlpt_level == jlpt_level)
        .order_by(Vocabulary.order, Vocabulary.id)
    )
    vocabs = vocab_result.scalars().all()
    vocab_stages = await _chunk_and_create_stages(db, list(vocabs), "VOCABULARY", jlpt_level, VOCAB_STAGE_DEFS)
    counts["VOCABULARY"] = len(vocab_stages)

    # 2. Grammar stages
    grammar_result = await db.execute(
        select(Grammar)
        .where(Grammar.jlpt_level == jlpt_level)
        .order_by(Grammar.order, Grammar.id)
    )
    grammars = grammar_result.scalars().all()
    grammar_stages = await _chunk_and_create_stages(db, list(grammars), "GRAMMAR", jlpt_level, GRAMMAR_STAGE_DEFS)
    counts["GRAMMAR"] = len(grammar_stages)

    # 3. Sentence arrange stages
    sentence_result = await db.execute(
        select(SentenceArrangeQuestion)
        .where(SentenceArrangeQuestion.jlpt_level == jlpt_level)
        .order_by(SentenceArrangeQuestion.order, SentenceArrangeQuestion.id)
    )
    sentences = sentence_result.scalars().all()
    sentence_stages = await _chunk_and_create_stages(db, list(sentences), "SENTENCE", jlpt_level, SENTENCE_STAGE_DEFS)
    counts["SENTENCE"] = len(sentence_stages)

    await db.commit()
    return counts


async def main() -> None:
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as db:
        counts = await seed_study_stages(db)
        for category, count in counts.items():
            print(f"  {category}: {count} stages created")

    await engine.dispose()
    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
