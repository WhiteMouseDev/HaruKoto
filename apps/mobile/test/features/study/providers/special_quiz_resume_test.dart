import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';
import 'package:harukoto_mobile/features/study/domain/quiz_resume_exception.dart';
import 'package:harukoto_mobile/features/study/presentation/study_entry_flow.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_page_content.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/sentence_arrange_quiz.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  for (final category in ['VOCABULARY', 'SENTENCE']) {
    test('fresh arrange normalizes $category to the canonical API category',
        () async {
      final fixture = _Fixture({
        'sessionId': 'same-session',
        'mode': 'arrange',
        'questions': [_arrange('a1')],
        'totalQuestions': 1,
      });
      addTearDown(fixture.dispose);
      await fixture.controller.initialize(QuizSessionRequest(
        quizType: category,
        jlptLevel: 'N5',
        count: 4,
        mode: 'arrange',
      ));
      expect(fixture.state.loadError, isNull);
      expect(fixture.state.sessionQuizType, 'SENTENCE_ARRANGE');
      expect(fixture.state.resolvedMode, 'arrange');
      final request = fixture.requests.single;
      expect(request.path, '/quiz/start');
      expect((request.data as Map<String, dynamic>)['quizType'],
          'SENTENCE_ARRANGE');
    });
  }
  test('VOCABULARY matching uses server mode and canonical pair bindings',
      () async {
    final fixture = _Fixture(_matching());
    addTearDown(fixture.dispose);
    await fixture.resume(fallbackMode: 'arrange');
    final state = fixture.state;
    expect(state.loadError, isNull);
    expect(state.sessionQuizType, 'VOCABULARY');
    expect(state.resolvedMode, 'matching');
    expect(state.questions.map((q) => q.questionId),
        ['q2', 'q4', 'q1', 'q3', 'q5']);
    expect(
        state.unansweredQuestions.map((q) => q.questionId), ['q1', 'q3', 'q5']);
    expect(state.currentQuestion!.matchingWord, '言葉1');
    expect(state.currentQuestion!.matchingMeaning, '뜻1');
    expect(state.currentQuestion!.correctOptionId, 'pair1');
    expect(state.headerCount, '2/5 저장');
    expect(fixture.requests.single.path, '/quiz/resume');
  });

  test('matching progress waits for durable save and keeps first wrong answer',
      () async {
    final fixture = _Fixture(_matching());
    addTearDown(fixture.dispose);
    await fixture.resume();
    fixture.answerGate = Completer<void>();
    fixture.controller.submitSpecialAnswer(
        questionId: 'q3', isCorrect: false, questionType: 'VOCABULARY');
    fixture.controller.submitSpecialAnswer(
        questionId: 'q3', isCorrect: true, questionType: 'VOCABULARY');
    expect(fixture.state.headerCount, '2/5 저장');
    fixture.answerGate!.complete();
    await fixture.controller.flushPendingAnswers();
    expect(fixture.state.headerCount, '3/5 저장');
    final writes = fixture.requests.where((r) => r.path == '/quiz/answer');
    expect(writes, hasLength(1));
    final body = writes.single.data as Map<String, dynamic>;
    expect(body['questionId'], 'q3');
    expect(body['selectedOptionId'], 'wrong');
    expect(body['questionType'], 'VOCABULARY');
    // Updating the acknowledgement must not shrink or reorder the active board.
    expect(fixture.state.unansweredQuestions.map((q) => q.questionId),
        ['q1', 'q3', 'q5']);
    fixture.controller.submitSpecialAnswer(
        questionId: 'q2', isCorrect: true, questionType: 'VOCABULARY');
    await fixture.controller.flushPendingAnswers();
    expect(
        fixture.requests.where((r) => r.path == '/quiz/answer'), hasLength(1));
  });

  test('resume with one matching pair left keeps it playable', () async {
    final fixture = _Fixture(_matching(answered: ['q1', 'q2', 'q3', 'q4']));
    addTearDown(fixture.dispose);
    await fixture.resume();
    expect(fixture.state.headerCount, '4/5 저장');
    expect(fixture.state.unansweredQuestions.single.questionId, 'q5');
    fixture.controller.submitSpecialAnswer(
        questionId: 'q5', isCorrect: true, questionType: 'VOCABULARY');
    await fixture.controller.flushPendingAnswers();
    expect(fixture.state.headerCount, '5/5 저장');
  });

  test('all saved matching answers expose result path without new answers',
      () async {
    final fixture =
        _Fixture(_matching(answered: ['q5', 'q2', 'q1', 'q3', 'q4']));
    addTearDown(fixture.dispose);
    await fixture.resume();
    expect(fixture.state.currentQuestion, isNull);
    expect(fixture.state.unansweredQuestions, isEmpty);
    expect(fixture.state.headerCount, '5/5 저장');
    expect(fixture.requests.map((r) => r.path), ['/quiz/resume']);
  });

  test('arrange restores original tokens and skips a saved wrong question',
      () async {
    final fixture = _Fixture({
      'sessionId': 'same-session',
      'quizType': 'SENTENCE_ARRANGE',
      'mode': 'arrange',
      'questions': [_arrange('a1'), _arrange('a2'), _arrange('a3')],
      'answeredQuestionIds': ['a1'],
      'totalQuestions': 3,
      'correctCount': 0,
    });
    addTearDown(fixture.dispose);
    await fixture.resume();
    expect(fixture.state.resolvedMode, 'arrange');
    expect(fixture.state.currentQuestion!.questionId, 'a2');
    expect(fixture.state.currentQuestion!.tokens, ['私', 'は', '学生', 'です']);
    expect(fixture.state.currentQuestion!.japaneseSentence, '私は学生です');
    expect(fixture.state.headerCount, '1/3 저장');
  });

  for (final payload in [
    {..._matching(), 'mode': 'future_unknown_mode'},
    {..._matching(), 'mode': null, 'matchingPairs': null},
    {
      ..._matching(),
      'answeredQuestionIds': ['foreign-question']
    },
    {..._matching(), 'matchingPairs': []},
    {..._matching(), 'totalQuestions': 7},
    {
      ..._matching(),
      'questions': <Object>[],
      'answeredQuestionIds': <String>[],
      'totalQuestions': 0
    },
  ]) {
    test(
        'unsafe special response is permanent and never starts another quiz: '
        '${payload['mode']}/${payload['answeredQuestionIds']}', () async {
      final fixture = _Fixture(payload);
      addTearDown(fixture.dispose);
      await fixture.resume();
      expect(fixture.state.loadError, contains('학습 기록은 유지'));
      expect(fixture.state.loadErrorCanRetry, isFalse);
      expect(fixture.state.questions, isEmpty);
      expect(fixture.requests.map((r) => r.path), ['/quiz/resume']);
    });
  }

  test('old server valid multiple-choice response remains usable', () async {
    final fixture = _Fixture({
      'sessionId': 'same-session',
      'quizType': 'VOCABULARY',
      'questions': [
        {
          'questionId': 'q1',
          'questionText': '猫',
          'options': [
            {'id': 'one', 'text': '고양이'}
          ],
          'correctOptionId': 'one',
        }
      ],
      'answeredQuestionIds': [],
      'totalQuestions': 1,
      'correctCount': 0,
    });
    addTearDown(fixture.dispose);
    await fixture.resume();
    expect(fixture.state.loadError, isNull);
    expect(fixture.state.isSpecialMode, isFalse);
    expect(fixture.state.currentQuestion!.questionText, '猫');
  });

  for (final envelope in [
    {'detail': '이 퀴즈는 이전 형식으로 저장되어 이어서 불러올 수 없어요. 저장된 학습 기록은 유지됩니다.'},
    {
      'error': {
        'code': 'SYSTEM_ERROR',
        'message': '퀴즈의 저장 정보를 안전하게 불러올 수 없어요. 저장된 학습 기록은 유지됩니다.'
      }
    },
    {'detail': 'private diagnostic not for the learner'},
  ]) {
    test(
        '409 resume error is scoped and does not expose diagnostics: $envelope',
        () async {
      final fixture = _Fixture(envelope, status: 409);
      addTearDown(fixture.dispose);
      await fixture.resume();
      expect(fixture.state.loadErrorCanRetry, isFalse);
      expect(fixture.state.loadError, contains('학습 기록은 유지'));
      expect(fixture.state.loadError, isNot(contains('private diagnostic')));
      expect(
          const ApiException(message: 'another endpoint', statusCode: 409)
              .userMessage,
          '이미 처리된 요청입니다.');
    });
  }

  test('temporary resume failure can retry only the same session', () async {
    final fixture = _Fixture(_matching(), status: 503);
    addTearDown(fixture.dispose);
    await fixture.resume();
    expect(fixture.state.loadErrorCanRetry, isTrue);
    fixture.status = 200;
    await fixture.resume();
    expect(fixture.state.loadError, isNull);
    expect(
        fixture.requests.map((r) => r.path), ['/quiz/resume', '/quiz/resume']);
    expect(
        fixture.requests
            .map((r) => (r.data as Map<String, dynamic>)['sessionId']),
        ['same-session', 'same-session']);
  });

  test('incomplete status preserves old server support and rejects unknowns',
      () {
    for (final status in [
      null,
      'available',
      'legacy_unavailable',
      'invalid_snapshot',
      'future'
    ]) {
      final session = _incomplete(status);
      expect(session.canResume, status == null || status == 'available');
      expect(session.mode, 'arrange');
    }
    expect(
        resolveStudyEntryDecision(
                category: 'SENTENCE_ARRANGE', hasIncomplete: true)
            .action,
        StudyEntryActionKind.resumeOrNew);
  });

  testWidgets('unavailable sheet offers return without retry or new start',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showResumeOrNewStudySheet(context,
                        session: _incomplete('legacy_unavailable'),
                        selectedCategory: 'SENTENCE_ARRANGE',
                        jlptLevel: 'N5'),
                    child: const Text('이어서 열기'))))));
    await tester.tap(find.text('이어서 열기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('이전 형식'), findsOneWidget);
    expect(find.text('새로 시작하기'), findsNothing);
    expect(find.text('다시 불러오기'), findsNothing);
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
  });

  testWidgets('permanent load failure hides retry and new-start uncertainty',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: QuizPageContent(
      session: QuizSessionState(
          loading: false,
          loadError: const QuizResumeException().userMessage,
          loadErrorCanRetry: false),
      quizType: 'VOCABULARY',
      jlptLevel: 'N5',
      onBackRequested: () {},
      onExit: () {},
      onAnswer: (_) {},
      onNext: () {},
      onComplete: () {},
      onRetryLoad: () => fail('Permanent errors must not retry'),
      onSubmitSpecialAnswer: (_, __, ___, {optionId}) {},
    ))));
    expect(find.text('다시 불러오기'), findsNothing);
    expect(find.textContaining('퀴즈가 준비되었지만'), findsNothing);
    expect(find.text('학습으로 돌아가기'), findsOneWidget);
  });

  testWidgets('arrange uses original total after a partial resume',
      (tester) async {
    final fixture = _Fixture({
      'sessionId': 'same-session',
      'quizType': 'SENTENCE_ARRANGE',
      'mode': 'arrange',
      'questions': [_arrange('a1'), _arrange('a2'), _arrange('a3')],
      'answeredQuestionIds': ['a1'],
      'totalQuestions': 3,
      'correctCount': 0,
    });
    addTearDown(fixture.dispose);
    await tester.runAsync(() => fixture.resume());
    await tester.pumpWidget(UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
            home: Scaffold(
                body: SentenceArrangeQuiz(
          questions: fixture.state.unansweredQuestions,
          initialAnsweredCount: fixture.state.currentIndex,
          totalQuestions: 3,
          onAnswer: (_, __) {},
          onComplete: () {},
        )))));
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('1/2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('acknowledgement updates header without resetting matching board',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = _Fixture(_matching(), prefs: prefs);
    addTearDown(fixture.dispose);
    await tester.runAsync(() => fixture.resume());
    await tester.pumpWidget(UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(home: Consumer(builder: (context, ref, child) {
        return QuizPageContent(
          session: ref.watch(quizSessionProvider),
          quizType: 'VOCABULARY',
          jlptLevel: 'N5',
          onBackRequested: () {},
          onExit: () {},
          onAnswer: (_) {},
          onNext: () {},
          onComplete: () {},
          onSubmitSpecialAnswer: (id, correct, type, {optionId}) =>
              fixture.controller.submitSpecialAnswer(
                  questionId: id,
                  isCorrect: correct,
                  questionType: type,
                  optionId: optionId),
        );
      })),
    ));
    expect(find.text('言葉2'), findsNothing);
    expect(find.text('言葉4'), findsNothing);
    await tester.tap(find.text('言葉1'));
    await tester.tap(find.text('뜻1'));
    await tester.pumpAndSettle();
    expect(find.text('言葉1'), findsNothing);
    expect(find.text('言葉3'), findsOneWidget);
    expect(find.text('3/5 저장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _matching({List<String> answered = const ['q2', 'q4']}) =>
    {
      'sessionId': 'same-session',
      'quizType': 'VOCABULARY',
      'mode': 'matching',
      'totalQuestions': 5,
      'correctCount': 1,
      'answeredQuestionIds': answered,
      'questions': [
        for (var i = 1; i <= 5; i++)
          {
            'questionId': 'q$i',
            'questionText': '言葉$i',
            'questionSubText': 'ことば',
            'options': [],
            'correctOptionId': 'pair$i',
          }
      ],
      'matchingPairs': [
        for (var i = 1; i <= 5; i++)
          {
            'id': 'pair$i',
            'word': '言葉$i',
            'meaning': '뜻$i',
          }
      ],
    };

Map<String, dynamic> _arrange(String id) => {
      'questionId': id,
      'questionText': '저는 학생입니다',
      'options': [],
      'correctOptionId': '',
      'japaneseSentence': '私は学生です',
      'tokens': ['私', 'は', '学生', 'です'],
    };

IncompleteSessionModel _incomplete(String? status) => IncompleteSessionModel(
      id: 'same-session',
      quizType: 'SENTENCE_ARRANGE',
      jlptLevel: 'N5',
      totalQuestions: 4,
      answeredCount: 1,
      correctCount: 0,
      startedAt: '2026-10-30',
      mode: 'arrange',
      resumeStatus: status,
    );

class _Fixture {
  _Fixture(this.payload, {this.status = 200, SharedPreferences? prefs}) {
    dio = Dio();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      requests.add(options);
      if (options.path == '/quiz/answer') {
        await answerGate?.future;
        handler.resolve(
            Response(requestOptions: options, data: {'success': true}));
      } else if (options.path == '/quiz/resume' ||
          options.path == '/quiz/start') {
        if (status == 200) {
          handler.resolve(Response(requestOptions: options, data: payload));
        } else {
          handler.reject(DioException(
              requestOptions: options,
              response: Response(
                  requestOptions: options, data: payload, statusCode: status),
              type: DioExceptionType.badResponse,
              error: ApiException.fromResponse(status, payload,
                  requestPath: options.path)));
        }
      } else {
        fail('Unexpected request ${options.path}');
      }
    }));
    container = ProviderContainer(overrides: [
      studyRepositoryProvider.overrideWithValue(ApiStudyRepository(dio)),
      if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
  }
  final Map<String, dynamic> payload;
  int status;
  late final Dio dio;
  late final ProviderContainer container;
  final requests = <RequestOptions>[];
  Completer<void>? answerGate;
  QuizSessionState get state => container.read(quizSessionProvider);
  QuizSessionController get controller =>
      container.read(quizSessionProvider.notifier);
  Future<void> resume({String? fallbackMode}) =>
      controller.initialize(QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 5,
        mode: fallbackMode,
        resumeSessionId: 'same-session',
      ));
  void dispose() {
    container.dispose();
    dio.close();
  }
}
