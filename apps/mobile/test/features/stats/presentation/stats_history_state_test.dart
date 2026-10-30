import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/stats/data/models/heatmap_data_model.dart';
import 'package:harukoto_mobile/features/stats/data/models/stats_history_model.dart';
import 'package:harukoto_mobile/features/stats/data/models/time_chart_model.dart';
import 'package:harukoto_mobile/features/stats/presentation/stats_page.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/heatmap_widget.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/period_tab.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/stats_bar_chart.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('stats requests the KST year and matches today by the same date',
      (tester) async {
    final years = <int>[];
    final container = await _pump(tester, now: DateTime.utc(2026, 12, 31, 15),
        history: (year) async {
      years.add(year);
      return [
        StatsHistoryRecord.fromJson(
            {'date': '2027-01-01', 'studyTimeSeconds': 180})
      ];
    });
    expect(years, [2027]);
    expect(find.text('3분'), findsWidgets);
    final heatmap = tester.widget<HeatmapWidget>(find.byType(HeatmapWidget));
    expect(heatmap.year, 2027);
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
    expect(find.text('데이터를 불러올 수 없습니다'), findsOneWidget);
    expect(find.byType(PeriodTab), findsNothing);
    fails = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.byType(PeriodTab), findsOneWidget);
    expect(find.text('데이터를 불러올 수 없습니다'), findsNothing);
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
    expect(find.byType(PeriodTab), findsNothing);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('데이터를 불러올 수 없습니다'), findsOneWidget);
    expect(find.byType(PeriodTab), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('weekly chart uses Monday in Korea instead of the device date',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          studyClockProvider
              .overrideWithValue(() => DateTime.utc(2026, 9, 27, 15)),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: StatsBarChart(records: [
          StatsHistoryRecord.fromJson(
              {'date': '2026-09-28', 'studyTimeSeconds': 180}),
          StatsHistoryRecord.fromJson(
              {'date': '2026-09-27', 'studyTimeSeconds': 480}),
        ])))));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('총 학습 시간 3분', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  DateTime? now,
  required Future<List<StatsHistoryRecord>> Function(int) history,
}) async {
  SharedPreferences.setMockInitialValues({'user_jlpt_level': 'N5'});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    currentAccountIdProvider.overrideWithValue('account-a'),
    currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
    sharedPreferencesProvider.overrideWithValue(prefs),
    studyClockProvider
        .overrideWithValue(() => now ?? DateTime.utc(2026, 10, 29, 3)),
    dashboardProvider.overrideWith((ref) async => DashboardModel.fromJson({})),
    statsHistoryProvider.overrideWith((ref, year) => history(year)),
    heatmapProvider
        .overrideWith((ref, year) async => const HeatmapResponse(data: [])),
    timeChartProvider
        .overrideWith((ref, days) async => const TimeChartResponse(data: [])),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const MaterialApp(home: StatsPage())));
  await tester.pumpAndSettle();
  return container;
}
