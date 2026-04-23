from __future__ import annotations

from app.services.study_capabilities import (
    QuizCapabilitiesData,
    SmartCapabilitiesData,
    SmartCategoryCapabilityData,
    StageCapabilitiesData,
    StudyCapabilitiesResult,
)
from app.services.study_responses import (
    to_learned_words_response,
    to_study_capabilities_response,
    to_study_stage_responses,
    to_study_wrong_answers_response,
)
from app.services.study_stage_query import StudyStageEntryData, StudyStageProgressData
from app.services.study_word_progress import (
    LearnedWordEntryData,
    LearnedWordsResult,
    StudyWrongAnswerEntryData,
    StudyWrongAnswersResult,
)


def test_to_learned_words_response_builds_entries_and_summary() -> None:
    result = LearnedWordsResult(
        entries=[
            LearnedWordEntryData(
                id="progress-1",
                vocabulary_id="vocab-1",
                word="食べる",
                reading="たべる",
                meaning_ko="먹다",
                jlpt_level="N5",
                example_sentence="ごはんを食べる。",
                example_translation="밥을 먹다.",
                correct_count=7,
                incorrect_count=2,
                streak=3,
                mastered=False,
                last_reviewed_at=None,
            )
        ],
        total=1,
        page=1,
        total_pages=1,
        total_learned=4,
        mastered_count=1,
    )

    response = to_learned_words_response(result)

    assert response.model_dump(by_alias=True) == {
        "entries": [
            {
                "id": "progress-1",
                "vocabularyId": "vocab-1",
                "word": "食べる",
                "reading": "たべる",
                "meaningKo": "먹다",
                "jlptLevel": "N5",
                "exampleSentence": "ごはんを食べる。",
                "exampleTranslation": "밥을 먹다.",
                "correctCount": 7,
                "incorrectCount": 2,
                "streak": 3,
                "mastered": False,
                "lastReviewedAt": None,
            }
        ],
        "total": 1,
        "page": 1,
        "totalPages": 1,
        "summary": {
            "totalLearned": 4,
            "mastered": 1,
            "learning": 3,
        },
    }


def test_to_study_wrong_answers_response_builds_entries_and_summary() -> None:
    result = StudyWrongAnswersResult(
        entries=[
            StudyWrongAnswerEntryData(
                id="progress-1",
                vocabulary_id="vocab-1",
                word="飲む",
                reading="のむ",
                meaning_ko="마시다",
                jlpt_level="N4",
                example_sentence="水を飲む。",
                example_translation="물을 마시다.",
                correct_count=2,
                incorrect_count=5,
                mastered=True,
                last_reviewed_at=None,
            )
        ],
        total=1,
        page=1,
        total_pages=1,
        total_wrong=6,
        mastered_wrong=2,
    )

    response = to_study_wrong_answers_response(result)

    assert response.model_dump(by_alias=True) == {
        "entries": [
            {
                "id": "progress-1",
                "vocabularyId": "vocab-1",
                "word": "飲む",
                "reading": "のむ",
                "meaningKo": "마시다",
                "jlptLevel": "N4",
                "exampleSentence": "水を飲む。",
                "exampleTranslation": "물을 마시다.",
                "correctCount": 2,
                "incorrectCount": 5,
                "mastered": True,
                "lastReviewedAt": None,
            }
        ],
        "total": 1,
        "page": 1,
        "totalPages": 1,
        "summary": {
            "totalWrong": 6,
            "mastered": 2,
            "remaining": 4,
        },
    }


def test_to_study_stage_responses_builds_progress_payload() -> None:
    response = to_study_stage_responses(
        [
            StudyStageEntryData(
                id="stage-1",
                category="VOCABULARY",
                jlpt_level="N5",
                stage_number=1,
                title="기초 단어",
                description=None,
                content_count=2,
                is_locked=False,
                user_progress=StudyStageProgressData(
                    best_score=95,
                    attempts=3,
                    completed=True,
                    completed_at=None,
                    last_attempted_at=None,
                ),
            )
        ]
    )

    assert [item.model_dump(by_alias=True) for item in response] == [
        {
            "id": "stage-1",
            "category": "VOCABULARY",
            "jlptLevel": "N5",
            "stageNumber": 1,
            "title": "기초 단어",
            "description": None,
            "contentCount": 2,
            "isLocked": False,
            "userProgress": {
                "bestScore": 95,
                "attempts": 3,
                "completed": True,
                "completedAt": None,
                "lastAttemptedAt": None,
            },
        }
    ]


def test_to_study_capabilities_response_preserves_alias_keys() -> None:
    result = StudyCapabilitiesResult(
        requested_jlpt_level="N4",
        effective_jlpt_level="N4",
        quiz=QuizCapabilitiesData(
            vocabulary=True,
            grammar=True,
            kanji=False,
            listening=False,
            kana=True,
            cloze=False,
            sentence_arrange=True,
        ),
        smart=SmartCapabilitiesData(
            vocabulary=SmartCategoryCapabilityData(available=True, has_pool=True),
            grammar=SmartCategoryCapabilityData(available=True, has_pool=False),
        ),
        lesson=True,
        stage=StageCapabilitiesData(vocabulary=True, grammar=True, sentence=False),
    )

    response = to_study_capabilities_response(result)

    assert response.model_dump(by_alias=True) == {
        "requestedJlptLevel": "N4",
        "effectiveJlptLevel": "N4",
        "quiz": {
            "VOCABULARY": True,
            "GRAMMAR": True,
            "KANJI": False,
            "LISTENING": False,
            "KANA": True,
            "CLOZE": False,
            "SENTENCE_ARRANGE": True,
        },
        "smart": {
            "VOCABULARY": {
                "available": True,
                "hasPool": True,
            },
            "GRAMMAR": {
                "available": True,
                "hasPool": False,
            },
        },
        "lesson": True,
        "stage": {
            "VOCABULARY": True,
            "GRAMMAR": True,
            "SENTENCE": False,
        },
    }
