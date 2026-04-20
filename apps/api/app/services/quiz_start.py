from __future__ import annotations

import random
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Grammar,
    QuizSession,
    UserGrammarProgress,
    UserVocabProgress,
    Vocabulary,
)
from app.models.user import User
from app.schemas.quiz import MatchingPair, QuizStartRequest, SmartStartRequest
from app.services.distractor import generate_distractors
from app.services.quiz_mode_questions import load_cloze_questions, load_sentence_arrange_questions
from app.services.quiz_policy import calculate_smart_distribution
from app.services.quiz_question_builder import build_grammar_question, build_options, build_vocab_question
from app.services.quiz_session import (
    auto_complete_sessions,
    build_session_questions_data,
    fetch_stage_content_ids,
    generate_matching_pairs,
)
from app.services.quiz_smart import load_smart_pool_stats
from app.utils.constants import QUIZ_CONFIG, SRS_CONFIG


class QuizStartServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class QuizStartResult:
    session: QuizSession
    questions: list[dict[str, Any]]
    matching_pairs: list[MatchingPair] | None = None


async def _create_quiz_session(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    quiz_type: Any,
    jlpt_level: Any,
    questions: list[dict[str, Any]],
    mode: str | None = None,
    stage_id: uuid.UUID | None = None,
) -> QuizSession:
    session = QuizSession(
        user_id=user_id,
        quiz_type=quiz_type,
        jlpt_level=jlpt_level,
        total_questions=len(questions),
        questions_data=build_session_questions_data(questions, mode=mode, stage_id=stage_id),
    )
    try:
        db.add(session)
        await db.commit()
        await db.refresh(session)
    except Exception as exc:
        await db.rollback()
        raise QuizStartServiceError(status_code=500, detail="퀴즈 세션 생성에 실패했습니다") from exc
    return session


