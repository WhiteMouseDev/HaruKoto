import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/cloze_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/four_choice_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_page_content.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_special_mode_content.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_standard_mode_content.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('QuizPageContent', () {
    testWidgets(
        'all saved answers allow completion without reading a missing question',
        (tester) async {
      var completed = 0;
      await _pumpQuizPageContent(
        tester,
        session: QuizSessionState(
            loading: false,
            questions: [_multipleChoiceQuestion()],
            currentIndex: 1),
        onComplete: () => completed++,
      );
      expect(find.text('모든 답안이 저장됐어요'), findsOneWidget);
      expect(find.byType(FourChoiceQuiz), findsNothing);
      await tester.tap(find.text('결과 확인하기'));
      expect(completed, 1);
    });

    testWidgets('shows loading state', (tester) async {
      await _pumpQuizPageContent(
        tester,
        session: const QuizSessionState(loading: true),
      );

      expect(find.text('퀴즈를 준비하고 있어요...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a recoverable load error instead of review empty state',
        (tester) async {
      var retried = false;
      await _pumpQuizPageContent(tester,
          session: const QuizSessionState(
            loading: false,
            resolvedMode: 'review',
            loadError: '로그인이 필요합니다.',
          ),
          onRetryLoad: () => retried = true);
      expect(find.text('퀴즈를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('로그인이 필요합니다.'), findsOneWidget);
      expect(find.text('복습할 문제가 없어요!'), findsNothing);
      await tester.tap(find.text('다시 불러오기'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('uncertain new-start failure offers exit without a POST retry',
        (tester) async {
      var exited = false;
      await _pumpQuizPageContent(tester,
          session: const QuizSessionState(
            loading: false,
            loadError: '잠시 후 다시 시도해 주세요.',
          ),
          onExit: () => exited = true);
      expect(find.text('다시 불러오기'), findsNothing);
      expect(find.textContaining('이어서 학습하기를 확인해 주세요.'), findsOneWidget);
      expect(find.text('이 레벨의 콘텐츠를 준비하고 있어요'), findsNothing);
      await tester.tap(find.text('학습으로 돌아가기'));
      expect(exited, isTrue);
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
      expect(find.byType(QuizStandardModeContent), findsOneWidget);
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

      expect(find.byType(QuizSpecialModeContent), findsOneWidget);
      expect(capturedQuestionId, 'q-cloze');
      expect(capturedIsCorrect, isTrue);
      expect(capturedQuestionType, 'CLOZE');
      expect(capturedOptionId, 'o2');
    });

    testWidgets(
        'saving blocks duplicate result actions while preserving the quiz',
        (tester) async {
      var nextCalls = 0;
      await _pumpQuizPageContent(
        tester,
        session: QuizSessionState(
            loading: false,
            questions: [_multipleChoiceQuestion()],
            answered: true,
            isCorrect: true,
            completing: true),
        onNext: () => nextCalls++,
      );
      expect(find.text('답안을 저장하고 있어요...'), findsOneWidget);
      expect(find.byType(FourChoiceQuiz), findsOneWidget);
      await tester.tap(find.text('결과 보기'), warnIfMissed: false);
      expect(nextCalls, 0);
    });

    for (final mode in [null, 'matching']) {
      testWidgets('save failure offers a persistent retry in $mode mode',
          (tester) async {
        var retryCalls = 0;
        await _pumpQuizPageContent(
          tester,
          session: QuizSessionState(
              loading: false,
              resolvedMode: mode,
              questions: [_multipleChoiceQuestion()],
              completionError:
                  const ApiException(message: '답안을 저장하지 못했어요. 다시 시도해주세요.')),
          onComplete: () => retryCalls++,
        );
        await tester.pump(const Duration(seconds: 10));
        expect(find.text('답안을 저장하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
        await tester.tap(find.text('다시 시도'));
        expect(retryCalls, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('fully saved resumed $mode quiz can request its result',
          (tester) async {
        var completionCalls = 0;
        final session = QuizSessionState(
            loading: false,
            resolvedMode: mode,
            questions: [_multipleChoiceQuestion()],
            currentIndex: 1);
        await _pumpQuizPageContent(tester,
            session: session, onComplete: () => completionCalls++);
        expect(session.headerCount, '1/1');
        expect(find.text('모든 답안이 저장됐어요'), findsOneWidget);
        await tester.tap(find.text('결과 확인하기'));
        expect(completionCalls, 1);
        expect(tester.takeException(), isNull);
      });
    }
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
  VoidCallback? onRetryLoad,
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
          onRetryLoad: onRetryLoad,
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
