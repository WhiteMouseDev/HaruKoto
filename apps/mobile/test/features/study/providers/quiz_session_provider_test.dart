import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('QuizSessionController', () {
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

class _FakeStudyRepository extends StudyRepository {
  _FakeStudyRepository() : super(Dio());

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
  int resumeQuizCalls = 0;
  int answerCalls = 0;
  int completeQuizCalls = 0;
  String? lastAnsweredQuestionId;
  String? lastSelectedOptionId;
  int? lastTimeSpent;
  String? lastCompletedStageId;

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions})> startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  }) async {
    startQuizCalls++;
    return (
      sessionId: 'start-session',
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
      })> resumeQuiz(String sessionId) async {
    resumeQuizCalls++;
    return (
      sessionId: 'resume-session',
      questions: questions,
      answeredQuestionIds: ['q0'],
      correctCount: 1,
      quizType: 'MATCHING',
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
