from __future__ import annotations

import contextlib
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, QuizAnswer, QuizSession, UserGrammarProgress, UserVocabProgress, Vocabulary
from app.models.user import User
from app.schemas.quiz import QuizQuestion, QuizResumeRequest
from app.services.quiz_session import build_response_questions, extract_questions_data
from app.utils.helpers import enum_value


class QuizQueryServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(slots=True)
class IncompleteQuizSessionResult:
    id: str
    quiz_type: str
    jlpt_level: str
    total_questions: int
    answered_count: int
    correct_count: int
    started_at: str


@dataclass(slots=True)
class ResumeQuizResult:
    session_id: str
    questions: list[QuizQuestion]
    answered_question_ids: list[str]
    total_questions: int
    correct_count: int
    quiz_type: str


@dataclass(slots=True)
class QuizStatsResult:
    total_quizzes: int
    total_correct: int
    total_questions: int
    accuracy: float


@dataclass(slots=True)
class ContentQuizStatsResult:
    total_count: int
    studied_count: int
    progress: int


@dataclass(slots=True)
class WrongAnswerResult:
    question_id: str
    word: str | None
    reading: str | None
    meaning_ko: str | None
    example_sentence: str | None
    example_translation: str | None


@dataclass(slots=True)
class RecommendationsResult:
    review_due_count: int
    new_words_count: int
    wrong_count: int
    last_reviewed_at: str | None


async def get_incomplete_quiz_session(
    db: AsyncSession,
    user: User,
) -> IncompleteQuizSessionResult | None:
    cutoff = datetime.now(UTC) - timedelta(hours=24)
    result = await db.execute(
        select(QuizSession)
        .where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.is_(None),
        )
        .order_by(QuizSession.started_at.desc())
    )
    sessions = result.scalars().all()

    valid_session: tuple[QuizSession, int] | None = None
    for session in sessions:
        answered_result = await db.execute(select(func.count(QuizAnswer.id)).where(QuizAnswer.session_id == session.id))
        answered_count = answered_result.scalar() or 0

        if answered_count == 0 or (session.started_at and session.started_at < cutoff):
            session.completed_at = datetime.now(UTC)
            continue

        if valid_session is None:
            valid_session = (session, answered_count)

    await db.commit()
    if not valid_session:
        return None

    session, answered_count = valid_session
    return IncompleteQuizSessionResult(
        id=str(session.id),
        quiz_type=enum_value(session.quiz_type),
        jlpt_level=enum_value(session.jlpt_level),
        total_questions=session.total_questions,
        answered_count=answered_count,
        correct_count=session.correct_count,
        started_at=session.started_at.isoformat() if session.started_at else "",
    )


async def resume_quiz_session(
    db: AsyncSession,
    user: User,
    body: QuizResumeRequest,
) -> ResumeQuizResult:
    session = await db.get(QuizSession, body.session_id)
    if not session or session.user_id != user.id:
        raise QuizQueryServiceError(status_code=404, detail="세션을 찾을 수 없습니다")
    if session.completed_at:
        raise QuizQueryServiceError(status_code=400, detail="이미 완료된 세션입니다")

    answered_result = await db.execute(select(QuizAnswer.question_id).where(QuizAnswer.session_id == session.id))
    answered_ids = [str(question_id) for question_id in answered_result.scalars().all()]
    questions = extract_questions_data(session.questions_data)
    response_questions = build_response_questions(questions)

    return ResumeQuizResult(
        session_id=str(session.id),
        questions=response_questions,
        answered_question_ids=answered_ids,
        total_questions=session.total_questions,
        correct_count=session.correct_count,
        quiz_type=enum_value(session.quiz_type),
    )


