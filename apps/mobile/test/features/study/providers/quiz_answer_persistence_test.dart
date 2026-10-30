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
  for (final mode in [null, 'smart']) {
    test('ten correct answers wait for saves before scoring in $mode mode',
        () async {
      final repository = _SavingRepository()..firstSave = Completer<void>();
      final container = _container(repository);
      final controller = await _initialize(container, mode: mode);
      expect(repository.smartStarts, mode == 'smart' ? 1 : 0);
      expect(repository.starts, mode == 'smart' ? 0 : 1);
      expect(controller.state.resolvedMode, mode);
      expect(controller.state.sessionQuizType, 'VOCABULARY');
      if (mode == 'smart') {
        expect(repository.smartRequest,
            (category: 'VOCABULARY', jlptLevel: 'N5', count: 10));
      }

      _answerAll(controller);
      final completion = controller.completeQuiz();
      await _flush();
      expect(controller.state.streak, 10);
      expect(repository.attempts, {for (var i = 0; i < 10; i++) 'q$i': 1});
      expect(repository.completeCalls, 0);
      expect(controller.state.completing, isTrue);
      expect(await controller.completeQuiz(), isNull);

      repository.firstSave!.complete();
      final result = await completion;
      expect(result!.correctCount, 10);
      expect(result.accuracy, 100);
      expect(result.xpEarned, 100);
      expect(repository.maxConcurrentSaves, greaterThan(1));
      expect(repository.completeCalls, 1);
      expect(controller.state.completing, isFalse);
    });
  }

  for (final responseLost in [false, true]) {
    test(
        'failed answer blocks results and retries safely (responseLost=$responseLost)',
        () async {
      final repository = _SavingRepository()
        ..firstSave = Completer<void>()
        ..failFirstSave = true
        ..commitBeforeFailure = responseLost;
      final controller = await _initialize(_container(repository));
      _answerAll(controller);
      final completion = controller.completeQuiz();
      final failure = expectLater(completion, throwsA(isA<ApiException>()));
      await _flush();
      repository.firstSave!.complete();
      await failure;

      expect(repository.completeCalls, 0);
      expect(controller.state.completing, isFalse);
      expect(controller.state.completionError, isNotNull);
      expect(repository.saved.length, responseLost ? 10 : 9);

      final result = await controller.completeQuiz();
      expect(result!.correctCount, 10);
      expect(result.xpEarned, 100);
      expect(repository.attempts['q0'], 2);
      expect(repository.attempts.values.where((count) => count == 1),
          hasLength(9));
      expect(repository.saved, hasLength(10));
      expect(controller.state.completionError, isNull);
    });
  }

  test('matching retries keep the first scored attempt and await every save',
      () async {
    final repository = _SavingRepository()..firstSave = Completer<void>();
    final controller = await _initialize(_container(repository));
    for (final question in controller.state.questions) {
      controller.submitSpecialAnswer(
          questionId: question.questionId,
          isCorrect: false,
          questionType: 'VOCABULARY');
      controller.submitSpecialAnswer(
          questionId: question.questionId,
          isCorrect: true,
          questionType: 'VOCABULARY');
    }
    final completion = controller.completeQuiz();
    await _flush();
    expect(repository.completeCalls, 0);
    repository.firstSave!.complete();
    final result = await completion;
    expect(result!.correctCount, 0);
    expect(repository.saved, hasLength(10));
    expect(repository.saved.values.toSet(), {'wrong'});
    expect(repository.attempts.values.toSet(), {1});
  });

  test('completion failure retries only completion, preserving saved answers',
      () async {
    final repository = _SavingRepository()..failFirstCompletion = true;
    final controller = await _initialize(_container(repository));
    _answerAll(controller);
    await expectLater(controller.completeQuiz(), throwsA(isA<StateError>()));
    expect(controller.state.completionError, isNotNull);
    final result = await controller.completeQuiz();
    expect(result!.correctCount, 10);
    expect(repository.completeCalls, 2);
    expect(repository.attempts.values.toSet(), {1});
  });

  test('old answer callbacks cannot complete or overwrite a new session',
      () async {
    final repository = _SavingRepository()..firstSave = Completer<void>();
    final controller = await _initialize(_container(repository));
    _answerAll(controller);
    final oldCompletion = controller.completeQuiz();
    await _flush();

    await controller.initialize(_request);
    expect(controller.state.sessionId, 'session-2');
    repository.firstSave!.complete();
    expect(await oldCompletion, isNull);
    expect(controller.state.sessionId, 'session-2');
    expect(controller.state.answered, isFalse);
    expect(controller.state.completionError, isNull);
    expect(repository.completeCalls, 0);
    expect(repository.attempts, {for (var i = 0; i < 10; i++) 'q$i': 1});
  });

  test('an in-flight old completion cannot return a result for a new session',
      () async {
    final repository = _SavingRepository()..completionGate = Completer<void>();
    final controller = await _initialize(_container(repository));
    _answerAll(controller);
    final oldCompletion = controller.completeQuiz();
    await _flush();
    expect(repository.completeCalls, 1);
    await controller.initialize(_request);
    repository.completionGate!.complete();
    expect(await oldCompletion, isNull);
    expect(controller.state.sessionId, 'session-2');
    expect(controller.state.completing, isFalse);
  });

  test(
      'resume skips saved IDs rather than dropping a prefix with unsaved answers',
      () async {
    final repository = _SavingRepository()..saved['q4'] = 'right-q4';
    final controller =
        _container(repository).read(quizSessionProvider.notifier);
    await controller.initialize(const QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 10,
        resumeSessionId: 'resume'));
    expect(controller.state.currentIndex, 1);
    expect(controller.state.currentQuestion!.questionId, 'q0');
    expect(
        controller.state.unansweredQuestions
            .map((question) => question.questionId),
        isNot(contains('q4')));
    _answerAll(controller);
    final result = await controller.completeQuiz();
    expect(result!.correctCount, 10);
    expect(repository.attempts.containsKey('q4'), isFalse);
  });
}

