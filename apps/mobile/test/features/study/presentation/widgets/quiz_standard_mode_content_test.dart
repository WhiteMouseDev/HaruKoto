import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/four_choice_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_feedback_bar.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_standard_mode_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

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

      expect(find.text('N5 단어퀴즈'), findsOneWidget);
      expect(find.text('1개'), findsOneWidget);
      expect(find.text('3개'), findsOneWidget);
      expect(find.text('Q1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(FourChoiceQuiz), findsOneWidget);
      expect(find.text('食べる'), findsOneWidget);
      final badge = find
          .ancestor(
            of: find.text('Q1'),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final badgeBottom = tester.getBottomLeft(badge).dy;
      final promptTop = tester.getTopLeft(find.text('食べる')).dy;
      expect(promptTop - badgeBottom, closeTo(24, 0.01));
      expect(find.text('たべる'), findsOneWidget);
      expect(find.byTooltip('음성 듣기'), findsOneWidget);
      final next = find.byKey(const ValueKey('quiz-next'));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      await tester.tap(find.text('먹다'));
      await tester.pump();

      expect(selectedOptionId, 'o1');
    });

    testWidgets('aligns progress and footer to the iPhone design frame',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);

      await _pumpQuizStandardModeContent(tester);

      final progress = tester.getRect(find.byType(LinearProgressIndicator));
      expect(progress, const Rect.fromLTWH(20, 110, 335, 8));
      final badge = find
          .ancestor(
            of: find.text('Q1'),
            matching: find.byType(DecoratedBox),
          )
          .first;
      expect(tester.getTopLeft(badge).dy, closeTo(228, 2));
      final next = find.byKey(const ValueKey('quiz-next'));
      expect(tester.getRect(next), const Rect.fromLTWH(20, 730, 335, 48));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
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
      expect(find.text('다음 문제'), findsOneWidget);
      expect(find.text('3연속 정답!'), findsOneWidget);
      expect(find.text('정답이에요!'), findsOneWidget);
      expect(find.byIcon(LucideIcons.checkCircle2), findsOneWidget);

      await tester.tap(find.text('다음 문제'));
      await tester.pump();

      expect(nextCalled, isTrue);
    });

    testWidgets(
      'wrong feedback retains answer and next without covering the options',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpQuizStandardModeContent(
          tester,
          answered: true,
          selectedOptionId: 'o4',
          brightness: Brightness.dark,
          textScale: 2,
          showFurigana: false,
        );

        expect(find.text('たべる'), findsNothing);
        expect(find.text('아쉬워요!'), findsOneWidget);
        expect(find.byIcon(LucideIcons.xCircle), findsOneWidget);
        expect(find.text('정답: 먹다'), findsOneWidget);
        expect(find.bySemanticsLabel('먹다, 정답'), findsOneWidget);
        expect(find.bySemanticsLabel('놀다, 선택한 오답'), findsOneWidget);

        final lastOption = find.text('놀다');
        final next = find.byKey(const ValueKey('quiz-next'));
        await tester.ensureVisible(lastOption);
        await tester.pumpAndSettle();
        expect(tester.getBottomLeft(lastOption).dy,
            lessThan(tester.getTopLeft(next).dy));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _pumpQuizStandardModeContent(
  WidgetTester tester, {
  bool answered = false,
  bool isCorrect = false,
  int streak = 0,
  String? selectedOptionId,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool showFurigana = true,
  ValueChanged<String>? onAnswer,
  VoidCallback? onNext,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: QuizStandardModeContent(
        title: 'N5 단어퀴즈',
        currentQuestion: 1,
        totalQuestions: 3,
        question: _multipleChoiceQuestion(),
        progress: 1 / 3,
        streak: streak,
        selectedOptionId: selectedOptionId,
        answered: answered,
        isCorrect: isCorrect,
        isLastQuestion: false,
        showFurigana: showFurigana,
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
      QuizOption(id: 'o3', text: '읽다'),
      QuizOption(id: 'o4', text: '놀다'),
    ],
    correctOptionId: 'o1',
  );
}
