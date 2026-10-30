import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('QuizSessionController', () {
    test('wrong review restores only unanswered source items in order',
        () async {
      final repository = _FakeStudyRepository()
        ..wrongReviewAnsweredIds = ['q2', 'q2', 'not-in-this-session'];
      final container = ProviderContainer(overrides: [
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(quizSessionProvider.notifier);
      await controller.initialize(const QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 0,
        sourceSessionId: 'completed-source',
      ));
      final state = container.read(quizSessionProvider);
      expect(repository.wrongReviewSources, ['completed-source']);
      expect(repository.startQuizCalls, 0);
      expect(repository.resumeQuizCalls, 0);
      expect(state.sessionId, 'wrong-review-child');
      expect(state.resolvedMode, 'wrong_answer_review');
      expect(state.sessionQuizType, 'GRAMMAR');
      expect(state.questions.map((q) => q.questionId), ['q2', 'q1', 'q3']);
      expect(state.currentIndex, 1);
      expect(state.currentQuestion!.questionId, 'q1');
      controller.advanceToNextQuestion();
      expect(container.read(quizSessionProvider).currentQuestion!.questionId,
          'q3');
    });

    test(
        'wrong-review retry preserves source and never falls back to general review',
        () async {
      final repository = _FakeStudyRepository()..failedWrongReviews = 1;
      final container = ProviderContainer(overrides: [
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(quizSessionProvider.notifier);
      const request = QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 0,
        sourceSessionId: 'same-source',
      );
      await controller.initialize(request);
      expect(container.read(quizSessionProvider).loadError, isNotNull);
      await controller.initialize(request);
      expect(repository.wrongReviewSources, ['same-source', 'same-source']);
      expect(repository.startQuizCalls, 0);
      expect(repository.resumeQuizCalls, 0);
      expect(container.read(quizSessionProvider).loadError, isNull);
    });

    test('initialization errors are distinct from an empty content response',
        () async {
      final repository = _FakeStudyRepository()..failedStarts = 1;
      final container = ProviderContainer(overrides: [
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      await container.read(quizSessionProvider.notifier).initialize(
            const QuizSessionRequest(
              quizType: 'VOCABULARY',
              jlptLevel: 'N5',
              count: 10,
              mode: 'review',
            ),
          );
      final state = container.read(quizSessionProvider);
      expect(state.loading, isFalse);
      expect(state.loadError, '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
      expect(state.questions, isEmpty);
      expect(repository.startQuizCalls, 1);
      expect(repository.answerCalls, 0);
      expect(repository.completeQuizCalls, 0);
    });

    test('resuming after failure uses the same session and clears the error',
        () async {
      final repository = _FakeStudyRepository()..failedResumes = 1;
      final container = ProviderContainer(overrides: [
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(quizSessionProvider.notifier);
      const request = QuizSessionRequest(
        quizType: 'GRAMMAR',
        jlptLevel: 'N5',
        count: 10,
        resumeSessionId: 'original-session',
      );
      await controller.initialize(request);
      expect(container.read(quizSessionProvider).loadError, isNotNull);
      await controller.initialize(request);
      expect(repository.resumedSessionIds,
          ['original-session', 'original-session']);
      expect(repository.startQuizCalls, 0);
      expect(container.read(quizSessionProvider).loadError, isNull);
      expect(container.read(quizSessionProvider).currentIndex, 1);
    });

    test('late initialization cannot replace a newer resumed session',
        () async {
      final repository = _FakeStudyRepository()..startGate = Completer<void>();
      final container = ProviderContainer(overrides: [
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(quizSessionProvider.notifier);
      final first = controller.initialize(const QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 10,
      ));
      await controller.initialize(const QuizSessionRequest(
        quizType: 'GRAMMAR',
        jlptLevel: 'N5',
        count: 10,
        resumeSessionId: 'newer-session',
      ));
      repository.startGate!.complete();
      await first;
      expect(container.read(quizSessionProvider).sessionId, 'resume-session');
      expect(container.read(quizSessionProvider).currentIndex, 1);
    });

    test('matching corrections keep the first scored POST and allow exit',
        () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(overrides: [
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(quizSessionProvider.notifier);
      await controller.initialize(const QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 2,
      ));
      controller.submitSpecialAnswer(
        questionId: 'q1',
        isCorrect: false,
        questionType: 'VOCABULARY',
      );
      controller.submitSpecialAnswer(
        questionId: 'q1',
        isCorrect: true,
        questionType: 'VOCABULARY',
      );
      await controller.flushPendingAnswers();
      expect(repository.answerCalls, 1);
      expect(repository.lastSelectedOptionId, 'wrong');
    });

    test('exit drain waits for delayed answer POST to finish', () async {
      final repository = _FakeStudyRepository()..answerGate = Completer<void>();
      final container = ProviderContainer(overrides: [
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(quizSessionProvider.notifier);
      await controller.initialize(const QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 2,
      ));
      controller.answerCurrentQuestion(
          optionId: 'a', questionType: 'VOCABULARY');
      var drained = false;
      final drain =
          controller.flushPendingAnswers().then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(repository.answerCalls, 1);
      expect(drained, isFalse);
      repository.answerGate!.complete();
      await drain;
      expect(drained, isTrue);
    });

    test('failed exit drain retries the same answer before allowing exit',
        () async {
      final repository = _FakeStudyRepository()
        ..answerGate = Completer<void>()
        ..failedAnswerSaves = 1;
      final container = ProviderContainer(overrides: [
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(quizSessionProvider.notifier);
      await controller.initialize(const QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 2,
      ));
      controller.answerCurrentQuestion(
          optionId: 'a', questionType: 'VOCABULARY');
      final drain = controller.flushPendingAnswers();
      final failure = expectLater(drain, throwsA(isA<ApiException>()));
      repository.answerGate!.complete();
      await failure;
      expect(repository.answerCalls, 1);
      await controller.flushPendingAnswers();
      expect(repository.answerCalls, 2);
      expect(repository.lastAnsweredQuestionId, 'q1');
      expect(repository.lastSelectedOptionId, 'a');
    });

    test('initializes a standard quiz session', () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(quizSessionProvider.notifier).initialize(
            const QuizSessionRequest(
              quizType: 'VOCABULARY',
              jlptLevel: 'N5',
              count: 10,
            ),
          );

      final state = container.read(quizSessionProvider);
      expect(repository.startQuizCalls, 1);
      expect(state.loading, isFalse);
      expect(state.sessionId, 'start-session');
      expect(state.questions, hasLength(2));
      expect(state.currentIndex, 0);
      expect(state.effectiveQuizType('VOCABULARY'), 'VOCABULARY');
    });

    test('initializes a resumed quiz session with resolved mode', () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(quizSessionProvider.notifier).initialize(
            const QuizSessionRequest(
              quizType: 'VOCABULARY',
              jlptLevel: 'N5',
              count: 10,
              resumeSessionId: 'resume-1',
            ),
          );

      final state = container.read(quizSessionProvider);
      expect(repository.resumeQuizCalls, 1);
      expect(state.sessionId, 'resume-session');
      expect(state.currentIndex, 1);
      expect(state.resolvedMode, 'matching');
      expect(state.effectiveQuizType('VOCABULARY'), 'MATCHING');
      expect(state.displayQuizType('VOCABULARY'), 'VOCABULARY');
    });

    test('records the current answer and advances to the next question', () {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.state = QuizSessionState(
        loading: false,
        sessionId: 'session-1',
        sessionQuizType: 'VOCABULARY',
        questions: repository.questions,
        timeSpent: 3,
      );

      final isCorrect = notifier.answerCurrentQuestion(
        optionId: 'a',
        questionType: 'VOCABULARY',
      );

      var state = container.read(quizSessionProvider);
      expect(isCorrect, isTrue);
      expect(state.answered, isTrue);
      expect(state.isCorrect, isTrue);
      expect(state.selectedOptionId, 'a');
      expect(state.streak, 1);
      expect(repository.answerCalls, 1);
      expect(repository.lastAnsweredQuestionId, 'q1');
      expect(repository.lastTimeSpent, 3);

      notifier.advanceToNextQuestion();
      state = container.read(quizSessionProvider);
      expect(state.currentIndex, 1);
      expect(state.answered, isFalse);
      expect(state.selectedOptionId, isNull);
      expect(state.timeSpent, 0);
    });

    test('submits special mode answers without mutating default flow state',
        () {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.state = QuizSessionState(
        loading: false,
        sessionId: 'session-1',
        sessionQuizType: 'MATCHING',
        questions: repository.questions,
        resolvedMode: 'matching',
      );

      notifier.submitSpecialAnswer(
        questionId: 'q2',
        isCorrect: false,
        questionType: 'MATCHING',
      );

      final state = container.read(quizSessionProvider);
      expect(state.currentIndex, 0);
      expect(state.answered, isFalse);
      expect(repository.answerCalls, 1);
      expect(repository.lastAnsweredQuestionId, 'q2');
      expect(repository.lastSelectedOptionId, 'wrong');
    });

    test('completes the quiz and returns the result', () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(quizSessionProvider.notifier);
      notifier.state = QuizSessionState(
        loading: false,
        sessionId: 'session-1',
        sessionQuizType: 'VOCABULARY',
        questions: repository.questions,
      );

      final result = await notifier.completeQuiz(stageId: 'stage-1');
      final state = container.read(quizSessionProvider);

      expect(result, isNotNull);
      expect(result!.correctCount, 2);
      expect(repository.completeQuizCalls, 1);
      expect(repository.lastCompletedStageId, 'stage-1');
      expect(state.completing, isFalse);
    });
  });
}

class _FakeStudyRepository extends Fake implements StudyRepository {
  final questions = const [
    QuizQuestionModel(
      questionId: 'q1',
      questionText: 'question-1',
      options: [
        QuizOption(id: 'a', text: 'A'),
        QuizOption(id: 'b', text: 'B'),
      ],
      correctOptionId: 'a',
    ),
    QuizQuestionModel(
      questionId: 'q2',
      questionText: 'question-2',
      options: [
        QuizOption(id: 'c', text: 'C'),
        QuizOption(id: 'd', text: 'D'),
      ],
      correctOptionId: 'c',
    ),
  ];

  int startQuizCalls = 0;
  int failedStarts = 0;
  int failedResumes = 0;
  Completer<void>? startGate;
  final resumedSessionIds = <String>[];
  final wrongReviewSources = <String>[];
  List<String> wrongReviewAnsweredIds = [];
  int failedWrongReviews = 0;
  int resumeQuizCalls = 0;
  int answerCalls = 0;
  Completer<void>? answerGate;
  int failedAnswerSaves = 0;
  int completeQuizCalls = 0;
  String? lastAnsweredQuestionId;
  String? lastSelectedOptionId;
  int? lastTimeSpent;
  String? lastCompletedStageId;

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions, String? mode})>
      startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  }) async {
    startQuizCalls++;
    await startGate?.future;
    if (failedStarts > 0) {
      failedStarts--;
      throw const ApiException(message: 'private details', statusCode: 503);
    }
    return (
      sessionId: 'start-session',
      mode: null,
      questions: questions,
    );
  }

  @override
  Future<
      ({
        String sessionId,
        List<QuizQuestionModel> questions,
        List<String> answeredQuestionIds,
        int correctCount,
        String? quizType,
        String? mode,
      })> resumeQuiz(String sessionId) async {
    resumeQuizCalls++;
    resumedSessionIds.add(sessionId);
    if (failedResumes > 0) {
      failedResumes--;
      throw const ApiException(message: 'private details', statusCode: 503);
    }
    return (
      sessionId: 'resume-session',
      mode: null,
      questions: questions,
      answeredQuestionIds: ['q1'],
      correctCount: 1,
      quizType: 'MATCHING',
    );
  }

  @override
  Future<
      ({
        String sessionId,
        List<QuizQuestionModel> questions,
        List<String> answeredQuestionIds,
        int correctCount,
        String? quizType,
        String? mode,
      })> startWrongAnswerReview(String sourceSessionId) async {
    wrongReviewSources.add(sourceSessionId);
    if (failedWrongReviews > 0) {
      failedWrongReviews--;
      throw const ApiException(message: 'synthetic error', statusCode: 503);
    }
    return (
      sessionId: 'wrong-review-child',
      mode: null,
      questions: [
        ...questions,
        const QuizQuestionModel(
          questionId: 'q3',
          questionText: 'question-3',
          options: [QuizOption(id: 'e', text: 'E')],
          correctOptionId: 'e',
        )
      ],
      answeredQuestionIds: wrongReviewAnsweredIds,
      correctCount: wrongReviewAnsweredIds.toSet().length,
      quizType: 'GRAMMAR',
    );
  }

  @override
  Future<void> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required bool isCorrect,
    required int timeSpentSeconds,
    required String questionType,
  }) async {
    answerCalls++;
    lastAnsweredQuestionId = questionId;
    lastSelectedOptionId = selectedOptionId;
    lastTimeSpent = timeSpentSeconds;
    await answerGate?.future;
    if (failedAnswerSaves > 0) {
      failedAnswerSaves--;
      throw TimeoutException('Synthetic answer write failure');
    }
  }

  @override
  Future<QuizResultModel> completeQuiz(
    String sessionId, {
    String? stageId,
  }) async {
    completeQuizCalls++;
    lastCompletedStageId = stageId;
    return const QuizResultModel(
      correctCount: 2,
      totalQuestions: 2,
      xpEarned: 10,
      accuracy: 100,
      currentXp: 20,
      xpForNext: 100,
      level: 1,
      events: [],
    );
  }
}
