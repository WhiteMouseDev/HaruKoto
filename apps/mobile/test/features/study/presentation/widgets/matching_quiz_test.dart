import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/services/haptic_service.dart';
import 'package:harukoto_mobile/core/services/sound_service.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/matching_quiz.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MatchingQuiz', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await HapticService().setEnabled(false);
      await SoundService().setEnabled(false);
    });

    tearDown(() async {
      await HapticService().setEnabled(true);
      await SoundService().setEnabled(true);
    });

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

      expect(find.text('0/2 맞춤'), findsOneWidget);
      expect(find.text('라운드 1/2'), findsOneWidget);

      await tester.tap(find.text('食べる'));
      await tester.pump();
      await tester.tap(find.text('먹다'));
      await tester.pump();

      expect(results, ['q1:true']);
      expect(find.text('1/2 맞춤'), findsOneWidget);

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
