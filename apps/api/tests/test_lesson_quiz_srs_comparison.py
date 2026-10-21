"""Characterize current unequal schedulers, without choosing a replacement policy.

Lesson commands call ``srs.process_answer`` after registration; quiz answers use
``quiz_answer_progress``. Only database boundaries and the clock are mocked.
These tests never read or update existing records or review due dates.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Literal
from unittest.mock import AsyncMock, MagicMock
from uuid import UUID

import pytest

from app.models.lesson import LessonItemLink
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.services import quiz_answer_progress, srs
from app.services.progress_defaults import new_progress_defaults

type ItemType = Literal["WORD", "GRAMMAR"]
type Progress = UserVocabProgress | UserGrammarProgress

NOW = datetime(2026, 10, 21, 12, 0, tzinfo=UTC)
USER_ID = UUID("00000000-0000-0000-0000-000000000001")
ITEM_ID = UUID("00000000-0000-0000-0000-000000000002")
LESSON_ID = UUID("00000000-0000-0000-0000-000000000003")
SESSION_ID = UUID("00000000-0000-0000-0000-000000000004")


@dataclass(frozen=True)
class History:
    state: str
    step: int = 0
    interval: int = 0
    streak: int = 0
    mastered: bool = False


@dataclass(frozen=True)
class Expected:
    state: str
    step: int
    interval: int
    ease: float
    due: timedelta
    mastered: bool = False


@dataclass(frozen=True)
class Comparison:
    name: str
    history: History
    lesson_correct: Expected
    quiz_correct: Expected
    lesson_wrong: Expected
    quiz_wrong: Expected


# Literal observations, not recomputation by either implementation under test.
# Changing these outcomes requires review; they are not a policy endorsement.
COMPARISONS = [
    Comparison(
        "unseen",
        History("UNSEEN"),
        Expected("PROVISIONAL", 1, 0, 2.5, timedelta(days=3)),
        Expected("PROVISIONAL", 1, 1, 2.5, timedelta(days=1)),
        Expected("PROVISIONAL", 0, 0, 2.5, timedelta(days=1)),
        Expected("PROVISIONAL", 0, 0, 1.7, timedelta(minutes=10)),
    ),
    Comparison(
        "provisional-first-step",
        History("PROVISIONAL"),
        Expected("PROVISIONAL", 1, 0, 2.5, timedelta(days=3)),
        Expected("PROVISIONAL", 1, 1, 2.5, timedelta(days=1)),
        Expected("PROVISIONAL", 0, 0, 2.5, timedelta(days=1)),
        Expected("PROVISIONAL", 0, 0, 1.7, timedelta(minutes=10)),
    ),
    Comparison(
        "provisional-graduation",
        History("PROVISIONAL", step=1, interval=3, streak=1),
        Expected("LEARNING", 0, 3, 2.5, timedelta(days=1)),
        Expected("LEARNING", 1, 3, 2.5, timedelta(days=3)),
        Expected("PROVISIONAL", 0, 3, 2.5, timedelta(days=1)),
        Expected("PROVISIONAL", 0, 1, 1.96, timedelta(days=1)),
    ),
    Comparison(
        "lesson-registered-learning",
        History("LEARNING"),
        Expected("LEARNING", 1, 0, 2.5, timedelta(days=3)),
        Expected("LEARNING", 1, 1, 2.5, timedelta(days=1)),
        Expected("LEARNING", 0, 0, 2.5, timedelta(days=1)),
        Expected("LEARNING", 0, 0, 1.7, timedelta(minutes=10)),
    ),
    Comparison(
        "learning-graduation",
        History("LEARNING", step=1, interval=3, streak=1),
        Expected("REVIEW", 0, 7, 2.6, timedelta(days=7)),
        Expected("LEARNING", 2, 3, 2.5, timedelta(days=3)),
        Expected("LEARNING", 0, 3, 2.5, timedelta(days=1)),
        Expected("LEARNING", 0, 1, 1.96, timedelta(days=1)),
    ),
    Comparison(
        "review-reaching-mastery",
        History("REVIEW", interval=10, streak=3),
        Expected("MASTERED", 0, 26, 2.6, timedelta(days=26), mastered=True),
        Expected("MASTERED", 0, 25, 2.5, timedelta(days=25), mastered=True),
        Expected("RELEARNING", 0, 1, 2.3, timedelta(days=1)),
        Expected("RELEARNING", 0, 1, 1.96, timedelta(days=1)),
    ),
    Comparison(
        "review-longer-lapse",
        History("REVIEW", interval=20, streak=3),
        Expected("MASTERED", 0, 52, 2.6, timedelta(days=52), mastered=True),
        Expected("MASTERED", 0, 50, 2.5, timedelta(days=50), mastered=True),
        Expected("RELEARNING", 0, 1, 2.3, timedelta(days=1)),
        Expected("RELEARNING", 0, 2, 1.96, timedelta(days=2)),
    ),
    Comparison(
        "mastered",
        History("MASTERED", interval=30, streak=5, mastered=True),
        Expected("MASTERED", 0, 78, 2.6, timedelta(days=78), mastered=True),
        Expected("MASTERED", 0, 75, 2.5, timedelta(days=75), mastered=True),
        Expected("RELEARNING", 0, 1, 2.3, timedelta(days=1)),
        Expected("RELEARNING", 0, 3, 1.96, timedelta(days=3)),
    ),
    Comparison(
        "relearning",
        History("RELEARNING", interval=1),
        Expected("REVIEW", 0, 1, 2.5, timedelta(days=1)),
        Expected("REVIEW", 0, 1, 2.5, timedelta(days=1)),
        Expected("RELEARNING", 0, 1, 2.5, timedelta(days=1)),
        Expected("RELEARNING", 0, 1, 1.7, timedelta(days=1)),
    ),
]


def _progress(item_type: ItemType, history: History) -> Progress:
    model = UserVocabProgress if item_type == "WORD" else UserGrammarProgress
    fk = "vocabulary_id" if item_type == "WORD" else "grammar_id"
    values = new_progress_defaults(NOW - timedelta(days=30))
    values.update(
        state=history.state,
        learning_step=history.step,
        interval=history.interval,
        streak=history.streak,
        mastered=history.mastered,
        correct_count=history.streak,
        introduced_by="LESSON",
        source_lesson_id=LESSON_ID,
        next_review_at=NOW - timedelta(days=1),
        last_reviewed_at=NOW - timedelta(days=2),
    )
    return model(user_id=USER_ID, **{fk: ITEM_ID}, **values)


def _db(progress: Progress | None) -> AsyncMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = progress
    db = AsyncMock()
    db.execute.return_value = result
    db.add = MagicMock()
    db.begin_nested = MagicMock(return_value=AsyncMock())
    return db


def _freeze_clock(monkeypatch: pytest.MonkeyPatch, now: datetime) -> None:
    class FixedDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            assert tz is UTC
            return now

    monkeypatch.setattr(srs, "datetime", FixedDateTime)


async def _answer_pair(
    monkeypatch: pytest.MonkeyPatch,
    item_type: ItemType,
    lesson: Progress,
    quiz: Progress,
    *,
    correct: bool,
    seconds: int = 8,
    now: datetime = NOW,
) -> tuple[AsyncMock, AsyncMock]:
    _freeze_clock(monkeypatch, now)
    lesson_log, quiz_log = AsyncMock(), AsyncMock()
    monkeypatch.setattr(srs, "log_review_event", lesson_log)
    monkeypatch.setattr(quiz_answer_progress, "log_review_event", quiz_log)
    lesson_db, quiz_db = _db(lesson), _db(quiz)
    result = await srs.process_answer(
        lesson_db,
        user_id=USER_ID,
        item_type=item_type,
        item_id=ITEM_ID,
        is_correct=correct,
        direction="JP_KR",
        response_ms=seconds * 1000,
        lesson_id=LESSON_ID,
    )
    update_quiz = (
        quiz_answer_progress.update_vocab_answer_progress if item_type == "WORD" else quiz_answer_progress.update_grammar_answer_progress
    )
    await update_quiz(
        quiz_db,
        user_id=USER_ID,
        question_id=ITEM_ID,
        session_id=SESSION_ID,
        is_correct=correct,
        time_spent_seconds=seconds,
        now=now,
    )
    assert result["state_after"] == lesson.state
    assert result["next_review_at"] == lesson.next_review_at.isoformat()
    for db in (lesson_db, quiz_db):
        db.add.assert_not_called()
        db.commit.assert_not_awaited()
    lesson_log.assert_awaited_once()
    quiz_log.assert_awaited_once()
    assert lesson_log.await_args.kwargs["item_id"] == quiz_log.await_args.args[3] == ITEM_ID
    assert lesson_log.await_args.kwargs["item_type"] == quiz_log.await_args.args[2] == item_type
    assert lesson_log.await_args.kwargs["reviewed_on"] == quiz_log.await_args.args[15] == now.date()
    assert lesson_log.await_args.kwargs["lesson_id"] == LESSON_ID
    assert quiz_log.await_args.args[4:6] == (SESSION_ID, None)
    return lesson_log, quiz_log


def _assert_schedule(progress: Progress, expected: Expected, now: datetime = NOW) -> None:
    assert (progress.state, progress.learning_step, progress.interval, progress.mastered) == (
        expected.state,
        expected.step,
        expected.interval,
        expected.mastered,
    )
    assert progress.ease_factor == pytest.approx(expected.ease)
    assert progress.next_review_at == now + expected.due
    assert progress.next_review_at.utcoffset() == timedelta(0)


@pytest.mark.parametrize("item_type", ["WORD", "GRAMMAR"])
@pytest.mark.parametrize("correct", [True, False], ids=["correct", "wrong"])
@pytest.mark.parametrize("case", COMPARISONS, ids=lambda case: case.name)
async def test_same_history_has_explicit_current_lesson_and_quiz_outcomes(
    monkeypatch: pytest.MonkeyPatch,
    item_type: ItemType,
    correct: bool,
    case: Comparison,
) -> None:
    lesson, quiz = _progress(item_type, case.history), _progress(item_type, case.history)
    await _answer_pair(monkeypatch, item_type, lesson, quiz, correct=correct)
    _assert_schedule(lesson, case.lesson_correct if correct else case.lesson_wrong)
    _assert_schedule(quiz, case.quiz_correct if correct else case.quiz_wrong)
    for progress in (lesson, quiz):
        assert progress.correct_count == case.history.streak + int(correct)
        assert progress.incorrect_count == int(not correct)
        assert progress.streak == (case.history.streak + 1 if correct else 0)
        assert progress.source_lesson_id == LESSON_ID
        assert progress.last_reviewed_at == progress.updated_at == NOW
        assert progress.created_at == NOW - timedelta(days=30)
    # These metadata differences also matter in any future policy unification.
    assert lesson.fsrs_reps == 1
    assert quiz.fsrs_reps == 0
    assert lesson.fsrs_lapses == int(not correct)
    assert quiz.fsrs_lapses == 0
    assert (lesson.jp_kr_total, lesson.jp_kr_correct) == (1, int(correct))
    assert (quiz.jp_kr_total, quiz.jp_kr_correct) == (0, 0)


@pytest.mark.parametrize("item_type", ["WORD", "GRAMMAR"])
@pytest.mark.parametrize(
    ("seconds", "lesson_rating", "quiz_ease", "quiz_interval"),
    [
        (0, 4, 2.6, 20),
        (2, 4, 2.6, 20),
        (3, 3, 2.6, 20),
        (4, 3, 2.5, 18),
        (8, 3, 2.5, 18),
        (9, 3, 2.36, 17),
        (10, 3, 2.36, 17),
        (11, 2, 2.36, 17),
    ],
)
async def test_response_time_boundaries_compare_real_units_and_logged_ratings(
    monkeypatch: pytest.MonkeyPatch,
    item_type: ItemType,
    seconds: int,
    lesson_rating: int,
    quiz_ease: float,
    quiz_interval: int,
) -> None:
    history = History("REVIEW", interval=7, streak=3)
    lesson, quiz = _progress(item_type, history), _progress(item_type, history)
    lesson_log, quiz_log = await _answer_pair(monkeypatch, item_type, lesson, quiz, correct=True, seconds=seconds)
    # Lesson computes a speed rating but REVIEW ignores it. Quiz uses <=3s/<=8s
    # quality thresholds while its event currently logs correct rating 3.
    _assert_schedule(lesson, Expected("REVIEW", 0, 18, 2.6, timedelta(days=18)))
    _assert_schedule(quiz, Expected("REVIEW", 0, quiz_interval, quiz_ease, timedelta(days=quiz_interval)))
    assert lesson_log.await_args.kwargs["rating"] == lesson_rating
    assert quiz_log.await_args.args[9] == 3
    assert lesson_log.await_args.kwargs["response_ms"] == quiz_log.await_args.args[8] == seconds * 1000


@pytest.mark.parametrize("item_type", ["WORD", "GRAMMAR"])
@pytest.mark.parametrize("correct", [True, False], ids=["correct", "wrong"])
@pytest.mark.parametrize(
    "now",
    [
        datetime(2026, 10, 31, 23, 59, 59, 999999, tzinfo=UTC),
        datetime(2026, 11, 1, 0, 0, tzinfo=UTC),
        datetime(2026, 12, 31, 23, 59, 59, 999999, tzinfo=UTC),
        datetime(2027, 1, 1, 0, 0, tzinfo=UTC),
    ],
    ids=["month-end", "month-start", "year-end", "year-start"],
)
async def test_due_dates_use_elapsed_utc_time_across_calendar_boundaries(
    monkeypatch: pytest.MonkeyPatch,
    item_type: ItemType,
    correct: bool,
    now: datetime,
) -> None:
    case = next(case for case in COMPARISONS if case.name == "lesson-registered-learning")
    lesson, quiz = _progress(item_type, case.history), _progress(item_type, case.history)
    await _answer_pair(monkeypatch, item_type, lesson, quiz, correct=correct, now=now)
    _assert_schedule(lesson, case.lesson_correct if correct else case.lesson_wrong, now)
    _assert_schedule(quiz, case.quiz_correct if correct else case.quiz_wrong, now)


@pytest.mark.parametrize("item_type", ["WORD", "GRAMMAR"])
@pytest.mark.parametrize("second_correct", [True, False], ids=["two-correct", "correct-then-wrong"])
async def test_repeated_same_item_on_same_day_advances_both_paths_without_due_date_guard(
    monkeypatch: pytest.MonkeyPatch,
    item_type: ItemType,
    second_correct: bool,
) -> None:
    lesson, quiz = _progress(item_type, History("LEARNING")), _progress(item_type, History("LEARNING"))
    await _answer_pair(monkeypatch, item_type, lesson, quiz, correct=True)
    first_due = (lesson.next_review_at, quiz.next_review_at)
    later = NOW + timedelta(seconds=30)
    await _answer_pair(monkeypatch, item_type, lesson, quiz, correct=second_correct, now=later)
    assert first_due == (NOW + timedelta(days=3), NOW + timedelta(days=1))
    if second_correct:
        _assert_schedule(lesson, Expected("REVIEW", 0, 7, 2.6, timedelta(days=7)), later)
        _assert_schedule(quiz, Expected("LEARNING", 2, 3, 2.5, timedelta(days=3)), later)
    else:
        _assert_schedule(lesson, Expected("LEARNING", 0, 0, 2.5, timedelta(days=1)), later)
        _assert_schedule(quiz, Expected("LEARNING", 0, 1, 1.96, timedelta(days=1)), later)
    assert lesson.correct_count == quiz.correct_count == 1 + int(second_correct)
    assert lesson.incorrect_count == quiz.incorrect_count == int(not second_correct)
    assert lesson.fsrs_reps == 2
    assert quiz.fsrs_reps == 0


@pytest.mark.parametrize("item_type", ["WORD", "GRAMMAR"])
async def test_lesson_registration_then_first_correct_is_three_days_while_quiz_is_one_day(
    monkeypatch: pytest.MonkeyPatch,
    item_type: ItemType,
) -> None:
    _freeze_clock(monkeypatch, NOW)
    db = _db(None)
    link = LessonItemLink(
        lesson_id=LESSON_ID,
        item_type=item_type,
        vocabulary_id=ITEM_ID if item_type == "WORD" else None,
        grammar_id=ITEM_ID if item_type == "GRAMMAR" else None,
        item_order=1,
    )
    assert await srs.register_items_from_lesson(db, USER_ID, LESSON_ID, [link]) == 1
    lesson = db.add.call_args.args[0]
    assert (lesson.state, lesson.learning_step, lesson.next_review_at) == ("LEARNING", 0, NOW + timedelta(days=1))
    monkeypatch.setattr(srs, "log_review_event", AsyncMock())
    await srs.process_answer(
        _db(lesson),
        user_id=USER_ID,
        item_type=item_type,
        item_id=ITEM_ID,
        is_correct=True,
        direction="JP_KR",
        response_ms=8000,
        lesson_id=LESSON_ID,
    )
    quiz_db = _db(None)
    monkeypatch.setattr(quiz_answer_progress, "log_review_event", AsyncMock())
    update_quiz = (
        quiz_answer_progress.update_vocab_answer_progress if item_type == "WORD" else quiz_answer_progress.update_grammar_answer_progress
    )
    await update_quiz(
        quiz_db,
        user_id=USER_ID,
        question_id=ITEM_ID,
        session_id=SESSION_ID,
        is_correct=True,
        time_spent_seconds=8,
        now=NOW,
    )
    quiz_db.add.assert_called_once()
    quiz = quiz_db.add.call_args.args[0]
    _assert_schedule(lesson, Expected("LEARNING", 1, 0, 2.5, timedelta(days=3)))
    _assert_schedule(quiz, Expected("PROVISIONAL", 1, 1, 2.5, timedelta(days=1)))
    assert lesson.introduced_by == "LESSON"
    assert quiz.introduced_by == "QUIZ"
    assert lesson.correct_count == quiz.correct_count == 1


@pytest.mark.parametrize("item_type", ["WORD", "GRAMMAR"])
@pytest.mark.parametrize("case", COMPARISONS[1:], ids=lambda case: case.name)
async def test_lesson_reregistration_preserves_every_existing_registered_progress_field(
    monkeypatch: pytest.MonkeyPatch,
    item_type: ItemType,
    case: Comparison,
) -> None:
    _freeze_clock(monkeypatch, NOW)
    progress = _progress(item_type, case.history)
    before = {column.key: getattr(progress, column.key) for column in progress.__table__.columns}
    db = _db(progress)
    link = LessonItemLink(
        lesson_id=LESSON_ID,
        item_type=item_type,
        vocabulary_id=ITEM_ID if item_type == "WORD" else None,
        grammar_id=ITEM_ID if item_type == "GRAMMAR" else None,
        item_order=1,
    )

    assert await srs.register_items_from_lesson(db, USER_ID, LESSON_ID, [link]) == 0

    assert {column.key: getattr(progress, column.key) for column in progress.__table__.columns} == before
    db.add.assert_not_called()
    db.commit.assert_not_awaited()