async def start_quiz_session(
    db: AsyncSession,
    user: User,
    body: QuizStartRequest,
) -> QuizStartResult:
    await auto_complete_sessions(db, user)

    mode = body.mode
    quiz_type = body.quiz_type.value
    jlpt_level = body.jlpt_level.value
    count = body.count

    questions: list[dict[str, Any]] = []
    matching_pairs: list[MatchingPair] | None = None
    stage_content_ids: list[uuid.UUID] = []
    stage = None

    if body.stage_id:
        stage, stage_content_ids = await fetch_stage_content_ids(db, body.stage_id)
        if not stage:
            raise QuizStartServiceError(status_code=404, detail="스테이지를 찾을 수 없습니다")
        if not stage_content_ids:
            raise QuizStartServiceError(status_code=400, detail="스테이지에 콘텐츠가 없습니다")

    if mode == "matching":
        if not stage:
            raise QuizStartServiceError(status_code=400, detail="매칭 모드는 stage_id가 필요합니다")
        questions, matching_pairs = await generate_matching_pairs(db, stage, stage_content_ids, count)
    elif mode == "cloze":
        questions = await load_cloze_questions(db, jlpt_level=jlpt_level, count=count, stage_content_ids=stage_content_ids)
    elif mode == "arrange":
        questions = await load_sentence_arrange_questions(db, jlpt_level=jlpt_level, count=count, stage_content_ids=stage_content_ids)
    elif mode == "review":
        if quiz_type in ("VOCABULARY", "KANJI", "LISTENING"):
            query = (
                select(Vocabulary)
                .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
                .where(
                    UserVocabProgress.user_id == user.id,
                    Vocabulary.jlpt_level == jlpt_level,
                    UserVocabProgress.next_review_at <= datetime.now(UTC),
                )
                .order_by(UserVocabProgress.next_review_at)
            )
            if stage_content_ids:
                query = query.where(Vocabulary.id.in_(stage_content_ids))
            result = await db.execute(query.limit(count))
            review_items = result.scalars().all()
            pool_result = await db.execute(
                select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
            )
            all_meanings = list(pool_result.scalars().all())

            for vocab in review_items:
                wrong_texts = [meaning for meaning in all_meanings if meaning != vocab.meaning_ko][: QUIZ_CONFIG.WRONG_OPTIONS_COUNT]
                options, correct_id = build_options(vocab.meaning_ko, wrong_texts)
                questions.append(build_vocab_question(vocab, quiz_type, options, correct_id))
        else:
            query = (
                select(Grammar)
                .join(UserGrammarProgress, UserGrammarProgress.grammar_id == Grammar.id)
                .where(
                    UserGrammarProgress.user_id == user.id,
                    Grammar.jlpt_level == jlpt_level,
                    UserGrammarProgress.next_review_at <= datetime.now(UTC),
                )
            )
            if stage_content_ids:
                query = query.where(Grammar.id.in_(stage_content_ids))
            result = await db.execute(query.limit(count))
            items = result.scalars().all()
            pool_result = await db.execute(
                select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
            )
            all_meanings = list(pool_result.scalars().all())
            for grammar in items:
                wrong_texts = [meaning for meaning in all_meanings if meaning != grammar.meaning_ko][: QUIZ_CONFIG.WRONG_OPTIONS_COUNT]
                options, correct_id = build_options(grammar.meaning_ko, wrong_texts)
                questions.append(build_grammar_question(grammar, quiz_type, options, correct_id))
    else:
        if stage_content_ids and quiz_type in ("VOCABULARY", "KANJI", "LISTENING"):
            result = await db.execute(select(Vocabulary).where(Vocabulary.id.in_(stage_content_ids)).order_by(func.random()).limit(count))
            items = result.scalars().all()
            pool_result = await db.execute(
                select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
            )
            all_meanings = list(pool_result.scalars().all())
            for vocab in items:
                wrong_texts = [meaning for meaning in all_meanings if meaning != vocab.meaning_ko]
                random.shuffle(wrong_texts)
                options, correct_id = build_options(vocab.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
                questions.append(build_vocab_question(vocab, quiz_type, options, correct_id))
        elif stage_content_ids and quiz_type == "GRAMMAR":
            result = await db.execute(select(Grammar).where(Grammar.id.in_(stage_content_ids)).order_by(func.random()).limit(count))
            items = result.scalars().all()
            pool_result = await db.execute(
                select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
            )
            all_meanings = list(pool_result.scalars().all())
            for grammar in items:
                wrong_texts = [meaning for meaning in all_meanings if meaning != grammar.meaning_ko]
                random.shuffle(wrong_texts)
                options, correct_id = build_options(grammar.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
                questions.append(build_grammar_question(grammar, quiz_type, options, correct_id))
        elif quiz_type in ("VOCABULARY", "KANJI", "LISTENING"):
            result = await db.execute(select(Vocabulary).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(count))
            items = result.scalars().all()
            pool_result = await db.execute(
                select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
            )
            all_meanings = list(pool_result.scalars().all())
            for vocab in items:
                wrong_texts = [meaning for meaning in all_meanings if meaning != vocab.meaning_ko]
                random.shuffle(wrong_texts)
                options, correct_id = build_options(vocab.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
                questions.append(build_vocab_question(vocab, quiz_type, options, correct_id))
        elif quiz_type == "GRAMMAR":
            result = await db.execute(select(Grammar).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(count))
            items = result.scalars().all()
            pool_result = await db.execute(
                select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
            )
            all_meanings = list(pool_result.scalars().all())
            for grammar in items:
                wrong_texts = [meaning for meaning in all_meanings if meaning != grammar.meaning_ko]
                random.shuffle(wrong_texts)
                options, correct_id = build_options(grammar.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
                questions.append(build_grammar_question(grammar, quiz_type, options, correct_id))

    session = await _create_quiz_session(
        db,
        user_id=user.id,
        quiz_type=body.quiz_type,
        jlpt_level=body.jlpt_level,
        questions=questions,
        stage_id=body.stage_id,
    )
    return QuizStartResult(session=session, questions=questions, matching_pairs=matching_pairs)


async def start_smart_quiz_session(
    db: AsyncSession,
    user: User,
    body: SmartStartRequest,
) -> QuizStartResult:
    await auto_complete_sessions(db, user)

    now = datetime.now(UTC)
    category = body.category
    jlpt_level = body.jlpt_level.value
    quiz_type = "VOCABULARY" if category == "VOCABULARY" else "GRAMMAR"
    pool_stats = await load_smart_pool_stats(
        db,
        user_id=user.id,
        category=category,
        jlpt_level=jlpt_level,
        now=now,
    )
    distribution = calculate_smart_distribution(body.count, pool_stats.review_due, pool_stats.retry_due)
    questions: list[dict[str, Any]] = []

    if category == "VOCABULARY":
        if distribution["review"] > 0:
            review_result = await db.execute(
                select(Vocabulary)
                .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
                .where(
                    UserVocabProgress.user_id == user.id,
                    Vocabulary.jlpt_level == jlpt_level,
                    UserVocabProgress.next_review_at <= now,
                    UserVocabProgress.interval > 0,
                )
                .order_by(UserVocabProgress.next_review_at)
                .limit(distribution["review"])
            )
            review_items = list(review_result.scalars().all())
        else:
            review_items = []

        if distribution["retry"] > 0:
            retry_result = await db.execute(
                select(Vocabulary)
                .join(UserVocabProgress, UserVocabProgress.vocabulary_id == Vocabulary.id)
                .where(
                    UserVocabProgress.user_id == user.id,
                    Vocabulary.jlpt_level == jlpt_level,
                    UserVocabProgress.interval == 0,
                    UserVocabProgress.incorrect_count > 0,
                    UserVocabProgress.last_reviewed_at <= now - timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES),
                )
                .order_by(UserVocabProgress.last_reviewed_at)
                .limit(distribution["retry"])
            )
            retry_items = list(retry_result.scalars().all())
        else:
            retry_items = []

        studied_ids_result = await db.execute(select(UserVocabProgress.vocabulary_id).where(UserVocabProgress.user_id == user.id))
        studied_ids = set(studied_ids_result.scalars().all())
        exclude_ids = studied_ids | {vocab.id for vocab in review_items} | {vocab.id for vocab in retry_items}

        new_count_needed = distribution["new"]
        shortfall = (distribution["review"] - len(review_items)) + (distribution["retry"] - len(retry_items))
        new_count_needed += shortfall

        if new_count_needed > 0:
            new_query = select(Vocabulary).where(
                Vocabulary.jlpt_level == jlpt_level,
                Vocabulary.id.notin_(exclude_ids) if exclude_ids else True,
            )
            new_result = await db.execute(new_query.order_by(Vocabulary.id).limit(new_count_needed))
            new_items = list(new_result.scalars().all())
        else:
            new_items = []

        all_items = list(review_items) + list(retry_items) + list(new_items)
        fallback_pool_result = await db.execute(
            select(Vocabulary.meaning_ko).where(Vocabulary.jlpt_level == jlpt_level).order_by(func.random()).limit(50)
        )
        fallback_meanings = list(fallback_pool_result.scalars().all())

        seen_meanings: set[str] = set()
        for vocab in all_items:
            if vocab.meaning_ko in seen_meanings:
                continue
            seen_meanings.add(vocab.meaning_ko)

            distractors = await generate_distractors(
                db,
                correct_item_id=vocab.id,
                item_type="WORD",
                jlpt_level=jlpt_level,
                count=QUIZ_CONFIG.WRONG_OPTIONS_COUNT,
                user_id=user.id,
            )

            correct_id = str(uuid.uuid4())
            options = [{"id": correct_id, "text": vocab.meaning_ko}]
            used_texts = {vocab.meaning_ko}
            for distractor in distractors:
                options.append({"id": str(uuid.uuid4()), "text": distractor["text"]})
                used_texts.add(distractor["text"])

            if len(options) - 1 < QUIZ_CONFIG.WRONG_OPTIONS_COUNT:
                for meaning in fallback_meanings:
                    if meaning not in used_texts:
                        options.append({"id": str(uuid.uuid4()), "text": meaning})
                        used_texts.add(meaning)
                        if len(options) - 1 >= QUIZ_CONFIG.WRONG_OPTIONS_COUNT:
                            break
            random.shuffle(options)
            questions.append(build_vocab_question(vocab, quiz_type, options, correct_id))
    else:
        if distribution["review"] > 0:
            review_result = await db.execute(
                select(Grammar)
                .join(UserGrammarProgress, UserGrammarProgress.grammar_id == Grammar.id)
                .where(
                    UserGrammarProgress.user_id == user.id,
                    Grammar.jlpt_level == jlpt_level,
                    UserGrammarProgress.next_review_at <= now,
                    UserGrammarProgress.interval > 0,
                )
                .order_by(UserGrammarProgress.next_review_at)
                .limit(distribution["review"])
            )
            review_items = list(review_result.scalars().all())
        else:
            review_items = []

        if distribution["retry"] > 0:
            retry_result = await db.execute(
                select(Grammar)
                .join(UserGrammarProgress, UserGrammarProgress.grammar_id == Grammar.id)
                .where(
                    UserGrammarProgress.user_id == user.id,
                    Grammar.jlpt_level == jlpt_level,
                    UserGrammarProgress.interval == 0,
                    UserGrammarProgress.incorrect_count > 0,
                    UserGrammarProgress.last_reviewed_at <= now - timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES),
                )
                .order_by(UserGrammarProgress.last_reviewed_at)
                .limit(distribution["retry"])
            )
            retry_items = list(retry_result.scalars().all())
        else:
            retry_items = []

        studied_ids_result = await db.execute(select(UserGrammarProgress.grammar_id).where(UserGrammarProgress.user_id == user.id))
        studied_ids = set(studied_ids_result.scalars().all())
        exclude_ids = studied_ids | {grammar.id for grammar in review_items} | {grammar.id for grammar in retry_items}
        new_count_needed = distribution["new"] + (distribution["review"] - len(review_items)) + (distribution["retry"] - len(retry_items))

        if new_count_needed > 0:
            new_result = await db.execute(
                select(Grammar)
                .where(Grammar.jlpt_level == jlpt_level, Grammar.id.notin_(exclude_ids) if exclude_ids else True)
                .order_by(Grammar.id)
                .limit(new_count_needed)
            )
            new_items = list(new_result.scalars().all())
        else:
            new_items = []

        all_items = list(review_items) + list(retry_items) + list(new_items)
        pool_result = await db.execute(select(Grammar.meaning_ko).where(Grammar.jlpt_level == jlpt_level).order_by(func.random()).limit(50))
        all_meanings = list(pool_result.scalars().all())

        seen_meanings: set[str] = set()
        for grammar in all_items:
            if grammar.meaning_ko in seen_meanings:
                continue
            seen_meanings.add(grammar.meaning_ko)

            wrong_texts = [meaning for meaning in all_meanings if meaning != grammar.meaning_ko]
            random.shuffle(wrong_texts)
            options, correct_id = build_options(grammar.meaning_ko, wrong_texts[: QUIZ_CONFIG.WRONG_OPTIONS_COUNT])
            questions.append(build_grammar_question(grammar, quiz_type, options, correct_id))

    random.shuffle(questions)

    if not questions:
        raise QuizStartServiceError(status_code=400, detail="학습할 콘텐츠가 없습니다")

    session = await _create_quiz_session(
        db,
        user_id=user.id,
        quiz_type=body.category,
        jlpt_level=body.jlpt_level,
        questions=questions,
        mode="smart",
    )
    return QuizStartResult(session=session, questions=questions, matching_pairs=None)
