"""Lesson API endpoints.

GET  /api/v1/lessons/chapters          — 챕터 목록 + 유저 진도
GET  /api/v1/lessons/review/summary    — SRS 복습 요약 (due/new 카드 수)
GET  /api/v1/lessons/{lesson_id}       — 레슨 상세 (대화문 + 문제, 정답 제거)
POST /api/v1/lessons/{lesson_id}/start — 레슨 시작
POST /api/v1/lessons/{lesson_id}/submit — 퀴즈 결과 제출
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

import sqlalchemy as sa
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.dependencies import get_current_user
from app.models.content import Grammar, Vocabulary
from app.models.lesson import Chapter, Lesson, LessonItemLink, UserLessonProgress
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.models.user import User
from app.schemas.lesson import (
    AnswerSubmission,
    ChapterListResponse,
    ChapterResponse,
    GrammarItem,
    LessonContent,
    LessonDetailResponse,
    LessonProgressResponse,
    LessonSubmitRequest,
    LessonSubmitResponse,
    LessonSummary,
    QuestionResult,
    ReviewSummaryResponse,
    VocabItem,
)
from app.services.srs import process_answer, register_items_from_lesson

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/lessons", tags=["lessons"])


# ── GET /chapters ──


@router.get("/chapters", response_model=ChapterListResponse, status_code=200)
async def get_chapters(
    jlpt_level: str = Query(default="N5", alias="jlptLevel"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """챕터 목록 + 각 레슨의 유저 진도를 반환한다."""
    # ABSOLUTE_ZERO → N5 매핑
    effective_level = "N5" if jlpt_level == "ABSOLUTE_ZERO" else jlpt_level

    result = await db.execute(
        select(Chapter)
        .where(cast(Chapter.jlpt_level, sa.Text()) == effective_level, Chapter.is_published.is_(True))
        .options(selectinload(Chapter.lessons))
        .order_by(Chapter.part_no, Chapter.chapter_no)
    )
    chapters = result.scalars().unique().all()

    # Fetch user progress for all lessons at once
    lesson_ids = [ls.id for ch in chapters for ls in ch.lessons]
    progress_map: dict[UUID, UserLessonProgress] = {}
    if lesson_ids:
        prog_result = await db.execute(
            select(UserLessonProgress).where(
                UserLessonProgress.user_id == user.id,
                UserLessonProgress.lesson_id.in_(lesson_ids),
            )
        )
        for p in prog_result.scalars().all():
            progress_map[p.lesson_id] = p

    chapter_responses = []
    for ch in chapters:
        published_lessons = sorted(
            [ls for ls in ch.lessons if ls.is_published],
            key=lambda ls: ls.chapter_lesson_no,
        )
        lesson_summaries = []
        completed = 0
        for ls in published_lessons:
            prog = progress_map.get(ls.id)
            status = prog.status if prog else "NOT_STARTED"
            if status == "COMPLETED":
                completed += 1
            lesson_summaries.append(
                LessonSummary(
                    id=ls.id,
                    lesson_no=ls.lesson_no,
                    chapter_lesson_no=ls.chapter_lesson_no,
                    title=ls.title,
                    topic=ls.topic,
                    estimated_minutes=ls.estimated_minutes,
                    status=status,
                    score_correct=prog.score_correct if prog else 0,
                    score_total=prog.score_total if prog else 0,
                )
            )

        chapter_responses.append(
            ChapterResponse(
                id=ch.id,
                jlpt_level=str(ch.jlpt_level),
                part_no=ch.part_no,
                chapter_no=ch.chapter_no,
                title=ch.title,
                topic=ch.topic,
                lessons=lesson_summaries,
                completed_lessons=completed,
                total_lessons=len(published_lessons),
            )
        )

    return ChapterListResponse(chapters=chapter_responses)


# ── GET /review/summary ──


@router.get("/review/summary", response_model=ReviewSummaryResponse, status_code=200)
async def get_review_summary(
    jlpt_level: Annotated[str, Query(alias="jlptLevel")] = "N5",
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """SRS 복습 요약: due 카드 수 + 새 카드 수를 반환한다."""
    # ABSOLUTE_ZERO maps to N5 for content queries
    effective_level = "N5" if jlpt_level == "ABSOLUTE_ZERO" else jlpt_level
    now = datetime.now(UTC)

    due_states = ("RELEARNING", "LEARNING", "REVIEW", "PROVISIONAL")

    # ── Due WORD items ──
    word_due_result = await db.execute(
        select(func.count())
        .select_from(UserVocabProgress)
        .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.state.in_(due_states),
            UserVocabProgress.next_review_at <= now,
            Vocabulary.jlpt_level == effective_level,
        )
    )
    word_due = word_due_result.scalar() or 0

    # ── Due GRAMMAR items ──
    grammar_due_result = await db.execute(
        select(func.count())
        .select_from(UserGrammarProgress)
        .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
        .where(
            UserGrammarProgress.user_id == user.id,
            UserGrammarProgress.state.in_(due_states),
            UserGrammarProgress.next_review_at <= now,
            Grammar.jlpt_level == effective_level,
        )
    )
    grammar_due = grammar_due_result.scalar() or 0

    # ── New WORD items: UNSEEN state + no progress record ──
    word_unseen_result = await db.execute(
        select(func.count())
        .select_from(UserVocabProgress)
        .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
        .where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.state == "UNSEEN",
            Vocabulary.jlpt_level == effective_level,
        )
    )
    word_unseen = word_unseen_result.scalar() or 0

    # Words with no progress record at all
    existing_vocab_ids = select(UserVocabProgress.vocabulary_id).where(UserVocabProgress.user_id == user.id).scalar_subquery()
    word_no_record_result = await db.execute(
        select(func.count())
        .select_from(Vocabulary)
        .where(
            Vocabulary.jlpt_level == effective_level,
            Vocabulary.id.notin_(existing_vocab_ids),
        )
    )
    word_no_record = word_no_record_result.scalar() or 0
    word_new = word_unseen + word_no_record

    # ── New GRAMMAR items: UNSEEN state + no progress record ──
    grammar_unseen_result = await db.execute(
        select(func.count())
        .select_from(UserGrammarProgress)
        .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
        .where(
            UserGrammarProgress.user_id == user.id,
            UserGrammarProgress.state == "UNSEEN",
            Grammar.jlpt_level == effective_level,
        )
    )
    grammar_unseen = grammar_unseen_result.scalar() or 0

    existing_grammar_ids = select(UserGrammarProgress.grammar_id).where(UserGrammarProgress.user_id == user.id).scalar_subquery()
    grammar_no_record_result = await db.execute(
        select(func.count())
        .select_from(Grammar)
        .where(
            Grammar.jlpt_level == effective_level,
            Grammar.id.notin_(existing_grammar_ids),
        )
    )
    grammar_no_record = grammar_no_record_result.scalar() or 0
    grammar_new = grammar_unseen + grammar_no_record

    return ReviewSummaryResponse(
        word_due=word_due,
        grammar_due=grammar_due,
        total_due=word_due + grammar_due,
        word_new=word_new,
        grammar_new=grammar_new,
    )


# ── GET /{lesson_id} ──


@router.get("/{lesson_id}", response_model=LessonDetailResponse, status_code=200)
async def get_lesson_detail(
    lesson_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """레슨 상세: 대화문 + 문제 (정답은 제거하여 클라이언트에 전달)."""
    result = await db.execute(
        select(Lesson).where(Lesson.id == lesson_id, Lesson.is_published.is_(True)).options(selectinload(Lesson.item_links))
    )
    lesson = result.scalar_one_or_none()
    if lesson is None:
        raise HTTPException(status_code=404, detail="레슨을 찾을 수 없습니다")

    # Parse content_jsonb
    content_raw = lesson.content_jsonb or {}
    content = LessonContent.model_validate(content_raw)

    # Strip correct answers from questions (prevent cheating)
    for q in content.questions:
        q.correct_answer = None
        q.correct_order = None

    # Fetch linked vocab/grammar items (batch query to avoid N+1)
    vocab_ids = [lk.vocabulary_id for lk in lesson.item_links if lk.item_type == "WORD" and lk.vocabulary_id]
    grammar_ids = [lk.grammar_id for lk in lesson.item_links if lk.item_type == "GRAMMAR" and lk.grammar_id]

    vocab_map: dict[UUID, Vocabulary] = {}
    if vocab_ids:
        vr = await db.execute(select(Vocabulary).where(Vocabulary.id.in_(vocab_ids)))
        vocab_map = {v.id: v for v in vr.scalars().all()}

    grammar_map: dict[UUID, Grammar] = {}
    if grammar_ids:
        gr = await db.execute(select(Grammar).where(Grammar.id.in_(grammar_ids)))
        grammar_map = {g.id: g for g in gr.scalars().all()}

    vocab_items: list[VocabItem] = []
    grammar_items: list[GrammarItem] = []
    for link in sorted(lesson.item_links, key=lambda x: x.item_order):
        if link.item_type == "WORD" and link.vocabulary_id:
            vocab = vocab_map.get(link.vocabulary_id)
            if vocab:
                vocab_items.append(
                    VocabItem(
                        id=vocab.id,
                        word=vocab.word,
                        reading=vocab.reading,
                        meaning_ko=vocab.meaning_ko,
                        part_of_speech=str(vocab.part_of_speech),
                    )
                )
        elif link.item_type == "GRAMMAR" and link.grammar_id:
            grammar = grammar_map.get(link.grammar_id)
            if grammar:
                grammar_items.append(
                    GrammarItem(
                        id=grammar.id,
                        pattern=grammar.pattern,
                        meaning_ko=grammar.meaning_ko,
                        explanation=grammar.explanation,
                    )
                )

    # Fetch user progress
    prog_result = await db.execute(
        select(UserLessonProgress).where(
            UserLessonProgress.user_id == user.id,
            UserLessonProgress.lesson_id == lesson.id,
        )
    )
    prog = prog_result.scalar_one_or_none()
    progress = None
    if prog:
        progress = LessonProgressResponse(
            status=prog.status,
            attempts=prog.attempts,
            score_correct=prog.score_correct,
            score_total=prog.score_total,
            started_at=prog.started_at,
            completed_at=prog.completed_at,
            srs_registered_at=getattr(prog, "srs_registered_at", None),
        )

    return LessonDetailResponse(
        id=lesson.id,
        lesson_no=lesson.lesson_no,
        chapter_lesson_no=lesson.chapter_lesson_no,
        title=lesson.title,
        topic=lesson.topic,
        estimated_minutes=lesson.estimated_minutes,
        content=content,
        vocab_items=vocab_items,
        grammar_items=grammar_items,
        progress=progress,
    )


# ── POST /{lesson_id}/start ──


@router.post("/{lesson_id}/start", response_model=LessonProgressResponse, status_code=200)
async def start_lesson(
    lesson_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """레슨 시작: 진도를 IN_PROGRESS로 업데이트한다."""
    lesson = await db.get(Lesson, lesson_id)
    if lesson is None or not lesson.is_published:
        raise HTTPException(status_code=404, detail="레슨을 찾을 수 없습니다")

    result = await db.execute(
        select(UserLessonProgress).where(
            UserLessonProgress.user_id == user.id,
            UserLessonProgress.lesson_id == lesson_id,
        )
    )
    prog = result.scalar_one_or_none()

    now = datetime.now(UTC)
    if prog is None:
        prog = UserLessonProgress(
            user_id=user.id,
            lesson_id=lesson_id,
            status="IN_PROGRESS",
            started_at=now,
        )
        db.add(prog)
    elif prog.status == "NOT_STARTED":
        prog.status = "IN_PROGRESS"
        prog.started_at = now

    await db.commit()
    await db.refresh(prog)

    return LessonProgressResponse(
        status=prog.status,
        attempts=prog.attempts,
        score_correct=prog.score_correct,
        score_total=prog.score_total,
        started_at=prog.started_at,
        completed_at=prog.completed_at,
        srs_registered_at=getattr(prog, "srs_registered_at", None),
    )


# ── POST /{lesson_id}/submit ──


@router.post("/{lesson_id}/submit", response_model=LessonSubmitResponse, status_code=200)
async def submit_lesson(
    lesson_id: UUID,
    body: LessonSubmitRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """퀴즈 결과 제출: 채점 → SRS 처리 → 진도 업데이트."""
    # Load lesson with item_links eagerly
    result = await db.execute(select(Lesson).where(Lesson.id == lesson_id).options(selectinload(Lesson.item_links)))
    lesson = result.scalar_one_or_none()
    if lesson is None:
        raise HTTPException(status_code=404, detail="레슨을 찾을 수 없습니다")

    content_raw = lesson.content_jsonb or {}
    questions_raw = content_raw.get("questions", [])

    # Build answer key from content_jsonb
    answer_key: dict[int, dict] = {}
    for q in questions_raw:
        answer_key[q["order"]] = q

    # Build mapping from question order → vocab/grammar item via lesson_item_links.
    # A question is mappable if it has a "vocabulary_id" or "grammar_id" field in
    # content_jsonb, OR we fall back to positional mapping (item_order == question order)
    # for VOCAB_MCQ questions where there is exactly one item link per order.
    item_links_by_order: dict[int, LessonItemLink] = {link.item_order: link for link in lesson.item_links}

    # Also build a lookup by item_id stored in the question's content_jsonb
    question_to_link: dict[int, LessonItemLink] = {}
    for q in questions_raw:
        q_order = q["order"]
        # Direct mapping: question has vocabulary_id or grammar_id in jsonb
        q_vocab_id = q.get("vocabulary_id")
        q_grammar_id = q.get("grammar_id")
        if q_vocab_id:
            for link in lesson.item_links:
                if link.item_type == "WORD" and str(link.vocabulary_id) == str(q_vocab_id):
                    question_to_link[q_order] = link
                    break
        elif q_grammar_id:
            for link in lesson.item_links:
                if link.item_type == "GRAMMAR" and str(link.grammar_id) == str(q_grammar_id):
                    question_to_link[q_order] = link
                    break
        else:
            # Fallback: positional mapping (item_order == question order)
            if q_order in item_links_by_order:
                question_to_link[q_order] = item_links_by_order[q_order]

    # Grade each answer and process SRS
    results: list[QuestionResult] = []
    correct_count = 0
    srs_items_registered = 0

    for ans in body.answers:
        q_data = answer_key.get(ans.order)
        if q_data is None:
            continue

        is_correct = _grade_answer(ans, q_data)
        if is_correct:
            correct_count += 1

        # SRS: process answer for mapped items (nested savepoint for isolation)
        srs_result = None
        link = question_to_link.get(ans.order)
        if link is not None:
            item_id = link.vocabulary_id if link.item_type == "WORD" else link.grammar_id
            if item_id is not None:
                try:
                    async with db.begin_nested():
                        srs_result = await process_answer(
                            db=db,
                            user_id=user.id,
                            item_type=link.item_type,
                            item_id=item_id,
                            is_correct=is_correct,
                            direction="JP_KR",  # lesson context default
                            response_ms=ans.response_ms,
                            session_id=None,
                            lesson_id=lesson_id,
                        )
                except Exception:
                    logger.warning(
                        "SRS process_answer failed for item %s in lesson %s",
                        item_id,
                        lesson_id,
                        exc_info=True,
                    )

        results.append(
            QuestionResult(
                order=ans.order,
                is_correct=is_correct,
                correct_answer=q_data.get("correct_answer"),
                correct_order=q_data.get("correct_order"),
                explanation=q_data.get("explanation"),
                state_before=srs_result["state_before"] if srs_result else None,
                state_after=srs_result["state_after"] if srs_result else None,
                next_review_at=srs_result["next_review_at"] if srs_result else None,
                is_provisional_phase=srs_result["is_provisional_phase"] if srs_result else False,
            )
        )

    total = len(results)

    # SRS: register all lesson items (nested savepoint for isolation)
    try:
        async with db.begin_nested():
            srs_items_registered = await register_items_from_lesson(
                db=db,
                user_id=user.id,
                lesson_id=lesson_id,
                item_links=list(lesson.item_links),
            )
    except Exception:
        logger.warning(
            "SRS register_items_from_lesson failed for lesson %s",
            lesson_id,
            exc_info=True,
        )

    # Update progress
    prog_result = await db.execute(
        select(UserLessonProgress).where(
            UserLessonProgress.user_id == user.id,
            UserLessonProgress.lesson_id == lesson_id,
        )
    )
    prog = prog_result.scalar_one_or_none()
    now = datetime.now(UTC)

    if prog is None:
        prog = UserLessonProgress(
            user_id=user.id,
            lesson_id=lesson_id,
            status="COMPLETED",
            attempts=1,
            score_correct=correct_count,
            score_total=total,
            started_at=now,
            completed_at=now,
            srs_registered_at=now if srs_items_registered > 0 else None,
        )
        db.add(prog)
    else:
        prog.attempts += 1
        prog.score_correct = correct_count
        prog.score_total = total
        prog.status = "COMPLETED"
        prog.completed_at = now
        if srs_items_registered > 0 and prog.srs_registered_at is None:
            prog.srs_registered_at = now

    await db.commit()

    return LessonSubmitResponse(
        score_correct=correct_count,
        score_total=total,
        results=results,
        status=prog.status,
        srs_items_registered=srs_items_registered,
    )


def _grade_answer(ans: AnswerSubmission, q_data: dict) -> bool:
    """Grade a single answer against the answer key."""
    q_type = q_data.get("type", "")

    if q_type == "SENTENCE_REORDER":
        correct_order = q_data.get("correct_order", [])
        return ans.submitted_order == correct_order

    # VOCAB_MCQ, CONTEXT_CLOZE
    correct = q_data.get("correct_answer", "")
    return ans.selected_answer == correct
