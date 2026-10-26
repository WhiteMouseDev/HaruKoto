import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_launch.dart';

void main() {
  group('quiz launch helpers', () {
    testWidgets(
        'source wrong-review launch keeps its source separate from general review',
        (tester) async {
      QuizLaunchRequest? captured;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        return TextButton(
          onPressed: () => openWrongAnswerReview(context,
              sourceSessionId: 'completed-source',
              quizType: 'GRAMMAR',
              jlptLevel: 'N5', routeBuilder: (request) {
            captured = request;
            return MaterialPageRoute<void>(
                builder: (_) => const _TestDestination());
          }),
          child: const Text('session wrong review'),
        );
      })));
      await tester.tap(find.text('session wrong review'));
      await tester.pumpAndSettle();
      expect(captured!.sourceSessionId, 'completed-source');
      expect(captured!.mode, 'wrong_answer_review');
      expect(captured!.resumeSessionId, isNull);
      expect(find.text('can-pop'), findsOneWidget);
    });

    testWidgets('openQuizPageForSession pushes on top of current route',
        (tester) async {
      QuizLaunchRequest? capturedRequest;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      openQuizPageForSession(
                        context,
                        quizType: 'VOCABULARY',
                        jlptLevel: 'N4',
                        count: 15,
                        mode: 'smart',
                        resumeSessionId: 'session-1',
                        routeBuilder: (request) {
                          capturedRequest = request;
                          return MaterialPageRoute<void>(
                            builder: (_) => const _TestDestination(),
                          );
                        },
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.quizType, 'VOCABULARY');
      expect(capturedRequest!.jlptLevel, 'N4');
      expect(capturedRequest!.count, 15);
      expect(capturedRequest!.mode, 'smart');
      expect(capturedRequest!.resumeSessionId, 'session-1');
      expect(find.text('can-pop'), findsOneWidget);
    });

    testWidgets('openReviewQuiz can replace the current route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      openReviewQuiz(
                        context,
                        quizType: 'GRAMMAR',
                        jlptLevel: 'N3',
                        replace: true,
                        routeBuilder: (_) => MaterialPageRoute<void>(
                          builder: (_) => const _TestDestination(),
                        ),
                      );
                    },
                    child: const Text('replace'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('replace'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });
  });
}

class _TestDestination extends StatelessWidget {
  const _TestDestination();

  @override
  Widget build(BuildContext context) {
    final label = Navigator.of(context).canPop() ? 'can-pop' : 'root';
    return Scaffold(
      body: Center(
        child: Text(label),
      ),
    );
  }
}
