import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_page_content.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final failFirstSave in [false, true]) {
    testWidgets(
        'partial exit drains POST, blocks failed writes and retries (failFirst=$failFirstSave)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _DelayedAnswerRepository()
        ..failedWrites = failFirstSave ? 1 : 0;
      var dashboardReads = 0;
      final container = ProviderContainer(overrides: [
        dashboardProvider.overrideWith((ref) async {
          dashboardReads++;
          return DashboardModel.fromJson({
            'today': {
              'vocabularyGoal': {
                'date': '2026-10-30',
                'answeredCount': repository.savedAnswers,
              },
            },
          });
        }),
        sharedPreferencesProvider.overrideWithValue(prefs),
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      try {
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(builder: (context, ref, child) {
              final progress = ref.watch(incompleteQuizProvider).value;
              final daily = ref.watch(dashboardProvider).value;
              return Scaffold(
                  body: Column(children: [
                Text('저장 ${progress?.answeredCount ?? 0}/2'),
                Text(
                    '오늘 ${daily?.today.vocabularyGoal?.answeredCount ?? 0}/20'),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    quizRoute(const QuizPage(count: 2)),
                  ),
                  child: const Text('퀴즈 열기'),
                ),
              ]));
            }),
          ),
        ));
        await tester.pumpAndSettle();
        expect(repository.sessionReads, 1);
        expect(dashboardReads, 1);
        await tester.tap(find.text('퀴즈 열기'));
        await tester.pumpAndSettle();
        container.read(quizSessionProvider.notifier).answerCurrentQuestion(
              optionId: 'correct',
              questionType: 'VOCABULARY',
            );
        await tester.pump();
        tester
            .widget<QuizPageContent>(find.byType(QuizPageContent))
            .onBackRequested();
        await tester.pumpAndSettle();
        await tester.tap(find.text('종료'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(QuizPage), findsOneWidget);
        expect(find.text('답안을 저장하고 있어요'), findsOneWidget);
        expect(repository.sessionReads, 1);

        repository.answerWrite.complete();
        await tester.pumpAndSettle();
        if (failFirstSave) {
          expect(find.byType(QuizPage), findsOneWidget);
          expect(find.text('답안을 저장하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
          expect(find.text('답안을 저장하고 있어요'), findsNothing);
          expect(repository.sessionReads, 1);
          expect(dashboardReads, 1);
          tester
              .widget<QuizPageContent>(find.byType(QuizPageContent))
              .onBackRequested();
          await tester.pumpAndSettle();
          await tester.tap(find.text('종료'));
          await tester.pumpAndSettle();
        }
        expect(find.byType(QuizPage), findsNothing);
        expect(find.text('저장 1/2'), findsOneWidget);
        expect(repository.sessionReads, 2);
        expect(find.text('오늘 1/20'), findsOneWidget);
        expect(dashboardReads, 2);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        container.dispose();
      }
    });
  }
}

class _DelayedAnswerRepository extends Fake implements StudyRepository {
  final answerWrite = Completer<void>();
  int savedAnswers = 0;
  int sessionReads = 0;
  int failedWrites = 0;

  @override
  Future<IncompleteSessionModel?> fetchIncompleteQuiz() async {
    sessionReads++;
    return IncompleteSessionModel(
      id: 'same-session',
      quizType: 'VOCABULARY',
      jlptLevel: 'N5',
      totalQuestions: 2,
      answeredCount: savedAnswers,
      correctCount: savedAnswers,
      startedAt: '2026-10-19T01:00:00Z',
    );
  }

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions})> startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  }) async =>
      (
        sessionId: 'same-session',
        questions: const [
          QuizQuestionModel(
              questionId: 'q1',
              questionText: '猫',
              options: [QuizOption(id: 'correct', text: '고양이')],
              correctOptionId: 'correct'),
          QuizQuestionModel(
              questionId: 'q2',
              questionText: '犬',
              options: [QuizOption(id: 'correct', text: '개')],
              correctOptionId: 'correct'),
        ]
      );

  @override
  Future<void> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required bool isCorrect,
    required int timeSpentSeconds,
    required String questionType,
  }) async {
    await answerWrite.future;
    if (failedWrites > 0) {
      failedWrites--;
      throw TimeoutException('Synthetic failed POST');
    }
    savedAnswers++;
  }
}
