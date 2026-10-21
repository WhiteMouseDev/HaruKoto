import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_result_page.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('QuizResultPage', () {
    testWidgets('malformed wrong-answer content is visible as an error',
        (tester) async {
      final repository = _FakeStudyRepository()..loadError = TypeError();
      await _pumpResult(tester, repository);
      expect(find.text('오답을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 불러오기'), findsOneWidget);
      expect(find.text('이번 퀴즈에는 오답이 없어요'), findsNothing);
      expect(find.text('오답 복습 →'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('loading wrong answers is visible and cannot launch review',
        (tester) async {
      final repository = _FakeStudyRepository()
        ..gate = Completer<List<WrongAnswerModel>>();
      var reviews = 0;
      await _pumpResult(tester, repository,
          reviewLauncher: (_) async => reviews++);
      expect(find.text('이번 퀴즈의 오답을 불러오고 있어요'), findsOneWidget);
      expect(find.text('오답 복습 →'), findsNothing);
      expect(reviews, 0);
      repository.gate!.complete(repository.answers);
      await tester.pump();
      await tester.pump();
      expect(find.text('틀린 단어 1개'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('GET error shows retry and reloads only the original session',
        (tester) async {
      final repository = _FakeStudyRepository()..failedLoads = 1;
      var reviews = 0;
      await _pumpResult(tester, repository,
          reviewLauncher: (_) async => reviews++);
      expect(find.text('오답을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('로그인이 필요합니다.'), findsOneWidget);
      expect(find.text('이번 퀴즈에는 오답이 없어요'), findsNothing);
      expect(find.text('오답 복습 →'), findsNothing);
      expect(reviews, 0);
      await tester.ensureVisible(find.text('다시 불러오기'));
      await tester.tap(find.text('다시 불러오기'));
      await tester.pump();
      await tester.pump();
      expect(repository.sessionIds, ['session-1', 'session-1']);
      expect(find.text('틀린 단어 1개'), findsOneWidget);
      expect(find.text('오답을 불러오지 못했어요'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('all-correct result has a genuine no-wrong-answers state',
        (tester) async {
      final repository = _FakeStudyRepository();
      await _pumpResult(tester, repository, correctCount: 10);
      expect(find.text('이번 퀴즈에는 오답이 없어요'), findsOneWidget);
      expect(find.text('오답 복습 →'), findsNothing);
      expect(find.text('다시 불러오기'), findsNothing);
      expect(repository.fetchWrongAnswersCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets(
        'unexpected empty list offers retry without claiming all correct',
        (tester) async {
      final repository = _FakeStudyRepository()..answers = const [];
      await _pumpResult(tester, repository);
      expect(find.text('표시할 오답이 없어요'), findsOneWidget);
      expect(find.text('이번 퀴즈에는 오답이 없어요'), findsNothing);
      expect(find.text('다시 불러오기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('review recommendation launches the review flow',
        (tester) async {
      final repository = _FakeStudyRepository();
      await _prepareViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyRepositoryProvider.overrideWith((ref) => repository),
          ],
          child: MaterialApp(
            home: QuizResultPage(
              result: _buildResult(correctCount: 6, totalQuestions: 10),
              quizType: 'VOCABULARY',
              jlptLevel: 'N4',
              sessionId: 'session-1',
              reviewLauncher: (context) {
                return Navigator.of(context).pushReplacement<void, void>(
                  PageRouteBuilder<void>(
                    pageBuilder: (_, __, ___) => const Scaffold(
                      body: Center(
                        child: Text('review-route'),
                      ),
                    ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(repository.fetchWrongAnswersCalls, 1);
      expect(find.text('오답 복습 →'), findsOneWidget);

      await tester.ensureVisible(find.text('오답 복습 →'));
      await tester.tap(find.text('오답 복습 →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('review-route'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('retry button launches the retry flow', (tester) async {
      final repository = _FakeStudyRepository();
      await _prepareViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyRepositoryProvider.overrideWith((ref) => repository),
          ],
          child: MaterialApp(
            home: QuizResultPage(
              result: _buildResult(correctCount: 10, totalQuestions: 10),
              quizType: 'GRAMMAR',
              jlptLevel: 'N3',
              sessionId: 'session-2',
              retryLauncher: (context) {
                return Navigator.of(context).pushReplacement<void, void>(
                  PageRouteBuilder<void>(
                    pageBuilder: (_, __, ___) => const Scaffold(
                      body: Center(
                        child: Text('retry-route'),
                      ),
                    ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('한 번 더 도전'), findsOneWidget);

      await tester.ensureVisible(find.text('한 번 더 도전'));
      await tester.tap(find.text('한 번 더 도전'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('retry-route'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}

Future<void> _pumpResult(WidgetTester tester, _FakeStudyRepository repository,
    {int correctCount = 6, QuizResultLaunch? reviewLauncher}) async {
  await _prepareViewport(tester);
  final container = ProviderContainer(overrides: [
    studyRepositoryProvider.overrideWithValue(repository),
  ]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
        home: QuizResultPage(
      result: _buildResult(correctCount: correctCount, totalQuestions: 10),
      quizType: 'VOCABULARY',
      jlptLevel: 'N5',
      sessionId: 'session-1',
      reviewLauncher: reviewLauncher,
    )),
  ));
  await tester.pump();
  await tester.pump();
}

class _FakeStudyRepository extends Fake implements StudyRepository {
  int fetchWrongAnswersCalls = 0;
  int failedLoads = 0;
  Object? loadError;
  Completer<List<WrongAnswerModel>>? gate;
  final sessionIds = <String>[];
  List<WrongAnswerModel> answers = const [
    WrongAnswerModel(questionId: 'q1', word: '学校', meaningKo: '학교'),
  ];

  @override
  Future<List<WrongAnswerModel>> fetchWrongAnswersBySession(
    String sessionId,
  ) async {
    fetchWrongAnswersCalls++;
    sessionIds.add(sessionId);
    if (loadError != null) throw loadError!;
    if (failedLoads > 0) {
      failedLoads--;
      throw const ApiException(message: 'private details', statusCode: 401);
    }
    return gate == null ? answers : gate!.future;
  }
}

QuizResultModel _buildResult({
  required int correctCount,
  required int totalQuestions,
}) {
  final accuracy =
      totalQuestions == 0 ? 0 : ((correctCount / totalQuestions) * 100).round();
  return QuizResultModel(
    correctCount: correctCount,
    totalQuestions: totalQuestions,
    xpEarned: 12,
    accuracy: accuracy,
    currentXp: 42,
    xpForNext: 100,
    level: 3,
    events: const [],
  );
}

Future<void> _prepareViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
