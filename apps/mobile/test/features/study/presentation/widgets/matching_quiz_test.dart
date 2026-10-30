import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/matching_quiz.dart';

void main() {
  group('MatchingQuiz', () {
    testWidgets('forwards matches, advances rounds, and completes',
        (tester) async {
      final results = <String>[];
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchingQuiz(
              questions: _questions,
              pairsPerRound: 1,
              showFurigana: false,
              onMatchResult: (questionId, isCorrect) {
                results.add('$questionId:$isCorrect');
              },
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('0/2 연결 완료'), findsOneWidget);
      expect(find.text('라운드 1/2'), findsOneWidget);

      await tester.tap(find.text('食べる'));
      await tester.pump();
      await tester.tap(find.text('먹다'));
      await tester.pump();

      expect(results, ['q1:true']);
      expect(find.text('1/2 연결 완료'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 401));

      expect(find.text('라운드 2/2'), findsOneWidget);

      await tester.tap(find.text('見る'));
      await tester.pump();
      await tester.tap(find.text('보다'));
      await tester.pump();

      expect(results, ['q1:true', 'q2:true']);

      await tester.pump(const Duration(milliseconds: 401));

      expect(completed, isTrue);
    });

    testWidgets(
        'preserves round progress when save status rebuilds the same questions',
        (tester) async {
      Future<void> pumpQuiz() => tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: MatchingQuiz(
              questions: List.of(_questions),
              pairsPerRound: 1,
              showFurigana: false,
              onMatchResult: (_, __) {},
              onComplete: () {},
            )),
          ));
      await pumpQuiz();
      await tester.tap(find.text('食べる'));
      await tester.pump();
      await tester.tap(find.text('먹다'));
      await tester.pump(const Duration(milliseconds: 401));
      expect(find.text('라운드 2/2'), findsOneWidget);
      await pumpQuiz();
      expect(find.text('라운드 2/2'), findsOneWidget);
      expect(find.text('1/2 연결 완료'), findsOneWidget);
      expect(find.text('食べる'), findsNothing);
    });
  });
}

const _questions = [
  QuizQuestionModel(
    questionId: 'q1',
    questionText: 'ignored',
    questionSubText: 'たべる',
    options: [],
    correctOptionId: '',
    matchingWord: '食べる',
    matchingMeaning: '먹다',
  ),
  QuizQuestionModel(
    questionId: 'q2',
    questionText: 'ignored',
    questionSubText: 'みる',
    options: [],
    correctOptionId: '',
    matchingWord: '見る',
    matchingMeaning: '보다',
  ),
];
