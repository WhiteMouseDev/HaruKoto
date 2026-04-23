import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/typing_quiz.dart';

void main() {
  group('TypingQuiz', () {
    testWidgets('enables submit after input and reports the answer',
        (tester) async {
      String? answeredQuestionId;
      bool? answeredCorrectly;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypingQuiz(
              questions: const [_typingQuestion],
              onAnswer: (questionId, isCorrect) {
                answeredQuestionId = questionId;
                answeredCorrectly = isCorrect;
              },
              onComplete: () {},
            ),
          ),
        ),
      );

      FilledButton submitButton() {
        return tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '확인'),
        );
      }

      expect(submitButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  TABERU ');
      await tester.pump();

      expect(submitButton().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, '확인'));
      await tester.pump();

      expect(answeredQuestionId, 'q-typing');
      expect(answeredCorrectly, isTrue);
      expect(find.text('정답이에요!'), findsOneWidget);
    });
  });
}

const _typingQuestion = QuizQuestionModel(
  questionId: 'q-typing',
  questionText: 'Type this',
  prompt: '食べる',
  answer: 'taberu',
  options: [],
  correctOptionId: '',
);
