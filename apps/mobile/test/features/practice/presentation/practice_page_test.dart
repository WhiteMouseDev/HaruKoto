import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/practice/presentation/practice_page.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PracticePage', () {
    testWidgets('frames the tab around quiz actions and records',
        (tester) async {
      await _pumpPracticePage(tester);

      expect(find.text('단어 퀴즈 풀기'), findsOneWidget);
      expect(find.text('N5 · 10문제 · 기본 모드'), findsOneWidget);
      expect(find.text('퀴즈 기록'), findsOneWidget);
      expect(find.text('오늘의 단어 학습'), findsNothing);
      expect(find.text('학습 관리'), findsNothing);
    });

    testWidgets('opens the free quiz picker for vocabulary and grammar',
        (tester) async {
      await _pumpPracticePage(tester);

      await tester.tap(find.text('단어 퀴즈 풀기'));
      await tester.pumpAndSettle();

      expect(find.text('자유 퀴즈'), findsOneWidget);
      expect(find.text('4지선다 퀴즈 시작 (10문제)'), findsOneWidget);
      expect(find.text('4지선다 학습 시작 (10문제)'), findsNothing);
      expect(find.text('오늘의 학습'), findsNothing);
    });

    testWidgets('starts sentence arrange as a quiz-specific category',
        (tester) async {
      await _pumpPracticePage(
        tester,
        initialCategory: 'SENTENCE_ARRANGE',
      );

      expect(find.text('문장 퀴즈 풀기'), findsOneWidget);
      expect(find.text('N5 · 10문제 · 어순 배열'), findsOneWidget);
      expect(find.text('오늘의 문장 학습'), findsNothing);
    });

    testWidgets('shows resume copy only for the selected quiz category',
        (tester) async {
      await _pumpPracticePage(
        tester,
        incomplete: const IncompleteSessionModel(
          id: 'session-1',
          quizType: 'GRAMMAR',
          jlptLevel: 'N5',
          totalQuestions: 10,
          answeredCount: 3,
          correctCount: 2,
          startedAt: '2026-05-11T00:00:00Z',
        ),
      );

      expect(find.text('단어 퀴즈 풀기'), findsOneWidget);
      expect(find.text('진행 중인 퀴즈 이어풀기'), findsNothing);

      await tester.tap(find.text('문법'));
      await tester.pumpAndSettle();

      expect(find.text('진행 중인 퀴즈 이어풀기'), findsOneWidget);
      expect(find.text('N5 · 3/10 문제 진행 중'), findsOneWidget);
    });
  });
}

Future<void> _pumpPracticePage(
  WidgetTester tester, {
  String? initialCategory,
  IncompleteSessionModel? incomplete,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        incompleteQuizProvider.overrideWith(
          (ref) => Future.value(incomplete),
        ),
        quizStatsProvider((level: 'N5', type: 'VOCABULARY')).overrideWith(
          (ref) => Future.value(_stats()),
        ),
        quizStatsProvider((level: 'N5', type: 'GRAMMAR')).overrideWith(
          (ref) => Future.value(_stats()),
        ),
      ],
      child: MaterialApp(
        home: PracticePage(initialCategory: initialCategory),
      ),
    ),
  );

  await tester.pump();
  await tester.pump();
}

StudyStatsModel _stats() {
  return const StudyStatsModel(
    totalCount: 20,
    studiedCount: 5,
    progress: 25,
  );
}
