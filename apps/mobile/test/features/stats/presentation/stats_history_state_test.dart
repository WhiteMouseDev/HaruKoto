import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/stats/data/models/stats_history_model.dart';
import 'package:harukoto_mobile/features/stats/presentation/stats_page.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/heatmap_widget.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/period_tab.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('stats requests the KST year and excludes recorded duration',
      (tester) async {
    final years = <int>[];
    final container = await _pump(tester, now: DateTime.utc(2026, 12, 31, 15),
        history: (year) async {
      years.add(year);
      return [
        StatsHistoryRecord.fromJson(
            {'date': '2027-01-01', 'studyTimeSeconds': 180, 'hasStudied': true})
      ];
    });
    expect(years, [2027]);
    final heatmap = tester.widget<HeatmapWidget>(find.byType(HeatmapWidget));
    expect(heatmap.year, 2027);
    expect(heatmap.records.single.hasStudyActivity, isTrue);
    expect(find.textContaining('학습 시간'), findsNothing);
    expect(find.text('3분'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('a failed month in annual history stays visible and can retry',
      (tester) async {
    var fails = true;
    var requests = 0;
    final container = await _pump(tester, history: (year) async {
      requests++;
      if (fails) throw StateError('One requested month failed');
      return [];
    });
    expect(find.byType(PeriodTab), findsOneWidget);
    expect(tester.widget<HeatmapWidget>(find.byType(HeatmapWidget)).hasError,
        isTrue);
    fails = false;
    await tester.ensureVisible(find.text('다시 시도'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.byType(PeriodTab), findsOneWidget);
    expect(tester.widget<HeatmapWidget>(find.byType(HeatmapWidget)).hasError,
        isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('refresh loading and error never reuse old calendar data',
      (tester) async {
    var requests = 0;
    final pending = Completer<List<StatsHistoryRecord>>();
    final container = await _pump(tester, history: (year) {
      requests++;
      return requests == 1
          ? Future.value([
              StatsHistoryRecord.fromJson(
                  {'date': '2026-10-29', 'studyTimeSeconds': 180})
            ])
          : pending.future;
    });
    expect(find.byType(PeriodTab), findsOneWidget);
    container.invalidate(statsHistoryProvider(2026));
    await tester.pump();
    final loading = tester.widget<HeatmapWidget>(find.byType(HeatmapWidget));
    expect(loading.isLoading, isTrue);
    expect(loading.records, isEmpty);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    final failed = tester.widget<HeatmapWidget>(find.byType(HeatmapWidget));
    expect(failed.hasError, isTrue);
    expect(failed.records, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('period summary uses the KST day and counts all three quiz types',
      (tester) async {
    final container = await _pump(
      tester,
      now: DateTime.utc(2026, 9, 27, 15),
      history: (_) async => [],
      dashboard: {
        'today': {'quizzesCompleted': 99, 'totalAnswers': 200},
        'weeklyQuestionStats': [
          for (var offset = 0; offset < 7; offset++)
            {
              'date': studyDateKey(DateTime.utc(2026, 9, 28 + offset)),
              'hasStudied': offset == 0,
              'vocabularyAnsweredCount': offset == 0 ? 3 : 0,
              'grammarAnsweredCount': offset == 0 ? 2 : 0,
              'sentenceArrangeAnsweredCount': offset == 0 ? 1 : 0,
            },
        ],
      },
    );
    expect(find.text('오늘 푼 문제'), findsOneWidget);
    expect(find.text('이번 주 푼 문제'), findsOneWidget);
    expect(find.textContaining('6문제', findRichText: true),
        findsAtLeastNWidgets(2));
    expect(find.textContaining('9.28'), findsOneWidget);
    expect(find.text('99'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  DateTime? now,
  required Future<List<StatsHistoryRecord>> Function(int) history,
  Map<String, dynamic> dashboard = const {},
}) async {
  SharedPreferences.setMockInitialValues({'user_jlpt_level': 'N5'});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    currentAccountIdProvider.overrideWithValue('account-a'),
    currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
    sharedPreferencesProvider.overrideWithValue(prefs),
    studyClockProvider
        .overrideWithValue(() => now ?? DateTime.utc(2026, 10, 29, 3)),
    dashboardProvider
        .overrideWith((ref) async => DashboardModel.fromJson(dashboard)),
    statsHistoryProvider.overrideWith((ref, year) => history(year)),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const MaterialApp(home: StatsPage())));
  await tester.pumpAndSettle();
  return container;
}
