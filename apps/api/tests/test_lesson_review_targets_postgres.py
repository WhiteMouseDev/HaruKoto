"""Real PostgreSQL regressions; only a disposable local cluster is used."""

import json
from copy import deepcopy
from pathlib import Path
from uuid import UUID, uuid4

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.base import Base
from app.models.content import Grammar, Vocabulary
from app.models.enums import JlptLevel, PartOfSpeech
from app.models.lesson import Lesson, LessonItemLink, UserLessonProgress
from app.models.progress import UserGrammarProgress, UserVocabProgress
from app.models.user import User
from app.schemas.lesson import AnswerSubmission, LessonDetailResponse
from app.seeds.lessons import CONTENT_ROOT, _seed_one_chapter
from app.services.lesson_command import LessonServiceError, submit_lesson_attempt
from app.services.lesson_detail_query import get_lesson_detail_data
from tests.test_quiz_answer_persistence_postgres import isolated_postgres_url as isolated_postgres_url


async def _prepare_tables(engine) -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
        await connection.execute(
            text("""
                CREATE TABLE IF NOT EXISTS review_events (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    user_id UUID NOT NULL, item_type TEXT NOT NULL,
                    vocabulary_id UUID, grammar_id UUID, session_id UUID, lesson_id UUID,
                    direction TEXT NOT NULL, is_correct BOOLEAN NOT NULL,
                    response_ms INTEGER NOT NULL, rating SMALLINT NOT NULL,
                    state_before TEXT NOT NULL, state_after TEXT NOT NULL,
                    distractor_difficulty TEXT,
                    is_provisional_phase BOOLEAN NOT NULL DEFAULT FALSE,
                    is_new_card BOOLEAN NOT NULL DEFAULT FALSE,
                    reviewed_on DATE NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                )
            """)
        )


async def _seed_first_lesson(
    db: AsyncSession, tmp_path: Path, *, extra_target: bool = False
) -> tuple[UUID, dict[int, UUID], dict[int, UUID]]:
    source = json.loads((CONTENT_ROOT / "n5/ch01-greetings-and-first-meetings.json").read_text(encoding="utf-8"))
    source["lessons"] = [source["lessons"][0]]
    lesson_source = source["lessons"][0]
    if extra_target:
        # An explicitly reviewed extra target is not one of the introduced items.
        lesson_source["content_jsonb"]["questions"][3]["grammar_order"] = 55
    vocabulary_ids: dict[int, UUID] = {}
    for order in lesson_source["vocab_orders"]:
        vocabulary = await db.scalar(select(Vocabulary).where(Vocabulary.jlpt_level == JlptLevel.N5, Vocabulary.order == order))
        if vocabulary is None:
            vocabulary = Vocabulary(
                jlpt_level=JlptLevel.N5,
                order=order,
                word=lesson_source["vocab_detail"][str(order)].split(" (")[0],
                reading=f"ごい{order}",
                meaning_ko=f"합성 어휘 {order}",
                part_of_speech=PartOfSpeech.NOUN,
            )
            db.add(vocabulary)
            await db.flush()
        vocabulary_ids[order] = vocabulary.id
    grammar_ids: dict[int, UUID] = {}
    for order in (1, 55) if extra_target else (1,):
        grammar = await db.scalar(select(Grammar).where(Grammar.jlpt_level == JlptLevel.N5, Grammar.order == order))
        if grammar is None:
            grammar = Grammar(
                jlpt_level=JlptLevel.N5,
                order=order,
                pattern="〜です" if order == 1 else "いる/あるの区別",
                meaning_ko="합성 문법",
                explanation="복습 항목 연결 회귀 검증",
            )
            db.add(grammar)
            await db.flush()
        grammar_ids[order] = grammar.id
    source_file = tmp_path / "first-lesson.json"
    source_file.write_text(json.dumps(source, ensure_ascii=False), encoding="utf-8")
    await _seed_one_chapter(db, source_file)
    await db.commit()
    lesson_id = await db.scalar(select(Lesson.id).where(Lesson.jlpt_level == JlptLevel.N5, Lesson.lesson_no == 1))
    assert lesson_id is not None
    return lesson_id, vocabulary_ids, grammar_ids


def _answers(content: dict, *, wrong_student: bool = False) -> list[AnswerSubmission]:
    answers = []
    for question in reversed(content["questions"]):
        if question["type"] == "SENTENCE_REORDER":
            answers.append(AnswerSubmission(order=question["order"], submitted_order=question["correct_order"], response_ms=1500))
        else:
            selected = "a" if wrong_student and question["order"] == 2 else question["correct_answer"]
            answers.append(AnswerSubmission(order=question["order"], selected_answer=selected, response_ms=1500))
    return answers


