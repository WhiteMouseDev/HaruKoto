"""Lesson API endpoints.

GET  /api/v1/lessons/chapters          — 챕터 목록 + 유저 진도
GET  /api/v1/lessons/review/summary    — SRS 복습 요약 (due/new 카드 수)
GET  /api/v1/lessons/{lesson_id}       — 레슨 상세 (대화문 + 문제, 정답 제거)
POST /api/v1/lessons/{lesson_id}/start — 레슨 시작
POST /api/v1/lessons/{lesson_id}/submit — 퀴즈 결과 제출
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.lesson import (
    ChapterListResponse,
    ChapterResponse,
    GrammarItem,
    LessonDetailResponse,
    LessonProgressResponse,
    LessonSubmitRequest,
    LessonSubmitResponse,
    LessonSummary,
    QuestionResult,
    ReviewSummaryResponse,
    VocabItem,
)
from app.services.lesson_command import (
    LessonServiceError,
    start_lesson_progress,
    submit_lesson_attempt,
)
from app.services.lesson_detail_query import get_lesson_detail_data
from app.services.lesson_query import (
    get_chapters_data,
    get_review_summary_data,
)

router = APIRouter(prefix="/api/v1/lessons", tags=["lessons"])


# ── GET /chapters ──


@router.get("/chapters", response_model=ChapterListResponse, status_code=200)
async def get_chapters(
    jlpt_level: str = Query(default="N5", alias="jlptLevel"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ChapterListResponse:
    """챕터 목록 + 각 레슨의 유저 진도를 반환한다."""
    chapters = await get_chapters_data(
        db,
        user,
        jlpt_level=jlpt_level,
    )

    return ChapterListResponse(
        chapters=[
            ChapterResponse(
                id=chapter.id,
                jlpt_level=chapter.jlpt_level,
                part_no=chapter.part_no,
                chapter_no=chapter.chapter_no,
                title=chapter.title,
                topic=chapter.topic,
                lessons=[
                    LessonSummary(
                        id=lesson.id,
                        lesson_no=lesson.lesson_no,
                        chapter_lesson_no=lesson.chapter_lesson_no,
                        title=lesson.title,
                        topic=lesson.topic,
                        estimated_minutes=lesson.estimated_minutes,
                        status=lesson.status,
                        score_correct=lesson.score_correct,
                        score_total=lesson.score_total,
                    )
                    for lesson in chapter.lessons
                ],
                completed_lessons=chapter.completed_lessons,
                total_lessons=chapter.total_lessons,
            )
            for chapter in chapters
        ]
    )


# ── GET /review/summary ──


@router.get("/review/summary", response_model=ReviewSummaryResponse, status_code=200)
async def get_review_summary(
    jlpt_level: Annotated[str, Query(alias="jlptLevel")] = "N5",
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ReviewSummaryResponse:
    """SRS 복습 요약: due 카드 수 + 새 카드 수를 반환한다."""
    summary = await get_review_summary_data(
        db,
        user,
        jlpt_level=jlpt_level,
    )

    return ReviewSummaryResponse(
        word_due=summary.word_due,
        grammar_due=summary.grammar_due,
        total_due=summary.total_due,
        word_new=summary.word_new,
        grammar_new=summary.grammar_new,
    )


# ── GET /{lesson_id} ──


@router.get("/{lesson_id}", response_model=LessonDetailResponse, status_code=200)
async def get_lesson_detail(
    lesson_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LessonDetailResponse:
    """레슨 상세: 대화문 + 문제 (정답은 제거하여 클라이언트에 전달)."""
    lesson = await get_lesson_detail_data(
        db,
        user,
        lesson_id=lesson_id,
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="레슨을 찾을 수 없습니다")

    return LessonDetailResponse(
        id=lesson.id,
        lesson_no=lesson.lesson_no,
        chapter_lesson_no=lesson.chapter_lesson_no,
        title=lesson.title,
        topic=lesson.topic,
        estimated_minutes=lesson.estimated_minutes,
        content=lesson.content,
        vocab_items=[
            VocabItem(
                id=item.id,
                word=item.word,
                reading=item.reading,
                meaning_ko=item.meaning_ko,
                part_of_speech=item.part_of_speech,
            )
            for item in lesson.vocab_items
        ],
        grammar_items=[
            GrammarItem(
                id=item.id,
                pattern=item.pattern,
                meaning_ko=item.meaning_ko,
                explanation=item.explanation,
            )
            for item in lesson.grammar_items
        ],
        progress=(
            LessonProgressResponse(
                status=lesson.progress.status,
                attempts=lesson.progress.attempts,
                score_correct=lesson.progress.score_correct,
                score_total=lesson.progress.score_total,
                started_at=lesson.progress.started_at,
                completed_at=lesson.progress.completed_at,
                srs_registered_at=lesson.progress.srs_registered_at,
            )
            if lesson.progress
            else None
        ),
    )


# ── POST /{lesson_id}/start ──


@router.post("/{lesson_id}/start", response_model=LessonProgressResponse, status_code=200)
async def start_lesson(
    lesson_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LessonProgressResponse:
    """레슨 시작: 진도를 IN_PROGRESS로 업데이트한다."""
    try:
        progress = await start_lesson_progress(
            db,
            user,
            lesson_id=lesson_id,
        )
    except LessonServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return LessonProgressResponse(
        status=progress.status,
        attempts=progress.attempts,
        score_correct=progress.score_correct,
        score_total=progress.score_total,
        started_at=progress.started_at,
        completed_at=progress.completed_at,
        srs_registered_at=progress.srs_registered_at,
    )


# ── POST /{lesson_id}/submit ──


@router.post("/{lesson_id}/submit", response_model=LessonSubmitResponse, status_code=200)
async def submit_lesson(
    lesson_id: UUID,
    body: LessonSubmitRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LessonSubmitResponse:
    """퀴즈 결과 제출: 채점 → SRS 처리 → 진도 업데이트."""
    try:
        result = await submit_lesson_attempt(
            db,
            user,
            lesson_id=lesson_id,
            answers=body.answers,
        )
    except LessonServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return LessonSubmitResponse(
        score_correct=result.score_correct,
        score_total=result.score_total,
        results=[
            QuestionResult(
                order=item.order,
                is_correct=item.is_correct,
                correct_answer=item.correct_answer,
                correct_order=item.correct_order,
                explanation=item.explanation,
                state_before=item.state_before,
                state_after=item.state_after,
                next_review_at=item.next_review_at,
                is_provisional_phase=item.is_provisional_phase,
            )
            for item in result.results
        ],
        status=result.status,
        srs_items_registered=result.srs_items_registered,
    )
