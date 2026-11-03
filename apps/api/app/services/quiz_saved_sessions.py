"""Read-only discovery of saved quizzes, with eligibility before pagination."""

from __future__ import annotations

import base64
import json
import uuid
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import Select, and_, exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Grammar, QuizAnswer, QuizSession, Vocabulary
from app.models.user import User
from app.schemas.quiz import IncompleteQuizSessionsResponse, SavedQuizSession
from app.services.quiz_errors import QuizQueryServiceError
from app.services.quiz_resume_snapshot import QuizResumeSnapshot, decode_quiz_resume_snapshot
from app.utils.helpers import enum_value

CONTENT_UNAVAILABLE = "이 퀴즈에 필요한 학습 항목을 더 이상 사용할 수 없어요. 저장된 학습 기록은 유지됩니다."


def utc_instant(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.utcoffset() is None else value.astimezone(UTC)


def saved_sessions_query(user_id: uuid.UUID) -> Select[tuple[QuizSession]]:
    # Filtering AFTER LIMIT would strand older answered quizzes behind empty ones.
    return (
        select(QuizSession)
        .where(
            QuizSession.user_id == user_id,
            QuizSession.completed_at.is_(None),
            QuizSession.quiz_type != "KANA",
            exists(select(QuizAnswer.id).where(QuizAnswer.session_id == QuizSession.id)),
        )
        .order_by(QuizSession.started_at.desc(), QuizSession.id.desc())
    )


def _cursor(session: QuizSession, quiz_type: str | None, jlpt_level: str | None) -> str:
    data = [1, utc_instant(session.started_at).isoformat(), str(session.id), quiz_type, jlpt_level]
    return base64.urlsafe_b64encode(json.dumps(data, separators=(",", ":")).encode()).decode().rstrip("=")


def _read_cursor(value: str, quiz_type: str | None, jlpt_level: str | None) -> tuple[datetime, uuid.UUID]:
    try:
        if not value or len(value) > 1024:
            raise ValueError
        raw = base64.b64decode(value + "=" * (-len(value) % 4), altchars=b"-_", validate=True)
        data = json.loads(raw)
        if not isinstance(data, list) or len(data) != 5 or type(data[0]) is not int or data[0] != 1:
            raise ValueError
        if not isinstance(data[1], str) or not isinstance(data[2], str) or data[3:] != [quiz_type, jlpt_level]:
            raise ValueError
        instant = datetime.fromisoformat(data[1])
        if instant.utcoffset() is None:
            raise ValueError
        return utc_instant(instant), uuid.UUID(data[2])
    except (ValueError, TypeError, UnicodeDecodeError) as exc:
        raise QuizQueryServiceError(status_code=400, detail="저장된 퀴즈 목록의 페이지 정보가 올바르지 않습니다") from exc


@dataclass(slots=True)
class SavedSessionEvidence:
    session: QuizSession
    snapshot: QuizResumeSnapshot
    first_answers: dict[str, QuizAnswer]
    summary: SavedQuizSession


def _valid_saved_answers(snapshot: QuizResumeSnapshot, session: QuizSession, answers: dict[str, QuizAnswer]) -> bool:
    questions = {question["id"]: question for question in snapshot.questions}
    if not answers.keys() <= questions.keys():
        return False
    if snapshot.mode not in {"matching", "arrange"}:
        return True
    pair_ids = {pair.id for pair in snapshot.matching_pairs or []}
    return all(
        enum_value(answer.question_type) == enum_value(session.quiz_type)
        and isinstance(answer.selected_option_id, str)
        and isinstance(answer.is_correct, bool)
        and answer.is_correct == (answer.selected_option_id == questions[question_id]["correctOptionId"])
        and (snapshot.mode != "matching" or answer.selected_option_id in pair_ids | {"wrong"})
        for question_id, answer in answers.items()
    )


def pending_catalog_ids(
    snapshot: QuizResumeSnapshot, session: QuizSession, answered_ids: set[str]
) -> tuple[set[uuid.UUID], set[uuid.UUID]]:
    vocab_ids: set[uuid.UUID] = set()
    grammar_ids: set[uuid.UUID] = set()
    for question in snapshot.questions:
        if question["id"] in answered_ids:
            continue
        kind = question.get("type") or enum_value(session.quiz_type)
        if kind in {"VOCABULARY", "KANJI", "LISTENING"}:
            vocab_ids.add(uuid.UUID(question["id"]))
        elif kind == "GRAMMAR":
            grammar_ids.add(uuid.UUID(question["id"]))
    return vocab_ids, grammar_ids


async def missing_catalog_ids(
    db: AsyncSession, vocab_ids: set[uuid.UUID], grammar_ids: set[uuid.UUID]
) -> tuple[set[uuid.UUID], set[uuid.UUID]]:
    missing_vocab, missing_grammar = set(vocab_ids), set(grammar_ids)
    if vocab_ids:
        missing_vocab -= set((await db.execute(select(Vocabulary.id).where(Vocabulary.id.in_(vocab_ids)))).scalars().all())
    if grammar_ids:
        missing_grammar -= set((await db.execute(select(Grammar.id).where(Grammar.id.in_(grammar_ids)))).scalars().all())
    return missing_vocab, missing_grammar


async def load_saved_session_evidence(db: AsyncSession, sessions: list[QuizSession]) -> list[SavedSessionEvidence]:
    if not sessions:
        return []
    # DISTINCT ON bounds legacy duplicate attempts to one persisted answer/question.
    result = await db.execute(
        select(QuizAnswer)
        .where(QuizAnswer.session_id.in_([session.id for session in sessions]))
        .distinct(QuizAnswer.session_id, QuizAnswer.question_id)
        .order_by(QuizAnswer.session_id, QuizAnswer.question_id, QuizAnswer.answered_at, QuizAnswer.id)
    )
    by_session: dict[uuid.UUID, dict[str, QuizAnswer]] = defaultdict(dict)
    for answer in result.scalars().all():
        by_session[answer.session_id].setdefault(str(answer.question_id), answer)
    evidence: list[SavedSessionEvidence] = []
    pending: dict[uuid.UUID, tuple[set[uuid.UUID], set[uuid.UUID]]] = {}
    all_vocab: set[uuid.UUID] = set()
    all_grammar: set[uuid.UUID] = set()
    for session in sessions:
        snapshot = decode_quiz_resume_snapshot(
            session.questions_data, total_questions=session.total_questions, quiz_type=enum_value(session.quiz_type)
        )
        answers = by_session[session.id]
        status = snapshot.status
        if status == "available" and not _valid_saved_answers(snapshot, session, answers):
            status = "invalid_snapshot"
        summary = SavedQuizSession(
            id=str(session.id),
            quiz_type=enum_value(session.quiz_type),
            jlpt_level=enum_value(session.jlpt_level),
            mode=snapshot.mode,
            total_questions=session.total_questions,
            answered_count=len(answers),
            remaining_count=session.total_questions - len(answers) if status == "available" else None,
            started_at=utc_instant(session.started_at).isoformat(),
            resume_status=status,
            resume_reason=("UNSUPPORTED_LEGACY" if status == "legacy_unavailable" else "SNAPSHOT_INVALID")
            if status != "available"
            else None,
        )
        evidence.append(SavedSessionEvidence(session, snapshot, answers, summary))
        if status == "available":
            pending[session.id] = pending_catalog_ids(snapshot, session, set(answers))
            all_vocab.update(pending[session.id][0])
            all_grammar.update(pending[session.id][1])
    missing_vocab, missing_grammar = await missing_catalog_ids(db, all_vocab, all_grammar)
    for item in evidence:
        required_vocab, required_grammar = pending.get(item.session.id, (set(), set()))
        if required_vocab & missing_vocab or required_grammar & missing_grammar:
            item.summary.resume_status = "invalid_snapshot"
            item.summary.resume_reason = "CONTENT_UNAVAILABLE"
            item.summary.remaining_count = None
    return evidence


async def get_saved_quiz_sessions(
    db: AsyncSession,
    user: User,
    *,
    limit: int = 20,
    cursor: str | None = None,
    quiz_type: str | None = None,
    jlpt_level: str | None = None,
) -> IncompleteQuizSessionsResponse:
    if not 1 <= limit <= 50:
        raise QuizQueryServiceError(status_code=400, detail="페이지 크기는 1개부터 50개까지 지정할 수 있습니다")
    query = saved_sessions_query(user.id)
    if quiz_type is not None:
        query = query.where(QuizSession.quiz_type == quiz_type)
    if jlpt_level is not None:
        query = query.where(QuizSession.jlpt_level == jlpt_level)
    if cursor is not None:
        started_at, session_id = _read_cursor(cursor, quiz_type, jlpt_level)
        query = query.where(
            or_(QuizSession.started_at < started_at, and_(QuizSession.started_at == started_at, QuizSession.id < session_id))
        )
    result = await db.execute(query.limit(limit + 1))
    candidates = list(result.scalars().all())
    page = candidates[:limit]
    evidence = await load_saved_session_evidence(db, page)
    return IncompleteQuizSessionsResponse(
        sessions=[item.summary for item in evidence],
        next_cursor=_cursor(page[-1], quiz_type, jlpt_level) if len(candidates) > limit else None,
    )