async def test_seeded_first_lesson_updates_student_and_grammar_instead_of_display_order_words(
    isolated_postgres_url: str, tmp_path: Path
) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id = uuid4()
    try:
        await _prepare_tables(engine)
        async with sessions() as db:
            lesson_id, vocabulary_ids, grammar_ids = await _seed_first_lesson(db, tmp_path)
            user = User(id=user_id, email=f"{user_id}@example.test", nickname="문항 연결 검증")
            db.add(user)
            await db.flush()
            # Existing quiz learning must not be reset or attributed to a new word.
            db.add(
                UserVocabProgress(
                    user_id=user_id,
                    vocabulary_id=vocabulary_ids[605],
                    state="REVIEW",
                    correct_count=13,
                    incorrect_count=2,
                    fsrs_reps=15,
                    introduced_by="QUIZ",
                )
            )
            db.add(UserLessonProgress(user_id=user_id, lesson_id=lesson_id, status="COMPLETED", attempts=2, score_correct=5, score_total=5))
            await db.commit()
            # The seed is repeatable and does not modify a user's historical result.
            await _seed_first_lesson(db, tmp_path)
            historical = await db.scalar(select(UserLessonProgress).where(UserLessonProgress.user_id == user_id))
            assert historical is not None and (historical.attempts, historical.score_correct) == (2, 5)
            lesson = await db.get(Lesson, lesson_id)
            assert lesson is not None
            result = await submit_lesson_attempt(db, user, lesson_id=lesson_id, answers=_answers(lesson.content_jsonb, wrong_student=True))
            assert (result.score_correct, result.score_total, result.status) == (4, 5, "COMPLETED")

        # A fresh connection verifies that actual target records, not mocks, persisted.
        async with sessions() as db:
            words = {
                row.vocabulary_id: row
                for row in (await db.scalars(select(UserVocabProgress).where(UserVocabProgress.user_id == user_id))).all()
            }
            assert (words[vocabulary_ids[7]].correct_count, words[vocabulary_ids[7]].incorrect_count) == (0, 1)
            assert (words[vocabulary_ids[503]].correct_count, words[vocabulary_ids[503]].incorrect_count) == (1, 0)
            private_word = words[vocabulary_ids[605]]
            assert (private_word.correct_count, private_word.incorrect_count, private_word.fsrs_reps, private_word.introduced_by) == (
                13,
                2,
                15,
                "QUIZ",
            )
            assert all(words[vocabulary_ids[order]].fsrs_reps == 0 for order in (74, 6, 594))
            grammar = await db.scalar(select(UserGrammarProgress).where(UserGrammarProgress.user_id == user_id))
            assert grammar is not None and grammar.grammar_id == grammar_ids[1]
            # Existing per-question scheduling policy is preserved, including repeated grammar targets.
            assert (grammar.correct_count, grammar.incorrect_count, grammar.fsrs_reps) == (3, 0, 3)
            events = (
                await db.execute(
                    text("SELECT item_type, vocabulary_id, grammar_id, is_correct FROM review_events WHERE user_id=:id"), {"id": user_id}
                )
            ).all()
            assert len(events) == 5
            assert sum(row.item_type == "GRAMMAR" and row.grammar_id == grammar_ids[1] and row.is_correct for row in events) == 3
            assert sum(row.vocabulary_id == vocabulary_ids[7] and not row.is_correct for row in events) == 1
            assert not any(row.vocabulary_id in {vocabulary_ids[605], vocabulary_ids[74], vocabulary_ids[6]} for row in events)
            progress = await db.scalar(select(UserLessonProgress).where(UserLessonProgress.user_id == user_id))
            assert progress is not None and (progress.attempts, progress.score_correct, progress.score_total) == (3, 4, 5)
    finally:
        await engine.dispose()


@pytest.mark.parametrize("invalid", ["missing", "outside-lesson", "wrong-type", "conflicting", "malformed", "duplicate-link"])
async def test_invalid_lesson_mapping_keeps_existing_learning_records_unchanged(
    isolated_postgres_url: str, tmp_path: Path, invalid: str
) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id = uuid4()
    try:
        await _prepare_tables(engine)
        async with sessions() as db:
            lesson_id, vocabulary_ids, grammar_ids = await _seed_first_lesson(db, tmp_path)
            user = User(id=user_id, email=f"{user_id}@example.test", nickname="잘못된 연결 보존 검증")
            db.add(user)
            await db.flush()
            db.add(
                UserVocabProgress(user_id=user_id, vocabulary_id=vocabulary_ids[605], correct_count=9, incorrect_count=4, state="REVIEW")
            )
            db.add(UserLessonProgress(user_id=user_id, lesson_id=lesson_id, status="COMPLETED", attempts=3, score_correct=4, score_total=5))
            lesson = await db.get(Lesson, lesson_id)
            assert lesson is not None
            content = deepcopy(lesson.content_jsonb)
            question = content["questions"][-1]
            question.pop("grammar_id")
            if invalid == "outside-lesson":
                question["grammar_id"] = str(uuid4())
            elif invalid == "wrong-type":
                question["vocabulary_id"] = str(grammar_ids[1])
            elif invalid == "conflicting":
                question.update(vocabulary_id=str(vocabulary_ids[7]), grammar_id=str(grammar_ids[1]))
            elif invalid == "malformed":
                question["grammar_id"] = "invalid"
            elif invalid == "duplicate-link":
                question["grammar_id"] = str(grammar_ids[1])
                db.add(LessonItemLink(lesson_id=lesson_id, item_type="GRAMMAR", grammar_id=grammar_ids[1], item_order=8))
            lesson.content_jsonb = content
            await db.commit()
            with pytest.raises(LessonServiceError) as error:
                await submit_lesson_attempt(db, user, lesson_id=lesson_id, answers=_answers(content))
            assert error.value.status_code == 409
            await db.rollback()

        async with sessions() as db:
            progress = await db.scalar(select(UserLessonProgress).where(UserLessonProgress.user_id == user_id))
            assert progress is not None and (progress.attempts, progress.score_correct, progress.score_total) == (3, 4, 5)
            word = await db.scalar(select(UserVocabProgress).where(UserVocabProgress.user_id == user_id))
            assert word is not None and (word.correct_count, word.incorrect_count, word.state) == (9, 4, "REVIEW")
            assert await db.scalar(select(func.count()).select_from(UserVocabProgress).where(UserVocabProgress.user_id == user_id)) == 1
            assert await db.scalar(select(func.count()).select_from(UserGrammarProgress).where(UserGrammarProgress.user_id == user_id)) == 0
            assert await db.scalar(text("SELECT count(*) FROM review_events WHERE user_id=:id"), {"id": user_id}) == 0
    finally:
        await engine.dispose()


