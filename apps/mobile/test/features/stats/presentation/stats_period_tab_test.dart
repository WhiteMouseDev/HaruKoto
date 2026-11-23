import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/stats/data/models/stats_history_model.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/period_tab.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/stats_bar_chart.dart';

void main() {
  testWidgets(
      'counts only saved answers, presents all weekdays and opens a day',
      (tester) async {
    await _pumpPeriod(
      tester,
      entries: [
        _entry('2026-11-01', (vocabulary: 30, grammar: 5, sentences: 5)),
        _entry('2026-11-02', (vocabulary: 3, grammar: 2, sentences: 4)),
        _entry('2026-11-03', (vocabulary: 8, grammar: 4, sentences: 4)),
        _entry('2026-11-04', (vocabulary: 0, grammar: 0, sentences: 0)),
        _entry('2026-11-05', (vocabulary: 3, grammar: 0, sentences: 3)),
        _entry('2026-11-06', (vocabulary: 9, grammar: 9, sentences: 9)),
      ],
    );

    expect(find.bySemanticsLabel('오늘 푼 문제, 6문제'), findsOneWidget);
    expect(find.bySemanticsLabel('이번 주 푼 문제, 31문제'), findsOneWidget);
    expect(find.text('11.2~11.8'), findsOneWidget);
    expect(find.text('11월 5일 (목) · 6문제'), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-zero-2026-11-04')), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-bar-2026-11-06')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(StatsBarChart),
        matching: find.bySemanticsLabel('2026-11-06 금요일, 예정'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('학습 시간'), findsNothing);
    final chart = tester.getSize(find.byType(StatsBarChart));
    expect(chart.width, 335);
    expect(chart.height, closeTo(229, 3));

    await tester.tap(find.bySemanticsLabel('2026-11-03 화요일, 16문제'));
    await tester.pumpAndSettle();
    expect(find.text('11월 3일 (화) · 16문제'), findsOneWidget);
    expect(find.text('단어 8 · 문법 4 · 문장배열 4'), findsOneWidget);
  });

  testWidgets('missing weekly data never invents zero or uses legacy totals',
      (tester) async {
    await _pumpPeriod(
      tester,
      today: TodayStats.fromJson({
        'quizzesCompleted': 60,
        'totalAnswers': 64,
        'categoryGoals': {
          'date': '2026-11-05',
          'vocabulary': {'target': 20, 'answeredCount': 3},
          'grammar': {'target': 20, 'answeredCount': 4},
          'sentence': {'target': 20, 'answeredCount': 2},
        },
      }),
    );

    expect(find.bySemanticsLabel('오늘 푼 문제, 9문제'), findsOneWidget);
    expect(find.bySemanticsLabel('이번 주 푼 문제, 집계 확인 필요'), findsOneWidget);
    expect(find.text('11월 5일 (목) · 9문제'), findsOneWidget);
    expect(find.bySemanticsLabel('2026-11-02 월요일, 집계 확인 필요'), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-zero-2026-11-02')), findsNothing);
    expect(find.textContaining('64문제'), findsNothing);
  });

  testWidgets('annual heatmap marks credited study days and personal goals',
      (tester) async {
    final selectedYears = <int>[];
    await _pumpPeriod(
      tester,
      onYearChange: selectedYears.add,
      history: [
        StatsHistoryRecord.fromJson(
            {'date': '2026-01-02', 'hasStudied': false, 'xpEarned': 20}),
        StatsHistoryRecord.fromJson({'date': '2026-01-03', 'hasStudied': true}),
        StatsHistoryRecord.fromJson({
          'date': '2026-01-04',
          'hasStudied': true,
          'goalAchieved': true,
        }),
      ],
    );

    expect(find.text('총 2일 · 목표 달성 1일'), findsOneWidget);
    expect(find.bySemanticsLabel('2026-01-02 금요일, 기록 없음'), findsOneWidget);
    expect(find.bySemanticsLabel('2026-01-03 토요일, 학습일'), findsOneWidget);
    final goal = find.bySemanticsLabel('2026-01-04 일요일, 목표 달성');
    await tester.tap(goal);
    await tester.pumpAndSettle();
    expect(find.text('2026-01-04 (일) · 목표 달성'), findsOneWidget);

    await tester.tap(find.byTooltip('이전 연도'));
    expect(selectedYears, [2025]);
  });
}

WeeklyQuestionStatEntry _entry(String date, StatsBarCounts counts) =>
    WeeklyQuestionStatEntry(
      date: date,
      hasStudied: counts.vocabulary + counts.grammar + counts.sentences > 0,
      vocabularyAnsweredCount: counts.vocabulary,
      grammarAnsweredCount: counts.grammar,
      sentenceArrangeAnsweredCount: counts.sentences,
    );

Future<void> _pumpPeriod(
  WidgetTester tester, {
  TodayStats? today,
  List<WeeklyQuestionStatEntry>? entries,
  List<StatsHistoryRecord> history = const [],
  ValueChanged<int>? onYearChange,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 15)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PeriodTab(
            today: today ?? TodayStats.fromJson({}),
            questionStats: entries,
            historyRecords: history,
            heatmapYear: 2026,
            onHeatmapYearChange: onYearChange ?? (_) {},
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