const _request =
    QuizSessionRequest(quizType: 'VOCABULARY', jlptLevel: 'N5', count: 10);

ProviderContainer _container(_SavingRepository repository) {
  final container = ProviderContainer(
      overrides: [studyRepositoryProvider.overrideWithValue(repository)]);
  addTearDown(container.dispose);
  return container;
}

Future<QuizSessionController> _initialize(ProviderContainer container,
    {String? mode}) async {
  final controller = container.read(quizSessionProvider.notifier);
  await controller.initialize(QuizSessionRequest(
      quizType: 'VOCABULARY', jlptLevel: 'N5', count: 10, mode: mode));
  return controller;
}

void _answerAll(QuizSessionController controller) {
  while (true) {
    expect(
        controller.answerCurrentQuestion(
            optionId: controller.state.currentQuestion!.correctOptionId,
            questionType: 'VOCABULARY'),
        isTrue);
    if (controller.state.isLastQuestion) break;
    controller.advanceToNextQuestion();
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _SavingRepository extends Fake implements StudyRepository {
  final questions = List.generate(
      10,
      (i) => QuizQuestionModel(
          questionId: 'q$i',
          questionText: '단어 $i',
          options: [QuizOption(id: 'right-q$i', text: '정답 $i')],
          correctOptionId: 'right-q$i'));
  final attempts = <String, int>{};
  final saved = <String, String>{};
  Completer<void>? firstSave;
  Completer<void>? completionGate;
  bool failFirstSave = false;
  bool commitBeforeFailure = false;
  bool failFirstCompletion = false;
  int starts = 0;
  int smartStarts = 0;
  ({String category, String jlptLevel, int count})? smartRequest;
  int completeCalls = 0;
  int activeSaves = 0;
  int maxConcurrentSaves = 0;

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions, String? mode})>
      startQuiz(
              {required String quizType,
              required String jlptLevel,
              required int count,
              String? mode,
              String? stageId}) async =>
          (sessionId: 'session-${++starts}', questions: questions, mode: null);

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions, String? mode})>
      startSmartQuiz({
    String category = 'VOCABULARY',
    String jlptLevel = 'N5',
    int count = 20,
  }) async {
    smartStarts++;
    smartRequest = (category: category, jlptLevel: jlptLevel, count: count);
    return (sessionId: 'smart-session', questions: questions, mode: null);
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
      })> resumeQuiz(String sessionId) async => (
        sessionId: sessionId,
        mode: null,
        questions: questions,
        answeredQuestionIds: saved.keys.toList(),
        correctCount: saved.length,
        quizType: 'VOCABULARY'
      );

  @override
  Future<void> answerQuestion(
      {required String sessionId,
      required String questionId,
      required String selectedOptionId,
      required bool isCorrect,
      required int timeSpentSeconds,
      required String questionType}) async {
    final attempt =
        attempts.update(questionId, (count) => count + 1, ifAbsent: () => 1);
    activeSaves++;
    if (activeSaves > maxConcurrentSaves) maxConcurrentSaves = activeSaves;
    try {
      if (questionId == 'q0' && attempt == 1) {
        await firstSave?.future;
        if (failFirstSave) {
          if (commitBeforeFailure) {
            saved.putIfAbsent(questionId, () => selectedOptionId);
          }
          throw TimeoutException('Synthetic failed answer response');
        }
      }
      saved.putIfAbsent(questionId, () => selectedOptionId);
    } finally {
      activeSaves--;
    }
  }

  @override
  Future<QuizResultModel> completeQuiz(String sessionId,
      {String? stageId}) async {
    completeCalls++;
    await completionGate?.future;
    if (failFirstCompletion && completeCalls == 1) {
      throw StateError('Synthetic completion failure');
    }
    final correct = saved.entries
        .where((entry) => entry.value == 'right-${entry.key}')
        .length;
    return QuizResultModel(
        correctCount: correct,
        totalQuestions: 10,
        xpEarned: correct * 10,
        accuracy: correct * 10,
        currentXp: correct * 10,
        xpForNext: 100,
        level: 1,
        events: const []);
  }
}
