import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/cloze_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/four_choice_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_page_content.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('QuizPageContent', () {
    testWidgets('shows loading state', (tester) async {
      await _pumpQuizPageContent(
        tester,
        session: const QuizSessionState(loading: true),
      );

      expect(find.text('퀴즈를 준비하고 있어요...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows review empty state and exits', (tester) async {
      var exited = false;

      await _pumpQuizPageContent(
        tester,
        session: const QuizSessionState(
          loading: false,
          resolvedMode: 'review',
        ),
        onExit: () {
          exited = true;
        },
      );

      expect(find.text('복습할 문제가 없어요!'), findsOneWidget);

      await tester.tap(find.text('학습으로 돌아가기'));
      await tester.pump();

      expect(exited, isTrue);
    });

    testWidgets('renders default quiz and forwards option selection',
        (tester) async {
      String? selectedOptionId;

      await _pumpQuizPageContent(
        tester,
        session: QuizSessionState(
          loading: false,
          questions: [_multipleChoiceQuestion()],
        ),
        onAnswer: (optionId) {
          selectedOptionId = optionId;
        },
      );

      expect(find.text('N5 단어 퀴즈'), findsOneWidget);
      expect(find.byType(FourChoiceQuiz), findsOneWidget);
      expect(find.text('食べる'), findsOneWidget);
      expect(find.text('たべる'), findsOneWidget);

      await tester.tap(find.text('먹다'));
      await tester.pump();

      expect(selectedOptionId, 'o1');
    });

    testWidgets('forwards cloze option id through special answer callback',
        (tester) async {
      String? capturedQuestionId;
      bool? capturedIsCorrect;
      String? capturedQuestionType;
      String? capturedOptionId;

      await _pumpQuizPageContent(
        tester,
        session: QuizSessionState(
          loading: false,
          resolvedMode: 'cloze',
          questions: [_clozeQuestion()],
        ),
        onSubmitSpecialAnswer: (
          questionId,
          isCorrect,
          questionType, {
          optionId,
        }) {
          capturedQuestionId = questionId;
          capturedIsCorrect = isCorrect;
          capturedQuestionType = questionType;
          capturedOptionId = optionId;
        },
      );

      final clozeQuiz = tester.widget<ClozeQuiz>(find.byType(ClozeQuiz));
      clozeQuiz.onAnswer('q-cloze', 'o2', true);

      expect(capturedQuestionId, 'q-cloze');
      expect(capturedIsCorrect, isTrue);
      expect(capturedQuestionType, 'CLOZE');
      expect(capturedOptionId, 'o2');
    });
  });
}

Future<void> _pumpQuizPageContent(
  WidgetTester tester, {
  required QuizSessionState session,
  String quizType = 'VOCABULARY',
  String jlptLevel = 'N5',
  VoidCallback? onBackRequested,
  VoidCallback? onExit,
  ValueChanged<String>? onAnswer,
  VoidCallback? onNext,
  VoidCallback? onComplete,
  QuizSpecialAnswerHandler? onSubmitSpecialAnswer,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
      ],
      child: MaterialApp(
        home: QuizPageContent(
          session: session,
          quizType: quizType,
          jlptLevel: jlptLevel,
          onBackRequested: onBackRequested ?? () {},
          onExit: onExit ?? () {},
          onAnswer: onAnswer ?? (_) {},
          onNext: onNext ?? () {},
          onComplete: onComplete ?? () {},
          onSubmitSpecialAnswer: onSubmitSpecialAnswer ??
              (
                _,
                __,
                ___, {
                optionId,
              }) {},
        ),
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

QuizQuestionModel _clozeQuestion() {
  return const QuizQuestionModel(
    questionId: 'q-cloze',
    questionText: '私は ____ を 食べます。',
    sentence: '私は {blank} を 食べます。',
    translation: '저는 ____ 를 먹습니다.',
    options: [
      QuizOption(id: 'o1', text: 'りんご'),
      QuizOption(id: 'o2', text: 'ごはん'),
    ],
    correctOptionId: 'o2',
  );
}
