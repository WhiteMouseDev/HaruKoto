import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/home/providers/study_activity_refresh_provider.dart';
import 'package:harukoto_mobile/features/kana/data/kana_repository.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_completion_service.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

import '../fixtures/lesson_activity_fixture.dart';

void main() {
  for (final mode in [null, 'matching', 'arrange']) {
    test(
        'one $mode answer refreshes only after save, without completing session',
        () async {
      final repository = _QuizRepository()..gate = Completer<void>();
      var refreshes = 0;
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue(activityOwner),
        currentAccountReaderProvider.overrideWithValue(() => activityOwner),
        studyRepositoryProvider.overrideWithValue(repository),
        studyActivityRefreshProvider
            .overrideWith((ref) => _Refresh(ref, () => refreshes++)),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(quizSessionProvider.notifier);
      await controller.initialize(QuizSessionRequest(
          quizType: 'VOCABULARY', jlptLevel: 'N5', count: 2, mode: mode));
      expect(controller.state.loadError, isNull);
      expect(controller.state.sessionId, 'session');
      if (mode == null) {
        controller.answerCurrentQuestion(
            optionId: 'wrong', questionType: 'VOCABULARY');
      } else {
        controller.submitSpecialAnswer(
            questionId: 'q0',
            isCorrect: false,
            questionType:
                mode == 'arrange' ? 'SENTENCE_ARRANGE' : 'VOCABULARY');
      }
      await activityFlush();
      expect(refreshes, 0);
      expect(repository.completeCalls, 0);
      repository.gate!.complete();
      await controller.flushPendingAnswers();
      expect(refreshes, 1);
      expect(repository.savedQuestions, ['q0']);
      expect(repository.completeCalls, 0);
    });
  }

  test(
      'failed answer and late success from previous account do not refresh current day',
      () async {
    final repository = _QuizRepository()..gate = Completer<void>();
    var owner = activityOwner;
    var refreshes = 0;
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => owner),
      currentAccountReaderProvider.overrideWithValue(() => owner),
      studyRepositoryProvider.overrideWithValue(repository),
      studyActivityRefreshProvider
          .overrideWith((ref) => _Refresh(ref, () => refreshes++)),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(quizSessionProvider.notifier);
    await controller.initialize(const QuizSessionRequest(
        quizType: 'VOCABULARY', jlptLevel: 'N5', count: 2));
    expect(controller.state.loadError, isNull);
    controller.answerCurrentQuestion(
        optionId: 'wrong', questionType: 'VOCABULARY');
    await activityFlush();
    owner = activityOtherOwner;
    container.invalidate(currentAccountIdProvider);
    repository.gate!.complete();
    await controller.flushPendingAnswers();
    expect(refreshes, 0);
    expect(repository.completeCalls, 0);
  });

  for (final fail in [false, true]) {
    test('kana per-answer ACK refreshes before completion (failure=$fail)',
        () async {
      final repository = _KanaRepository()..fail = fail;
      var refreshes = 0;
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue(activityOwner),
        currentAccountReaderProvider.overrideWithValue(() => activityOwner),
        kanaRepositoryProvider.overrideWithValue(repository),
        studyActivityRefreshProvider
            .overrideWith((ref) => _Refresh(ref, () => refreshes++)),
      ]);
      addTearDown(container.dispose);
      final saving = container
          .read(kanaCompletionServiceProvider)
          .answerQuestion(
              sessionId: 'kana-session',
              questionId: 'kana-q',
              selectedOptionId: 'wrong');
      if (fail) {
        await expectLater(saving, throwsStateError);
        expect(refreshes, 0);
      } else {
        expect((await saving).isCorrect, isFalse);
        expect(refreshes, 1);
      }
      expect(repository.answers, 1);
    });
  }
}

class _Refresh extends StudyActivityRefresh {
  _Refresh(super.ref, this.callback);
  final void Function() callback;
  @override
  void refresh() => callback();
}

class _QuizRepository extends Fake implements StudyRepository {
  Completer<void>? gate;
  final savedQuestions = <String>[];
  int completeCalls = 0;

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions, String? mode})>
      startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  }) async =>
          (
            sessionId: 'session',
            mode: mode,
            questions: [
              for (var i = 0; i < 2; i++)
                QuizQuestionModel(
                    questionId: 'q$i',
                    questionText: '단어 $i',
                    correctOptionId: 'right',
                    options: const [
                      QuizOption(id: 'right', text: '정답'),
                      QuizOption(id: 'wrong', text: '오답'),
                    ],
                    matchingWord: '単語$i',
                    matchingMeaning: '단어$i',
                    japaneseSentence: '私です',
                    tokens: const ['私', 'です']),
            ]
          );

  @override
  Future<void> answerQuestion(
      {required String sessionId,
      required String questionId,
      required String selectedOptionId,
      required bool isCorrect,
      required int timeSpentSeconds,
      required String questionType}) async {
    if (gate != null) await gate!.future;
    savedQuestions.add(questionId);
  }

  @override
  Future<QuizResultModel> completeQuiz(String sessionId,
      {String? stageId}) async {
    completeCalls++;
    throw StateError('A single answer must not complete this quiz');
  }
}

class _KanaRepository extends Fake implements KanaRepository {
  bool fail = false;
  int answers = 0;
  @override
  Future<({bool isCorrect, String correctOptionId})> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    answers++;
    if (fail) throw StateError('save failed');
    return (isCorrect: false, correctOptionId: 'right');
  }
}
