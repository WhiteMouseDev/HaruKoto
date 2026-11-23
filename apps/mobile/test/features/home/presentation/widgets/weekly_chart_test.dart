import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/weekly_chart.dart';

final _today = DateTime.utc(2026, 11, 5);

void main() {
  testWidgets('shows Monday to Sunday and scales exactly by total questions',
      (tester) async {
    await _pumpChart(
      tester,
      questionStats: _week({
        2: (20, 0, 0, true),
        3: (60, 30, 10, true),
        4: (0, 0, 0, false),
        5: (0, 4, 0, true),
        7: (800, 1, 1, true),
      }).reversed.toList(),
    );

    final monday = tester.getRect(_bar('2026-11-02'));
    final tuesday = tester.getRect(_bar('2026-11-03'));
    expect(monday.left, lessThan(tuesday.left));
    expect(tuesday.height, closeTo(monday.height * 5, 0.02));
    expect(monday.bottom, closeTo(tuesday.bottom, 0.02));
    final segments = find.descendant(
      of: _bar('2026-11-03'),
      matching: find.byType(ColoredBox),
    );
    expect(segments, findsNWidgets(3));
    for (var index = 0; index < 3; index++) {
      expect(tester.getSize(segments.at(index)).width, tuesday.width);
    }
    expect(_bar('2026-11-07'), findsNothing);
    expect(_zero('2026-11-04'), findsOneWidget);
    expect(_zero('2026-11-06'), findsNothing);
    expect(find.text('11.2~11.8'), findsOneWidget);
    expect(find.text('124개'), findsOneWidget);
    expect(find.text('3일'), findsOneWidget);
    expect(find.textContaining('목표'), findsNothing);
    expect(find.textContaining('XP'), findsNothing);

    await tester.tap(_day('2026-11-03'));
    await tester.pumpAndSettle();
    expect(find.text('11월 3일 (화) · 100문제'), findsOneWidget);
    expect(find.text('단어 60 · 문법 30 · 문장배열 10'), findsOneWidget);

    await tester.tap(_day('2026-11-04'));
    await tester.pumpAndSettle();
    expect(find.text('11월 4일 (수) · 0문제'), findsOneWidget);
    expect(find.text('11월 3일 (화) · 100문제'), findsNothing);
  });

  testWidgets('keeps the panel size when data, loading, or error changes',
      (tester) async {
    await _pumpChart(tester, questionStats: _week({}));
    final chartHeight = tester.getSize(find.byType(WeeklyChart)).height;
    expect(find.text('이번 주 학습 기록이 아직 없어요'), findsOneWidget);
    expect(find.text('오늘 단어 1개만 학습해도 그래프가 채워져요!'), findsOneWidget);
    expect(find.text('0개'), findsOneWidget);
    expect(find.text('0일'), findsOneWidget);

    await _pumpChart(tester, isLoading: true);
    expect(find.text('주간 학습 기록을 불러오는 중이에요'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(tester.getSize(find.byType(WeeklyChart)).height, chartHeight);

    await _pumpChart(tester, hasError: true);
    expect(find.text('주간 학습 기록을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(tester.getSize(find.byType(WeeklyChart)).height, chartHeight);

    await _pumpChart(
      tester,
      questionStats: _week({2: (4, 0, 0, true)}),
    );
    expect(tester.getSize(find.byType(WeeklyChart)).height, chartHeight);
  });

  testWidgets('non-quiz study counts only as a study day', (tester) async {
    await _pumpChart(tester, questionStats: _week({3: (0, 0, 0, true)}));
    expect(find.text('이번 주 문제풀이 기록은 아직 없어요'), findsOneWidget);
    expect(find.text('0개'), findsOneWidget);
    expect(find.text('1일'), findsOneWidget);
    expect(_bar('2026-11-03'), findsNothing);
  });

  testWidgets('legacy reports never become three-category data',
      (tester) async {
    await _pumpChart(
      tester,
      weeklyStats: [
        for (var day = 2; day <= 5; day++)
          WeeklyStatEntry(
            date: '2026-11-0$day',
            wordsStudied: 8,
            xpEarned: 40,
            vocabularyAnsweredCount: 8,
            hasStudied: day == 2,
          ),
      ],
    );

    expect(find.text('주간 문제풀이 기록을 확인할 수 없어요'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('1일'), findsOneWidget);
    expect(find.text('0개'), findsNothing);
    expect(_bar('2026-11-02'), findsNothing);
  });

  testWidgets('details opens learning statistics', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: WeeklyChart(weeklyStats: const [], studyDate: _today),
          ),
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const Scaffold(body: Text('학습 통계 화면')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
    ));

    await tester.tap(find.text('학습 통계 자세히 보기'));
    await tester.pumpAndSettle();
    expect(find.text('학습 통계 화면'), findsOneWidget);
  });
}

Finder _day(String date) => find.byKey(ValueKey('weekly-day-$date'));
Finder _bar(String date) => find.byKey(ValueKey('weekly-question-bar-$date'));
Finder _zero(String date) => find.byKey(ValueKey('weekly-zero-bar-$date'));

List<WeeklyQuestionStatEntry> _week(Map<int, (int, int, int, bool)> counts) => [
      for (var day = 2; day <= 8; day++)
        WeeklyQuestionStatEntry(
          date: '2026-11-0$day',
          vocabularyAnsweredCount: counts[day]?.$1 ?? 0,
          grammarAnsweredCount: counts[day]?.$2 ?? 0,
          sentenceArrangeAnsweredCount: counts[day]?.$3 ?? 0,
          hasStudied: counts[day]?.$4 ?? false,
        ),
    ];

Future<void> _pumpChart(
  WidgetTester tester, {
  List<WeeklyStatEntry> weeklyStats = const [],
  List<WeeklyQuestionStatEntry>? questionStats,
  bool isLoading = false,
  bool hasError = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: WeeklyChart(
          weeklyStats: weeklyStats,
          questionStats: questionStats,
          studyDate: _today,
          isLoading: isLoading,
          hasError: hasError,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
