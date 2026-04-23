import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/four_choice_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_feedback_bar.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_standard_mode_content.dart';

void main() {
  group('QuizStandardModeContent', () {
    testWidgets('renders standard quiz and forwards selected option',
        (tester) async {
      String? selectedOptionId;

      await _pumpQuizStandardModeContent(
        tester,
        onAnswer: (optionId) {
          selectedOptionId = optionId;
        },
      );

      expect(find.text('N5 단어 퀴즈'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(FourChoiceQuiz), findsOneWidget);
      expect(find.text('食べる'), findsOneWidget);
      expect(find.text('たべる'), findsOneWidget);

      await tester.tap(find.text('먹다'));
      await tester.pump();

      expect(selectedOptionId, 'o1');
    });

    testWidgets('shows feedback bar after answer and forwards next',
        (tester) async {
      var nextCalled = false;

      await _pumpQuizStandardModeContent(
        tester,
        answered: true,
        isCorrect: true,
        streak: 3,
        onNext: () {
          nextCalled = true;
        },
      );

      expect(find.byType(QuizFeedbackBar), findsOneWidget);
      expect(find.text('다음 문제 →'), findsOneWidget);
      expect(find.text('3연속 정답!'), findsOneWidget);

      await tester.tap(find.text('다음 문제 →'));
      await tester.pump();

      expect(nextCalled, isTrue);
    });
  });
}

Future<void> _pumpQuizStandardModeContent(
  WidgetTester tester, {
  bool answered = false,
  bool isCorrect = false,
  int streak = 0,
  ValueChanged<String>? onAnswer,
  VoidCallback? onNext,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: QuizStandardModeContent(
        title: 'N5 단어 퀴즈',
        count: '1/3',
        question: _multipleChoiceQuestion(),
        progress: 1 / 3,
        streak: streak,
        selectedOptionId: null,
        answered: answered,
        isCorrect: isCorrect,
        isLastQuestion: false,
        showFurigana: true,
        onBack: () {},
        onAnswer: onAnswer ?? (_) {},
        onNext: onNext ?? () {},
      ),
    ),
  );
}

QuizQuestionModel _multipleChoiceQuestion() {
  return const QuizQuestionModel(
    questionId: 'q-1',
    questionText: '食べる',
    questionSubText: 'たべる',
    options: [
      QuizOption(id: 'o1', text: '먹다'),
      QuizOption(id: 'o2', text: '보다'),
    ],
    correctOptionId: 'o1',
  );
}