async def get_quiz_stats_data(
    db: AsyncSession,
    user: User,
    *,
    level: str | None,
    quiz_type: str | None,
) -> ContentQuizStatsResult | QuizStatsResult:
    if level and quiz_type:
        if quiz_type in ("VOCABULARY", "KANJI", "LISTENING"):
            total_result = await db.execute(select(func.count(Vocabulary.id)).where(Vocabulary.jlpt_level == level))
            total_count = total_result.scalar() or 0

            studied_result = await db.execute(
                select(func.count(UserVocabProgress.id))
                .join(Vocabulary, UserVocabProgress.vocabulary_id == Vocabulary.id)
                .where(
                    UserVocabProgress.user_id == user.id,
                    Vocabulary.jlpt_level == level,
                )
            )
            studied_count = studied_result.scalar() or 0
        else:
            total_result = await db.execute(select(func.count(Grammar.id)).where(Grammar.jlpt_level == level))
            total_count = total_result.scalar() or 0

            studied_result = await db.execute(
                select(func.count(UserGrammarProgress.id))
                .join(Grammar, UserGrammarProgress.grammar_id == Grammar.id)
                .where(
                    UserGrammarProgress.user_id == user.id,
                    Grammar.jlpt_level == level,
                )
            )
            studied_count = studied_result.scalar() or 0

        return ContentQuizStatsResult(
            total_count=total_count,
            studied_count=studied_count,
            progress=round(studied_count / total_count * 100) if total_count > 0 else 0,
        )

    total_result = await db.execute(
        select(func.count(QuizSession.id)).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.isnot(None),
        )
    )
    totals_result = await db.execute(
        select(
            func.sum(QuizSession.correct_count),
            func.sum(QuizSession.total_questions),
        ).where(
            QuizSession.user_id == user.id,
            QuizSession.completed_at.isnot(None),
        )
    )
    row = totals_result.one()
    total_correct = row[0] or 0
    total_questions = row[1] or 0

    return QuizStatsResult(
        total_quizzes=total_result.scalar() or 0,
        total_correct=total_correct,
        total_questions=total_questions,
        accuracy=(total_correct / total_questions * 100) if total_questions > 0 else 0,
    )


async def get_wrong_answers_data(
    db: AsyncSession,
    user: User,
    *,
    session_id: str,
) -> list[WrongAnswerResult]:
    session = await db.get(QuizSession, session_id)
    if not session or session.user_id != user.id:
        raise QuizQueryServiceError(status_code=404, detail="세션을 찾을 수 없습니다")

    wrong_result = await db.execute(
        select(QuizAnswer).where(
            QuizAnswer.session_id == session.id,
            QuizAnswer.is_correct.is_(False),
        )
    )
    wrong_answers = wrong_result.scalars().all()

    questions_data = extract_questions_data(session.questions_data)
    question_map = {question["id"]: question for question in questions_data}

    wrong_vocab_ids = []
    for wrong_answer in wrong_answers:
        question = question_map.get(str(wrong_answer.question_id))
        if question and question.get("type") in ("VOCABULARY", "KANJI", "LISTENING"):
            with contextlib.suppress(ValueError):
                wrong_vocab_ids.append(uuid.UUID(str(wrong_answer.question_id)))

    vocab_map: dict[str, Vocabulary] = {}
    if wrong_vocab_ids:
        vocab_result = await db.execute(select(Vocabulary).where(Vocabulary.id.in_(wrong_vocab_ids)))
        for vocab in vocab_result.scalars().all():
            vocab_map[str(vocab.id)] = vocab

    results: list[WrongAnswerResult] = []
    for wrong_answer in wrong_answers:
        question = question_map.get(str(wrong_answer.question_id), {})
        vocab = vocab_map.get(str(wrong_answer.question_id))
        results.append(
            WrongAnswerResult(
                question_id=str(wrong_answer.question_id),
                word=question.get("word"),
                reading=question.get("reading") or (vocab.reading if vocab else None),
                meaning_ko=question.get("meaningKo"),
                example_sentence=vocab.example_sentence if vocab else None,
                example_translation=vocab.example_translation if vocab else None,
            )
        )
    return results


