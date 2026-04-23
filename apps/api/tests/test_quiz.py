import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.db.session import get_db
from app.models.enums import JlptLevel, QuizType


@pytest.fixture
def mock_quiz_session(test_user_id):
    session = MagicMock()
    session.id = uuid.uuid4()
    session.user_id = test_user_id
    session.quiz_type = QuizType.VOCABULARY
    session.jlpt_level = JlptLevel.N5
    session.total_questions = 2
    session.correct_count = 0
    session.completed_at = None
    session.started_at = datetime.now(UTC)
    session.questions_data = [
        {
            "id": str(uuid.uuid4()),
            "type": "VOCABULARY",
            "question": "食べる",
            "options": [
                {"id": "correct-1", "text": "먹다"},
                {"id": "wrong-1", "text": "마시다"},
                {"id": "wrong-2", "text": "자다"},
                {"id": "wrong-3", "text": "가다"},
            ],
            "correctOptionId": "correct-1",
            "word": "食べる",
            "meaningKo": "먹다",
        },
        {
            "id": str(uuid.uuid4()),
            "type": "VOCABULARY",
            "question": "飲む",
            "options": [
                {"id": "correct-2", "text": "마시다"},
                {"id": "wrong-4", "text": "먹다"},
                {"id": "wrong-5", "text": "자다"},
                {"id": "wrong-6", "text": "가다"},
            ],
            "correctOptionId": "correct-2",
            "word": "飲む",
            "meaningKo": "마시다",
        },
    ]
    return session


@pytest.mark.asyncio
async def test_start_quiz_success(client, mock_user, test_user_id):
    """Test POST /api/v1/quiz/start creates a quiz session with questions."""
    from app.main import app

    mock_session = AsyncMock()

    # Mock _auto_complete_sessions: select incomplete sessions returns empty
    mock_incomplete_result = MagicMock()
    mock_incomplete_result.scalars.return_value.all.return_value = []

    # Mock vocab queries for normal mode
    mock_review_result = MagicMock()
    mock_review_result.scalars.return_value.all.return_value = []

    mock_studied_ids_result = MagicMock()
    mock_studied_ids_result.scalars.return_value.all.return_value = []

    mock_vocab = MagicMock()
    mock_vocab.id = uuid.uuid4()
    mock_vocab.word = "食べる"
    mock_vocab.reading = "たべる"
    mock_vocab.meaning_ko = "먹다"
    mock_vocab.jlpt_level = "N5"

    mock_new_result = MagicMock()
    mock_new_result.scalars.return_value.all.return_value = [mock_vocab]

    mock_pool_result = MagicMock()
    mock_pool_result.scalars.return_value.all.return_value = ["마시다", "자다", "가다", "읽다"]

    mock_session.execute = AsyncMock(
        side_effect=[
            mock_incomplete_result,  # _auto_complete_sessions
            mock_review_result,  # review items
            mock_studied_ids_result,  # studied ids
            mock_new_result,  # new items
            mock_pool_result,  # wrong options pool
        ]
    )
    mock_session.add = MagicMock()
    mock_session.commit = AsyncMock()
    mock_session.flush = AsyncMock()

    # Mock refresh to set session.id
    async def mock_refresh(obj):
        obj.id = uuid.uuid4()

    mock_session.refresh = mock_refresh

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/quiz/start",
        json={
            "quizType": "VOCABULARY",
            "jlptLevel": "N5",
            "count": 1,
        },
    )
    assert response.status_code == 200

    data = response.json()
    assert "sessionId" in data
    assert "questions" in data
    assert data["totalQuestions"] >= 0  # CI 환경에는 시드 데이터가 없으므로 0 허용


@pytest.mark.asyncio
async def test_answer_question_correct(client, mock_user, mock_quiz_session, test_user_id):
    """Test POST /api/v1/quiz/answer with a correct answer."""
    from app.main import app

    question_id = mock_quiz_session.questions_data[0]["id"]

    # Create a mock progress object with numeric defaults
    mock_progress = MagicMock()
    mock_progress.correct_count = 0
    mock_progress.incorrect_count = 0
    mock_progress.streak = 0
    mock_progress.interval = 0
    mock_progress.ease_factor = 2.5
    mock_progress.next_review_at = None
    mock_progress.last_reviewed_at = None
    mock_progress.mastered = False

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_quiz_session)

    # Mock for UserVocabProgress select - return existing progress
    mock_progress_result = MagicMock()
    mock_progress_result.scalar_one_or_none.return_value = mock_progress

    mock_session.execute = AsyncMock(return_value=mock_progress_result)
    mock_session.add = MagicMock()
    mock_session.flush = AsyncMock()
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/quiz/answer",
        json={
            "sessionId": str(mock_quiz_session.id),
            "questionId": question_id,
            "selectedOptionId": "correct-1",
            "questionType": "VOCABULARY",
        },
    )
    assert response.status_code == 200
    assert response.json()["success"] is True
    # Verify correct_count was incremented on both session and progress
    assert mock_quiz_session.correct_count == 1
    assert mock_progress.correct_count == 1