async def test_seed_adds_reviewed_non_core_target_and_preserves_intro_and_client_contract(
    isolated_postgres_url: str, tmp_path: Path
) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id = uuid4()
    try:
        await _prepare_tables(engine)
        async with sessions() as db:
            lesson_id, _, grammar_ids = await _seed_first_lesson(db, tmp_path, extra_target=True)
            user = User(id=user_id, email=f"{user_id}@example.test", nickname="추가 검수 항목")
            db.add(user)
            await db.commit()
            links = (
                await db.scalars(select(LessonItemLink).where(LessonItemLink.lesson_id == lesson_id).order_by(LessonItemLink.item_order))
            ).all()
            assert len(links) == 8 and all(link.is_core for link in links[:7])
            assert (links[-1].item_type, links[-1].grammar_id, links[-1].item_order, links[-1].is_core) == (
                "GRAMMAR",
                grammar_ids[55],
                8,
                False,
            )
            detail = await get_lesson_detail_data(db, user, lesson_id=lesson_id)
            assert detail is not None and len(detail.vocab_items) == 6 and len(detail.grammar_items) == 2
            # Supporting target cards are visible under the current existing detail behavior.
            response = LessonDetailResponse.model_validate(detail).model_dump(by_alias=True, mode="json")
            assert all(
                question["correctAnswer"] is None and question["correctOrder"] is None for question in response["content"]["questions"]
            )
            assert all("grammarId" not in question and "grammarOrder" not in question for question in response["content"]["questions"])
            lesson = await db.get(Lesson, lesson_id)
            assert lesson is not None
            result = await submit_lesson_attempt(db, user, lesson_id=lesson_id, answers=_answers(lesson.content_jsonb))
            assert result.srs_items_registered == 8
        async with sessions() as db:
            grammar = await db.scalar(
                select(UserGrammarProgress).where(UserGrammarProgress.user_id == user_id, UserGrammarProgress.grammar_id == grammar_ids[55])
            )
            assert grammar is not None and grammar.correct_count == 1
    finally:
        await engine.dispose()


async def test_reviewed_exclusion_grades_without_fabricating_an_srs_answer(isolated_postgres_url: str, tmp_path: Path) -> None:
    engine = create_async_engine(isolated_postgres_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    user_id = uuid4()
    try:
        await _prepare_tables(engine)
        async with sessions() as db:
            lesson_id, _, grammar_ids = await _seed_first_lesson(db, tmp_path)
            user = User(id=user_id, email=f"{user_id}@example.test", nickname="의도적 제외 검증")
            db.add(user)
            lesson = await db.get(Lesson, lesson_id)
            assert lesson is not None
            content = deepcopy(lesson.content_jsonb)
            content["questions"][-1].pop("grammar_id")
            content["questions"][-1]["srs_skip_reason"] = "여러 고정 표현을 조합하는 과제로 단일 복습 항목에 귀속하지 않음"
            lesson.content_jsonb = content
            await db.commit()
            result = await submit_lesson_attempt(db, user, lesson_id=lesson_id, answers=_answers(content))
            excluded = next(question for question in result.results if question.order == 5)
            assert (result.score_correct, result.score_total, result.status) == (5, 5, "COMPLETED")
            assert excluded.is_correct and excluded.state_before is None and excluded.next_review_at is None
        async with sessions() as db:
            assert await db.scalar(text("SELECT count(*) FROM review_events WHERE user_id=:id"), {"id": user_id}) == 4
            grammar = await db.scalar(
                select(UserGrammarProgress).where(UserGrammarProgress.user_id == user_id, UserGrammarProgress.grammar_id == grammar_ids[1])
            )
            assert grammar is not None and grammar.correct_count == 2
    finally:
        await engine.dispose()
