from __future__ import annotations

from app.schemas.study import (
    LearnedWordEntry,
    LearnedWordsResponse,
    LearnedWordsSummary,
    QuizCapabilitiesResponse,
    SmartCapabilitiesResponse,
    SmartCategoryCapability,
    StageCapabilitiesResponse,
    StudyCapabilitiesResponse,
    StudyStageResponse,
    StudyStageUserProgress,
    StudyWrongAnswerEntry,
    StudyWrongAnswersResponse,
    StudyWrongAnswersSummary,
)
from app.services.study_capabilities import StudyCapabilitiesResult
from app.services.study_stage_query import StudyStageEntryData
from app.services.study_word_progress import LearnedWordsResult, StudyWrongAnswersResult


def to_learned_words_response(result: LearnedWordsResult) -> LearnedWordsResponse:
    return LearnedWordsResponse(
        entries=[
            LearnedWordEntry(
                id=item.id,
                vocabulary_id=item.vocabulary_id,
                word=item.word,
                reading=item.reading,
                meaning_ko=item.meaning_ko,
                jlpt_level=item.jlpt_level,
                example_sentence=item.example_sentence,
                example_translation=item.example_translation,
                correct_count=item.correct_count,
                incorrect_count=item.incorrect_count,
                streak=item.streak,
                mastered=item.mastered,
                last_reviewed_at=item.last_reviewed_at,
            )
            for item in result.entries
        ],
        total=result.total,
        page=result.page,
        total_pages=result.total_pages,
        summary=LearnedWordsSummary(
            total_learned=result.total_learned,
            mastered=result.mastered_count,
            learning=result.total_learned - result.mastered_count,
        ),
    )


def to_study_wrong_answers_response(result: StudyWrongAnswersResult) -> StudyWrongAnswersResponse:
    return StudyWrongAnswersResponse(
        entries=[
            StudyWrongAnswerEntry(
                id=item.id,
                vocabulary_id=item.vocabulary_id,
                word=item.word,
                reading=item.reading,
                meaning_ko=item.meaning_ko,
                jlpt_level=item.jlpt_level,
                example_sentence=item.example_sentence,
                example_translation=item.example_translation,
                correct_count=item.correct_count,
                incorrect_count=item.incorrect_count,
                mastered=item.mastered,
                last_reviewed_at=item.last_reviewed_at,
            )
            for item in result.entries
        ],
        total=result.total,
        page=result.page,
        total_pages=result.total_pages,
        summary=StudyWrongAnswersSummary(
            total_wrong=result.total_wrong,
            mastered=result.mastered_wrong,
            remaining=result.total_wrong - result.mastered_wrong,
        ),
    )


def to_study_stage_responses(stages: list[StudyStageEntryData]) -> list[StudyStageResponse]:
    return [
        StudyStageResponse(
            id=stage.id,
            category=stage.category,
            jlpt_level=stage.jlpt_level,
            stage_number=stage.stage_number,
            title=stage.title,
            description=stage.description,
            content_count=stage.content_count,
            is_locked=stage.is_locked,
            user_progress=(
                StudyStageUserProgress(
                    best_score=stage.user_progress.best_score,
                    attempts=stage.user_progress.attempts,
                    completed=stage.user_progress.completed,
                    completed_at=stage.user_progress.completed_at,
                    last_attempted_at=stage.user_progress.last_attempted_at,
                )
                if stage.user_progress
                else None
            ),
        )
        for stage in stages
    ]


def to_study_capabilities_response(capabilities: StudyCapabilitiesResult) -> StudyCapabilitiesResponse:
    return StudyCapabilitiesResponse(
        requested_jlpt_level=capabilities.requested_jlpt_level,
        effective_jlpt_level=capabilities.effective_jlpt_level,
        quiz=QuizCapabilitiesResponse(
            vocabulary=capabilities.quiz.vocabulary,
            grammar=capabilities.quiz.grammar,
            kanji=capabilities.quiz.kanji,
            listening=capabilities.quiz.listening,
            kana=capabilities.quiz.kana,
            cloze=capabilities.quiz.cloze,
            sentence_arrange=capabilities.quiz.sentence_arrange,
        ),
        smart=SmartCapabilitiesResponse(
            vocabulary=SmartCategoryCapability(
                available=capabilities.smart.vocabulary.available,
                has_pool=capabilities.smart.vocabulary.has_pool,
            ),
            grammar=SmartCategoryCapability(
                available=capabilities.smart.grammar.available,
                has_pool=capabilities.smart.grammar.has_pool,
            ),
        ),
        lesson=capabilities.lesson,
        stage=StageCapabilitiesResponse(
            vocabulary=capabilities.stage.vocabulary,
            grammar=capabilities.stage.grammar,
            sentence=capabilities.stage.sentence,
        ),
    )