async def get_recommendations_data(
    db: AsyncSession,
    user: User,
    *,
    category: str | None,
) -> RecommendationsResult:
    now = datetime.now(UTC)

    if category == "VOCABULARY":
        due_result = await db.execute(
            select(func.count(UserVocabProgress.id)).where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.next_review_at <= now,
            )
        )
        review_due = due_result.scalar() or 0

        studied_count_result = await db.execute(
            select(func.count(UserVocabProgress.id)).where(
                UserVocabProgress.user_id == user.id,
            )
        )
        studied_count = studied_count_result.scalar() or 0
        total_result = await db.execute(select(func.count(Vocabulary.id)))
        total = total_result.scalar() or 0
        new_count = max(0, total - studied_count)

        wrong_result = await db.execute(
            select(func.count(UserVocabProgress.id)).where(
                UserVocabProgress.user_id == user.id,
                UserVocabProgress.incorrect_count > 0,
            )
        )
        wrong_count = wrong_result.scalar() or 0

        last_reviewed_result = await db.execute(
            select(func.max(UserVocabProgress.last_reviewed_at)).where(
                UserVocabProgress.user_id == user.id,
            )
        )
        last_reviewed = last_reviewed_result.scalar()
        return RecommendationsResult(
            review_due_count=review_due,
            new_words_count=new_count,
            wrong_count=wrong_count,
            last_reviewed_at=last_reviewed.isoformat() if last_reviewed else None,
        )

    if category == "GRAMMAR":
        due_result = await db.execute(
            select(func.count(UserGrammarProgress.id)).where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.next_review_at <= now,
            )
        )
        review_due = due_result.scalar() or 0

        studied_count_result = await db.execute(
            select(func.count(UserGrammarProgress.id)).where(
                UserGrammarProgress.user_id == user.id,
            )
        )
        studied_count = studied_count_result.scalar() or 0
        total_result = await db.execute(select(func.count(Grammar.id)))
        total = total_result.scalar() or 0
        new_count = max(0, total - studied_count)

        wrong_result = await db.execute(
            select(func.count(UserGrammarProgress.id)).where(
                UserGrammarProgress.user_id == user.id,
                UserGrammarProgress.incorrect_count > 0,
            )
        )
        wrong_count = wrong_result.scalar() or 0

        last_reviewed_result = await db.execute(
            select(func.max(UserGrammarProgress.last_reviewed_at)).where(
                UserGrammarProgress.user_id == user.id,
            )
        )
        last_reviewed = last_reviewed_result.scalar()
        return RecommendationsResult(
            review_due_count=review_due,
            new_words_count=new_count,
            wrong_count=wrong_count,
            last_reviewed_at=last_reviewed.isoformat() if last_reviewed else None,
        )

    if category == "SENTENCE":
        return RecommendationsResult(
            review_due_count=0,
            new_words_count=0,
            wrong_count=0,
            last_reviewed_at=None,
        )

    due_vocab_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.next_review_at <= now,
        )
    )
    due_grammar_result = await db.execute(
        select(func.count(UserGrammarProgress.id)).where(
            UserGrammarProgress.user_id == user.id,
            UserGrammarProgress.next_review_at <= now,
        )
    )
    vocab_due = due_vocab_result.scalar() or 0
    grammar_due = due_grammar_result.scalar() or 0

    studied_count_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
        )
    )
    studied_count = studied_count_result.scalar() or 0
    total_vocab_result = await db.execute(select(func.count(Vocabulary.id)))
    total_vocab = total_vocab_result.scalar() or 0
    new_words_count = max(0, total_vocab - studied_count)

    wrong_count_result = await db.execute(
        select(func.count(UserVocabProgress.id)).where(
            UserVocabProgress.user_id == user.id,
            UserVocabProgress.incorrect_count > 0,
        )
    )
    wrong_count = wrong_count_result.scalar() or 0

    last_reviewed_result = await db.execute(
        select(func.max(UserVocabProgress.last_reviewed_at)).where(
            UserVocabProgress.user_id == user.id,
        )
    )
    last_reviewed = last_reviewed_result.scalar()

    return RecommendationsResult(
        review_due_count=vocab_due + grammar_due,
        new_words_count=new_words_count,
        wrong_count=wrong_count,
        last_reviewed_at=last_reviewed.isoformat() if last_reviewed else None,
    )