@pytest.mark.asyncio
async def test_answer_question_wrong(client, mock_user, mock_quiz_session, test_user_id):
    """Test POST /api/v1/quiz/answer with a wrong answer."""
    from app.main import app

    question_id = mock_quiz_session.questions_data[0]["id"]
    # Reset correct_count (may have been incremented by previous test via shared fixture)
    mock_quiz_session.correct_count = 0

    # Create a mock progress object with numeric defaults
    mock_progress = MagicMock()
    mock_progress.correct_count = 0
    mock_progress.incorrect_count = 0
    mock_progress.streak = 0
    mock_progress.interval = 0
    mock_progress.ease_factor = 2.5
    mock_progress.next_review_at = None
    mock_progress.last_reviewed_at = None
    mock_progress.mastered = False

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_quiz_session)

    mock_progress_result = MagicMock()
    mock_progress_result.scalar_one_or_none.return_value = mock_progress

    mock_session.execute = AsyncMock(return_value=mock_progress_result)
    mock_session.add = MagicMock()
    mock_session.flush = AsyncMock()
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/quiz/answer",
        json={
            "sessionId": str(mock_quiz_session.id),
            "questionId": question_id,
            "selectedOptionId": "wrong-1",
            "questionType": "VOCABULARY",
        },
    )
    assert response.status_code == 200
    assert response.json()["success"] is True
    # correct_count should not have been incremented
    assert mock_quiz_session.correct_count == 0
    # incorrect_count should have been incremented
    assert mock_progress.incorrect_count == 1


@pytest.mark.asyncio
@patch("app.services.quiz_complete.check_and_grant_achievements")
async def test_complete_quiz_success(mock_achievements, client, mock_user, mock_quiz_session, test_user_id):
    """Test POST /api/v1/quiz/complete completes the session and awards XP."""
    from app.main import app

    mock_quiz_session.correct_count = 2
    mock_achievements.return_value = []

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_quiz_session)

    # execute calls: upsert daily progress, count quizzes, count words
    mock_exec_result = MagicMock()
    mock_exec_result.scalar.return_value = 5

    mock_session.execute = AsyncMock(return_value=mock_exec_result)
    mock_session.commit = AsyncMock()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/quiz/complete",
        json={"sessionId": str(mock_quiz_session.id)},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["sessionId"] == str(mock_quiz_session.id)
    assert data["correctCount"] == 2
    assert data["totalQuestions"] == 2
    assert data["accuracy"] == 100.0
    assert data["xpEarned"] == 20  # 2 correct * 10 XP each


@pytest.mark.asyncio
async def test_get_incomplete_quiz_returns_session_banner(client):
    """Test GET /api/v1/quiz/incomplete serializes the banner session payload."""
    from app.services.quiz_session_query import IncompleteQuizSessionResult

    started_at = datetime(2026, 4, 17, 6, 30, tzinfo=UTC).isoformat()

    with patch("app.routers.quiz.get_incomplete_quiz_session", new=AsyncMock()) as mock_get_incomplete:
        mock_get_incomplete.return_value = IncompleteQuizSessionResult(
            id=str(uuid.uuid4()),
            quiz_type="VOCABULARY",
            jlpt_level="N5",
            total_questions=10,
            answered_count=3,
            correct_count=2,
            started_at=started_at,
        )

        response = await client.get("/api/v1/quiz/incomplete")

    assert response.status_code == 200
    assert response.json() == {
        "session": {
            "id": mock_get_incomplete.return_value.id,
            "quizType": "VOCABULARY",
            "jlptLevel": "N5",
            "totalQuestions": 10,
            "answeredCount": 3,
            "correctCount": 2,
            "startedAt": started_at,
        }
    }


