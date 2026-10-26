import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/services/haptic_service.dart';
import 'package:harukoto_mobile/core/services/sound_service.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_result_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_page_content.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_result_provider.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'result CTA practices only source mistakes and preserves source result',
      (tester) async {
    final repository = _SessionReviewRepository();
    final container = await _pumpSourceResult(tester, repository);
    await tester.ensureVisible(find.text('오답 복습 →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오답 복습 →'));
    await tester.tap(find.text('오답 복습 →'));
    await tester.pumpAndSettle();

    expect(repository.sources, ['source-session']);
    expect(repository.generalStarts, 0);
    final session = container.read(quizSessionProvider);
    expect(session.sessionId, 'review-child');
    expect(session.questions.map((q) => q.questionId), ['wrong-only']);
    expect(find.text('정답이었던 항목'), findsNothing);
    expect(find.text('무관한 복습 항목'), findsNothing);

    container.read(quizSessionProvider.notifier).answerCurrentQuestion(
          optionId: 'correct',
          questionType: 'GRAMMAR',
        );
    tester.widget<QuizPageContent>(find.byType(QuizPageContent)).onComplete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(repository.savedAnswers,
        [('review-child', 'wrong-only', 'correct', 'GRAMMAR')]);
    expect(repository.completedSessions, ['review-child']);
    expect(find.text('이번 퀴즈에는 오답이 없어요'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('이전 퀴즈 결과로 돌아가기'), 200);
    await tester.pump();
    await tester.tap(find.text('이전 퀴즈 결과로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('틀린 문법 1개'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(
        container
            .read(quizResultProvider('source-session'))
            .wrongAnswers
            .single
            .questionId,
        'wrong-only');
    expect(repository.loadedWrongSessions, ['source-session']);
    expect(repository.completedSessions, isNot(contains('source-session')));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'source-start error can retry the same source or return to its list',
      (tester) async {
    final repository = _SessionReviewRepository()..failStarts = 2;
    await _pumpSourceResult(tester, repository);
    await tester.ensureVisible(find.text('오답 복습 →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오답 복습 →'));
    await tester.pumpAndSettle();
    expect(find.text('퀴즈를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('복습할 문제가 없어요!'), findsNothing);
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
    expect(repository.sources, ['source-session', 'source-session']);
    expect(repository.generalStarts, 0);
    await tester.tap(find.text('결과로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('틀린 문법 1개'), findsOneWidget);
    expect(repository.loadedWrongSessions, ['source-session']);
    expect(repository.savedAnswers, isEmpty);
    expect(repository.completedSessions, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<ProviderContainer> _pumpSourceResult(
    WidgetTester tester, _SessionReviewRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await SoundService().setEnabled(false);
  await HapticService().setEnabled(false);
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
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
      result: _result(1, 2),
      quizType: 'GRAMMAR',
      jlptLevel: 'N5',
      sessionId: 'source-session',
    )),
  ));
  await tester.pumpAndSettle();
  return container;
}

class _SessionReviewRepository extends Fake implements StudyRepository {
  int failStarts = 0;
  int generalStarts = 0;
  final sources = <String>[];
  final loadedWrongSessions = <String>[];
  final completedSessions = <String>[];
  final savedAnswers = <(String, String, String, String)>[];

  @override
  Future<List<WrongAnswerModel>> fetchWrongAnswersBySession(
      String sessionId) async {
    loadedWrongSessions.add(sessionId);
    return const [
      WrongAnswerModel(
        questionId: 'wrong-only',
        word: '〜は〜です',
        meaningKo: '~는 ~입니다',
      )
    ];
  }

  @override
  Future<
      ({
        String sessionId,
        List<QuizQuestionModel> questions,
        List<String> answeredQuestionIds,
        int correctCount,
        String? quizType
      })> startWrongAnswerReview(String sourceSessionId) async {
    sources.add(sourceSessionId);
    if (failStarts > 0) {
      failStarts--;
      throw const ApiException(message: 'synthetic failure', statusCode: 503);
    }
    return (
      sessionId: 'review-child',
      questions: const [
        QuizQuestionModel(
          questionId: 'wrong-only',
          questionText: '〜は〜です',
          options: [
            QuizOption(id: 'correct', text: '~는 ~입니다'),
            QuizOption(id: 'wrong', text: '그리고'),
          ],
          correctOptionId: 'correct',
        )
      ],
      answeredQuestionIds: <String>[],
      correctCount: 0,
      quizType: 'GRAMMAR',
    );
  }

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions})> startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  }) async {
    generalStarts++;
    throw StateError('must not use the unrelated due-review pool');
  }

  @override
  Future<void> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required bool isCorrect,
    required int timeSpentSeconds,
    required String questionType,
  }) async {
    savedAnswers.add((sessionId, questionId, selectedOptionId, questionType));
  }

  @override
  Future<QuizResultModel> completeQuiz(String sessionId,
      {String? stageId}) async {
    completedSessions.add(sessionId);
    return _result(1, 1);
  }
}

QuizResultModel _result(int correct, int total) => QuizResultModel(
      correctCount: correct,
      totalQuestions: total,
      xpEarned: 10,
      accuracy: (correct * 100 / total).round(),
      currentXp: 10,
      xpForNext: 100,
      level: 1,
      events: const [],
    );
