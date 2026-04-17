import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_result_page.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('QuizResultPage', () {
    testWidgets('review recommendation launches the review flow',
        (tester) async {
      final repository = _FakeStudyRepository();

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

      await tester.tap(find.text('오답 복습 →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('review-route'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('retry button launches the retry flow', (tester) async {
      final repository = _FakeStudyRepository();

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

      await tester.tap(find.text('한 번 더 도전'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('retry-route'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}

class _FakeStudyRepository extends Fake implements StudyRepository {
  int fetchWrongAnswersCalls = 0;

  @override
  Future<List<WrongAnswerModel>> fetchWrongAnswersBySession(
    String sessionId,
  ) async {
    fetchWrongAnswersCalls++;
    return const [];
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