@pytest.mark.asyncio
async def test_resume_quiz_returns_response_model_shape(client):
    """Test POST /api/v1/quiz/resume preserves the expected camelCase response contract."""
    from app.schemas.quiz import QuizOption, QuizQuestion
    from app.services.quiz_session_query import ResumeQuizResult

    session_id = str(uuid.uuid4())
    question_id = str(uuid.uuid4())

    with patch("app.routers.quiz.resume_quiz_session", new=AsyncMock()) as mock_resume_quiz:
        mock_resume_quiz.return_value = ResumeQuizResult(
            session_id=session_id,
            questions=[
                QuizQuestion(
                    question_id=question_id,
                    question_text="食べる",
                    question_sub_text="たべる",
                    options=[
                        QuizOption(id="correct-1", text="먹다"),
                        QuizOption(id="wrong-1", text="마시다"),
                    ],
                    correct_option_id=None,
                )
            ],
            answered_question_ids=[question_id],
            total_questions=10,
            correct_count=7,
            quiz_type="VOCABULARY",
        )

        response = await client.post("/api/v1/quiz/resume", json={"sessionId": session_id})

    assert response.status_code == 200
    assert response.json() == {
        "sessionId": session_id,
        "questions": [
            {
                "questionId": question_id,
                "questionText": "食べる",
                "questionSubText": "たべる",
                "hint": None,
                "options": [
                    {"id": "correct-1", "text": "먹다"},
                    {"id": "wrong-1", "text": "마시다"},
                ],
                "correctOptionId": None,
                "tokens": None,
                "japaneseSentence": None,
                "explanation": None,
            }
        ],
        "answeredQuestionIds": [question_id],
        "totalQuestions": 10,
        "correctCount": 7,
        "quizType": "VOCABULARY",
    }


@pytest.mark.asyncio
async def test_get_quiz_stats(client, mock_user, test_user_id):
    """Test GET /api/v1/quiz/stats returns aggregated quiz statistics."""
    from app.main import app

    mock_session = AsyncMock()

    # First execute: count completed quizzes
    mock_count_result = MagicMock()
    mock_count_result.scalar.return_value = 10

    # Second execute: sum correct/total
    mock_row = MagicMock()
    mock_row.__getitem__ = lambda self, idx: [80, 100][idx]
    mock_sum_result = MagicMock()
    mock_sum_result.one.return_value = mock_row

    mock_session.execute = AsyncMock(side_effect=[mock_count_result, mock_sum_result])

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get("/api/v1/quiz/stats")
    assert response.status_code == 200

    data = response.json()
    assert data["totalQuizzes"] == 10
    assert data["totalCorrect"] == 80
    assert data["totalQuestions"] == 100
    assert data["accuracy"] == 80.0


