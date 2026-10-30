"""Validate stored quiz snapshots without repairing or re-generating their data."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Any, Literal, cast

from app.schemas.quiz import MatchingPair
from app.services.quiz_session import build_response_questions

ResumeStatus = Literal["available", "legacy_unavailable", "invalid_snapshot"]
SUPPORTED_MODES = frozenset({"normal", "matching", "arrange", "cloze", "review", "smart", "wrong_answer_review"})
LEGACY_UNAVAILABLE = "이 퀴즈는 이전 형식으로 저장되어 이어서 불러올 수 없어요. 저장된 학습 기록은 유지됩니다."
INVALID_SNAPSHOT = "퀴즈의 저장 정보를 안전하게 불러올 수 없어요. 저장된 학습 기록은 유지됩니다."


@dataclass(slots=True)
class QuizResumeSnapshot:
    mode: str | None
    status: ResumeStatus
    questions: list[dict[str, Any]]
    matching_pairs: list[MatchingPair] | None = None
    source: Literal["stored", "legacy_snapshot"] = "legacy_snapshot"


class InvalidQuizSnapshotError(ValueError):
    pass


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _uuid(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(uuid.UUID(value)) == value
    except ValueError:
        return False


def _require(condition: bool) -> None:
    if not condition:
        raise InvalidQuizSnapshotError


def _questions(raw: Any, total: int) -> list[dict[str, Any]]:
    _require(isinstance(raw, list) and bool(raw) and len(raw) == total)
    seen: set[str] = set()
    result: list[dict[str, Any]] = []
    for question in raw:
        _require(isinstance(question, dict))
        question_id = question.get("id")
        _require(_uuid(question_id) and question_id not in seen)
        _require(_text(question.get("question")) and isinstance(question.get("options"), list))
        seen.add(question_id)
        result.append(question)
    # Validate optional API fields before returning any apparently resumable data.
    build_response_questions(result)
    return result


def _kind(question: dict[str, Any]) -> str:
    if question["options"]:
        return "choice"
    if question.get("type") == "SENTENCE_ARRANGE" and question.get("correctOptionId") == "":
        return "arrange"
    if _uuid(question.get("correctOptionId")):
        if question.get("type") in {"VOCABULARY", "GRAMMAR"}:
            return "matching"
        if question.get("type") == "SENTENCE_ARRANGE":
            return "sentence_matching"
    raise InvalidQuizSnapshotError


def _validate_choices(questions: list[dict[str, Any]]) -> None:
    for question in questions:
        _require(question.get("type") in {None, "VOCABULARY", "GRAMMAR", "KANJI", "LISTENING", "CLOZE"})
        option_ids: set[str] = set()
        for option in question["options"]:
            _require(isinstance(option, dict) and _text(option.get("id")) and _text(option.get("text")))
            _require(option["id"] not in option_ids)
            option_ids.add(option["id"])
        _require(bool(option_ids) and question.get("correctOptionId") in option_ids)


def _validate_arrange(questions: list[dict[str, Any]]) -> None:
    for question in questions:
        tokens = question.get("tokens")
        _require(question.get("type") == "SENTENCE_ARRANGE" and question["options"] == [])
        _require(question.get("correctOptionId") == "" and _text(question.get("japaneseSentence")))
        _require(isinstance(tokens, list) and bool(tokens) and all(_text(token) for token in tokens))


def _matching_pairs(questions: list[dict[str, Any]], stored: Any) -> list[MatchingPair]:
    pair_ids: set[str] = set()
    pairs: list[MatchingPair] = []
    if stored is not None:
        _require(isinstance(stored, list) and len(stored) == len(questions))
        for raw_pair in stored:
            _require(isinstance(raw_pair, dict) and _uuid(raw_pair.get("id")))
            _require(_text(raw_pair.get("word")) and _text(raw_pair.get("meaning")))
            pair = MatchingPair(**raw_pair)
            _require(pair.id not in pair_ids)
            pair_ids.add(pair.id)
            pairs.append(pair)
    else:
        # Only exact known legacy vocabulary/grammar serializers contain both sides.
        for question in questions:
            field = "word" if question.get("type") == "VOCABULARY" else "pattern"
            _require(question.get("type") in {"VOCABULARY", "GRAMMAR"})
            _require(_text(question.get(field)) and question[field] == question["question"] and _text(question.get("meaningKo")))
            pair_id = question.get("correctOptionId")
            _require(_uuid(pair_id) and pair_id not in pair_ids)
            pair_id = cast(str, pair_id)
            pair_ids.add(pair_id)
            pairs.append(MatchingPair(id=pair_id, word=question[field], meaning=question["meaningKo"]))
    by_id = {pair.id: pair for pair in pairs}
    used: set[str] = set()
    for question in questions:
        pair_id = question.get("correctOptionId")
        _require(question["options"] == [] and _uuid(pair_id) and pair_id not in used and pair_id in by_id)
        pair_id = cast(str, pair_id)
        pair = by_id[pair_id]
        _require(pair.word == question["question"])
        question_type = question.get("type")
        if question_type in {"VOCABULARY", "GRAMMAR"}:
            field = "word" if question_type == "VOCABULARY" else "pattern"
            _require(question.get(field) == pair.word and question.get("meaningKo") == pair.meaning)
        else:
            _require(question_type == "SENTENCE_ARRANGE" and question.get("japaneseSentence") == pair.meaning)
        used.add(pair_id)
    _require(used == pair_ids)
    return pairs


def decode_quiz_resume_snapshot(raw: Any, *, total_questions: int, quiz_type: str | None = None) -> QuizResumeSnapshot:
    """Decode only known stored formats; never consult current content or mutate raw."""
    mode: str | None = None
    source: Literal["stored", "legacy_snapshot"] = "legacy_snapshot"
    try:
        if isinstance(raw, dict):
            raw_mode = raw.get("mode")
            _require(raw_mode is None or isinstance(raw_mode, str) and raw_mode in SUPPORTED_MODES)
            mode = raw_mode
            source = "stored" if mode is not None else "legacy_snapshot"
            raw_questions = raw.get("questions")
        else:
            _require(isinstance(raw, list))
            raw_questions = raw
        questions = _questions(raw_questions, total_questions)
        kinds = {_kind(question) for question in questions}
        _require(len(kinds) == 1)
        kind = next(iter(kinds))
        question_types = {question.get("type") for question in questions}
        _require(len(question_types) == 1)
        declared_type = next(iter(question_types))
        if quiz_type is not None and kind != "arrange" and declared_type not in {None, "CLOZE"}:
            same_vocabulary_catalog = declared_type == "VOCABULARY" and quiz_type in {"VOCABULARY", "KANJI", "LISTENING"}
            _require(declared_type == quiz_type or same_vocabulary_catalog)
        if kind == "sentence_matching" and (not isinstance(raw, dict) or raw.get("matchingPairs") is None):
            _require(mode in {None, "matching"})
            return QuizResumeSnapshot("matching", "legacy_unavailable", questions, source=source)
        if kind in {"matching", "sentence_matching"}:
            _require(mode in {None, "matching"})
            _require(len({question.get("type") for question in questions}) == 1)
            stored_pairs = raw.get("matchingPairs") if isinstance(raw, dict) else None
            pairs = _matching_pairs(questions, stored_pairs)
            return QuizResumeSnapshot("matching", "available", questions, pairs, source)
        if kind == "arrange":
            _require(mode in {None, "arrange"})
            _validate_arrange(questions)
            # A legacy vocabulary/grammar session cannot safely change its
            # answer category or SRS meaning merely because it has tokens.
            if quiz_type != "SENTENCE_ARRANGE":
                return QuizResumeSnapshot("arrange", "legacy_unavailable", questions, source=source)
            return QuizResumeSnapshot("arrange", "available", questions, source=source)
        _require(mode not in {"matching", "arrange"})
        if isinstance(raw, dict):
            _require(raw.get("matchingPairs") is None)
        _validate_choices(questions)
        if mode == "cloze":
            _require(question_types == {"CLOZE"} or question_types == {None} and quiz_type == "CLOZE")
        if mode is None:
            types = {question.get("type") for question in questions}
            mode = "cloze" if types == {"CLOZE"} or quiz_type == "CLOZE" else "normal"
        return QuizResumeSnapshot(mode, "available", questions, source=source)
    except (InvalidQuizSnapshotError, KeyError, TypeError, ValueError):
        return QuizResumeSnapshot(mode, "invalid_snapshot", [], source=source)


def snapshot_error_message(status: ResumeStatus) -> str:
    return LEGACY_UNAVAILABLE if status == "legacy_unavailable" else INVALID_SNAPSHOT
