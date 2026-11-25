import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/practice/presentation/practice_page.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/data/models/saved_quiz_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/free_quiz_sheet.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_service.dart';
import 'package:harukoto_mobile/features/study/providers/saved_quiz_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:harukoto_mobile/shared/widgets/app_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _start = ValueKey('practice-start-quiz');

void main() {
  group('PracticePage', () {
    testWidgets('frames the tab around quiz actions and records',
        (tester) async {
      await _pumpPracticePage(tester);

      expect(find.text('단어 퀴즈 풀기'), findsOneWidget);
      expect(find.text('10문제'), findsOneWidget);
      expect(find.text('퀴즈 풀기'), findsOneWidget);
      expect(find.textContaining('기본 모드'), findsNothing);
      expect(find.text('퀴즈 기록'), findsOneWidget);
      expect(find.text('0개'), findsNWidgets(3));
      expect(find.text('오늘의 단어 학습'), findsNothing);
      expect(find.text('학습 관리'), findsNothing);

      final titleStyle = tester.widget<Text>(find.text('단어 퀴즈 풀기')).style!;
      expect(titleStyle.fontFamily, 'Pretendard');
      expect(titleStyle.fontSize, 18);
      expect(titleStyle.fontWeight, FontWeight.w600);
      expect(titleStyle.letterSpacing, closeTo(-0.45, 0.001));

      for (final (type, label) in [
        ('VOCABULARY', '단어'),
        ('GRAMMAR', '문법'),
        ('KANJI', '한자'),
        ('LISTENING', '리스닝'),
        ('SENTENCE_ARRANGE', '문장배열'),
      ]) {
        final tab = find.byKey(ValueKey('practice-category-$type'));
        final text = find.descendant(of: tab, matching: find.text(label));
        expect(tester.getCenter(text).dy,
            closeTo(tester.getCenter(tab).dy - 1, 0.001));
        if (type == 'SENTENCE_ARRANGE') expect(tester.getSize(tab).width, 84);
      }
    });

    for (final category in ['VOCABULARY', 'GRAMMAR']) {
      testWidgets('$category enters its own free quiz with four-choice default',
          (tester) async {
        await _pumpPracticePage(tester);
        await tester.tap(
          find.byKey(ValueKey('practice-category-$category')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_start));
        await tester.pumpAndSettle();

        final sheet = tester.widget<FreeQuizSheet>(find.byType(FreeQuizSheet));
        expect(sheet.initialSelection.type, category);
        expect(sheet.initialSelection.mode, 'normal');
        final sheetLabels = find.descendant(
          of: find.byType(FreeQuizSheet),
          matching: find.text('4지선다'),
        );
        expect(sheetLabels, findsOneWidget);
        expect(find.byType(QuizPage), findsNothing);
      });
    }

    testWidgets('starts sentence arrange as a quiz-specific category',
        (tester) async {
      final repository = _QuizStartSpy();
      await _pumpPracticePage(
        tester,
        initialCategory: 'SENTENCE_ARRANGE',
        repository: repository,
      );

      expect(find.text('문장배열 퀴즈 풀기'), findsOneWidget);
      await tester.tap(find.byKey(_start));
      await tester.pumpAndSettle();

      expect(find.byType(FreeQuizSheet), findsNothing);
      expect(find.byType(QuizPage), findsOneWidget);
      expect(repository.starts, [('SENTENCE_ARRANGE', 'N5', 10, 'arrange')]);
      Navigator.of(tester.element(find.byType(QuizPage))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('keeps saved quizzes accessible across category changes',
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
      expect(find.text('진행 중인 퀴즈 이어풀기'), findsOneWidget);
      expect(find.text('3/10문제 저장됨'), findsOneWidget);
      expect(find.text('전체 보기'), findsOneWidget);

      await tester.tap(find.text('문법'));
      await tester.pumpAndSettle();

      expect(find.text('문법 퀴즈 풀기'), findsOneWidget);
      expect(find.text('3/10문제 저장됨'), findsOneWidget);
    });

    testWidgets('today counts all completed quizzes across category changes',
        (tester) async {
      await _pumpPracticePage(tester,
          loadDashboard: () async => _dashboard(total: 10, correct: 8));

      expect(find.bySemanticsLabel('푼 문제 10개'), findsOneWidget);
      expect(find.bySemanticsLabel('정답 8개'), findsOneWidget);
      expect(find.bySemanticsLabel('오답 2개'), findsOneWidget);

      final metric = tester.widget<Text>(find.text('10개'));
      final unitStyle = (metric.textSpan! as TextSpan).children!.single.style!;
      expect(metric.style!.fontSize, 18);
      expect(metric.style!.fontWeight, FontWeight.w600);
      expect(unitStyle.fontSize, 13);
      expect(unitStyle.fontWeight, FontWeight.w400);
      expect(unitStyle.letterSpacing, closeTo(-0.325, 0.001));

      await tester.tap(find.byKey(const ValueKey('practice-category-GRAMMAR')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('푼 문제 10개'), findsOneWidget);
      expect(find.bySemanticsLabel('오답 2개'), findsOneWidget);
    });

    testWidgets('a completed quiz refreshes today records in place',
        (tester) async {
      var completed = false;
      await _pumpPracticePage(
        tester,
        loadDashboard: () async =>
            completed ? _dashboard(total: 10, correct: 7) : _dashboard(),
        repository: _QuizStartSpy(onComplete: () => completed = true),
      );
      expect(find.bySemanticsLabel('푼 문제 0개'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PracticePage)),
      );
      await container.read(quizSessionServiceProvider).completeQuiz('q1');
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('푼 문제 10개'), findsOneWidget);
      expect(find.bySemanticsLabel('정답 7개'), findsOneWidget);
      expect(find.bySemanticsLabel('오답 3개'), findsOneWidget);
    });

    testWidgets('today records distinguish loading, error and retry',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final first = Completer<DashboardModel>();
      var reads = 0;
      await _pumpPracticePage(tester, loadDashboard: () async {
        reads++;
        return reads == 1 ? first.future : _dashboard(total: 5, correct: 5);
      });
      expect(find.bySemanticsLabel('오늘의 기록 불러오는 중'), findsOneWidget);
      expect(find.byType(AppSkeletonBlock), findsNWidgets(3));
      expect(find.text('오늘 푼 퀴즈'), findsOneWidget);
      expect(find.text('정답'), findsOneWidget);
      expect(find.text('오답'), findsOneWidget);
      expect(find.text('0개'), findsNothing);

      first.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 기록을 확인하지 못했어요'), findsOneWidget);
      expect(find.byType(AppSkeletonBlock), findsNothing);
      expect(find.text('0개'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('practice-today-retry')));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.bySemanticsLabel('푼 문제 5개'), findsOneWidget);
      expect(find.bySemanticsLabel('오답 0개'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('five category controls fit narrow dark mode and larger text',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpPracticePage(
        tester,
        brightness: Brightness.dark,
        textScale: 2,
      );
      final tabStrip = find.byWidgetPredicate((widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal);
      await tester.drag(tabStrip, const Offset(-250, 0));
      await tester.pumpAndSettle();
      final sentences =
          find.byKey(const ValueKey('practice-category-SENTENCE_ARRANGE'));
      await tester.tap(sentences);
      await tester.pumpAndSettle();
      expect(find.text('문장배열 퀴즈 풀기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpPracticePage(
  WidgetTester tester, {
  String? initialCategory,
  IncompleteSessionModel? incomplete,
  Future<DashboardModel> Function()? loadDashboard,
  StudyRepository? repository,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: [
        currentAccountIdProvider.overrideWithValue('test-account'),
        currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        dashboardProvider.overrideWith(
          (ref) => loadDashboard?.call() ?? Future.value(_dashboard()),
        ),
        if (repository != null)
          studyRepositoryProvider.overrideWithValue(repository),
        savedQuizListProvider.overrideWith(() => _SavedList(incomplete)),
        quizStatsProvider((level: 'N5', type: 'VOCABULARY')).overrideWith(
          (ref) => Future.value(_stats()),
        ),
        quizStatsProvider((level: 'N5', type: 'GRAMMAR')).overrideWith(
          (ref) => Future.value(_stats()),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: PracticePage(initialCategory: initialCategory),
      ),
    ),
  );

  await tester.pump();
  await tester.pump();
}

class _SavedList extends SavedQuizList {
  _SavedList(this.session);
  final IncompleteSessionModel? session;
  @override
  Future<SavedQuizListState> build() async => SavedQuizListState(
        accountId: 'test-account',
        sessions: session == null ? [] : [SavedQuizModel.fromLegacy(session!)],
      );
}

StudyStatsModel _stats() {
  return const StudyStatsModel(
    totalCount: 20,
    studiedCount: 5,
    progress: 25,
  );
}

DashboardModel _dashboard({int total = 0, int correct = 0}) =>
    DashboardModel.fromJson({
      'today': {'totalAnswers': total, 'correctAnswers': correct},
    });

class _QuizStartSpy extends Fake implements StudyRepository {
  _QuizStartSpy({this.onComplete});

  final VoidCallback? onComplete;
  final starts = <(String, String, int, String?)>[];

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions, String? mode})>
      startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  }) async {
    starts.add((quizType, jlptLevel, count, mode));
    return (
      sessionId: 'test-session',
      questions: const <QuizQuestionModel>[],
      mode: mode,
    );
  }

  @override
  Future<QuizResultModel> completeQuiz(String sessionId,
      {String? stageId}) async {
    onComplete?.call();
    return QuizResultModel.fromJson({});
  }
}