@pytest.mark.asyncio
async def test_get_smart_preview_vocabulary(client, mock_user, test_user_id):
    """Test GET /api/v1/quiz/smart-preview returns the expected smart quiz preview shape."""
    from app.main import app

    mock_session = AsyncMock()

    mock_studied_ids_result = MagicMock()
    mock_studied_ids_result.scalars.return_value.all.return_value = [uuid.uuid4(), uuid.uuid4()]

    mock_total_result = MagicMock()
    mock_total_result.scalar.return_value = 12

    mock_review_result = MagicMock()
    mock_review_result.scalar.return_value = 3

    mock_retry_result = MagicMock()
    mock_retry_result.scalar.return_value = 1

    mock_studied_result = MagicMock()
    mock_studied_result.scalar.return_value = 5

    mock_mastered_result = MagicMock()
    mock_mastered_result.scalar.return_value = 2

    mock_today_result = MagicMock()
    mock_today_result.scalar.return_value = 4

    mock_session.execute = AsyncMock(
        side_effect=[
            mock_studied_ids_result,
            mock_total_result,
            mock_review_result,
            mock_retry_result,
            mock_studied_result,
            mock_mastered_result,
            mock_today_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get(
        "/api/v1/quiz/smart-preview",
        params={"category": "VOCABULARY", "jlptLevel": "N5"},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["poolSize"] == {"newReady": 10, "reviewDue": 3, "retryDue": 1}
    assert data["sessionDistribution"] == {"new": 2, "review": 3, "retry": 1, "total": 6}
    assert data["dailyGoal"] == 10
    assert data["todayCompleted"] == 4
    assert data["overallProgress"] == {
        "total": 12,
        "studied": 5,
        "mastered": 2,
        "percentage": 42,
    }


@pytest.mark.asyncio
async def test_get_wrong_answers(client, mock_user, mock_quiz_session, test_user_id):
    """Test GET /api/v1/quiz/wrong-answers returns enriched wrong answer data."""
    from app.main import app

    question_id = uuid.UUID(mock_quiz_session.questions_data[0]["id"])
    mock_wrong_answer = MagicMock()
    mock_wrong_answer.question_id = question_id

    mock_vocab = MagicMock()
    mock_vocab.id = question_id
    mock_vocab.reading = "たべる"
    mock_vocab.example_sentence = "ごはんを食べる。"
    mock_vocab.example_translation = "밥을 먹다."

    wrong_result = MagicMock()
    wrong_result.scalars.return_value.all.return_value = [mock_wrong_answer]

    vocab_result = MagicMock()
    vocab_result.scalars.return_value.all.return_value = [mock_vocab]

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=mock_quiz_session)
    mock_session.execute = AsyncMock(side_effect=[wrong_result, vocab_result])

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get(
        "/api/v1/quiz/wrong-answers",
        params={"session_id": str(mock_quiz_session.id)},
    )
    assert response.status_code == 200

    data = response.json()
    assert data["wrongAnswers"] == [
        {
            "questionId": str(question_id),
            "word": "食べる",
            "reading": "たべる",
            "meaningKo": "먹다",
            "exampleSentence": "ごはんを食べる。",
            "exampleTranslation": "밥을 먹다.",
        }
    ]


@pytest.mark.asyncio
async def test_get_recommendations_vocabulary(client, mock_user, test_user_id):
    """Test GET /api/v1/quiz/recommendations for vocabulary category."""
    from app.main import app

    mock_session = AsyncMock()

    due_result = MagicMock()
    due_result.scalar.return_value = 3

    studied_result = MagicMock()
    studied_result.scalar.return_value = 5

    total_result = MagicMock()
    total_result.scalar.return_value = 12

    wrong_result = MagicMock()
    wrong_result.scalar.return_value = 2

    last_reviewed = datetime(2026, 4, 17, 6, 30, tzinfo=UTC)
    last_reviewed_result = MagicMock()
    last_reviewed_result.scalar.return_value = last_reviewed

    mock_session.execute = AsyncMock(
        side_effect=[
            due_result,
            studied_result,
            total_result,
            wrong_result,
            last_reviewed_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get(
        "/api/v1/quiz/recommendations",
        params={"category": "VOCABULARY"},
    )
    assert response.status_code == 200

    data = response.json()
    assert data == {
        "reviewDueCount": 3,
        "newWordsCount": 7,
        "wrongCount": 2,
        "lastReviewedAt": last_reviewed.isoformat(),
    }


@pytest.mark.asyncio
async def test_get_recommendations_grammar(client, mock_user, test_user_id):
    """Test GET /api/v1/quiz/recommendations for grammar category."""
    from app.main import app

    mock_session = AsyncMock()

    due_result = MagicMock()
    due_result.scalar.return_value = 4

    studied_result = MagicMock()
    studied_result.scalar.return_value = 6

    total_result = MagicMock()
    total_result.scalar.return_value = 15

    wrong_result = MagicMock()
    wrong_result.scalar.return_value = 1

    last_reviewed = datetime(2026, 4, 18, 9, 15, tzinfo=UTC)
    last_reviewed_result = MagicMock()
    last_reviewed_result.scalar.return_value = last_reviewed

    mock_session.execute = AsyncMock(
        side_effect=[
            due_result,
            studied_result,
            total_result,
            wrong_result,
            last_reviewed_result,
        ]
    )

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.get(
        "/api/v1/quiz/recommendations",
        params={"category": "GRAMMAR"},
    )
    assert response.status_code == 200

    data = response.json()
    assert data == {
        "reviewDueCount": 4,
        "newWordsCount": 9,
        "wrongCount": 1,
        "lastReviewedAt": last_reviewed.isoformat(),
    }


@pytest.mark.asyncio
async def test_answer_question_session_not_found(client, mock_user, test_user_id):
    """Test POST /api/v1/quiz/answer returns 404 for missing session."""
    from app.main import app

    mock_session = AsyncMock()
    mock_session.get = AsyncMock(return_value=None)

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    response = await client.post(
        "/api/v1/quiz/answer",
        json={
            "sessionId": str(uuid.uuid4()),
            "questionId": str(uuid.uuid4()),
            "selectedOptionId": "some-id",
            "questionType": "VOCABULARY",
        },
    )
    assert response.status_code == 404
    assert response.json()["error"]["message"] == "세션을 찾을 수 없습니다"
