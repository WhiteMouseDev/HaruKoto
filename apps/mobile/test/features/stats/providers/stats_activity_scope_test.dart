import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/features/home/data/home_repository.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/stats/data/models/heatmap_data_model.dart';
import 'package:harukoto_mobile/features/stats/data/models/stats_history_model.dart';
import 'package:harukoto_mobile/features/stats/data/stats_repository.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('old account responses cannot replace refreshed dashboard or calendars',
      () async {
    var account = 'account-a';
    final oldDashboard = Completer<DashboardModel>();
    final oldYear = Completer<List<StatsHistoryRecord>>();
    final oldMonth = Completer<List<StatsHistoryRecord>>();
    final oldHeatmap = Completer<HeatmapResponse>();
    final home = _HomeRepository(() => account == 'account-a'
        ? oldDashboard.future
        : Future.value(DashboardModel.fromJson({
            'today': {
              'vocabularyGoal': {'date': '2026-10-30', 'answeredCount': 2},
            },
            'streak': {'current': 2}
          })));
    final stats = _StatsRepository(
      history: () => account == 'account-a' ? oldYear.future : Future.value([]),
      month: () => account == 'account-a' ? oldMonth.future : Future.value([]),
      heatmap: () => account == 'account-a'
          ? oldHeatmap.future
          : Future.value(const HeatmapResponse(data: [])),
    );
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => account),
      currentAccountReaderProvider.overrideWithValue(() => account),
      studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 29, 3)),
      homeRepositoryProvider.overrideWithValue(home),
      statsRepositoryProvider.overrideWithValue(stats),
    ]);
    addTearDown(container.dispose);
    container.listen(dashboardProvider, (_, __) {});
    container.listen(statsHistoryProvider(2026), (_, __) {});
    container.listen(
        statsMonthHistoryProvider((year: 2026, month: 10)), (_, __) {});
    container.listen(heatmapProvider(2026), (_, __) {});
    expect([home.calls, stats.yearCalls, stats.monthCalls, stats.heatmapCalls],
        [1, 1, 1, 1]);
    account = 'account-b';
    container.invalidate(currentAccountIdProvider);
    expect((await container.read(dashboardProvider.future)).streak.current, 2);
    expect(await container.read(statsHistoryProvider(2026).future), isEmpty);
    expect(
        await container
            .read(statsMonthHistoryProvider((year: 2026, month: 10)).future),
        isEmpty);
    expect((await container.read(heatmapProvider(2026).future)).data, isEmpty);
    oldDashboard.complete(DashboardModel.fromJson({
      'today': {
        'vocabularyGoal': {'date': '2026-10-30', 'answeredCount': 99},
      },
      'streak': {'current': 99}
    }));
    oldYear.complete([
      StatsHistoryRecord.fromJson({'date': 'old-account', 'hasStudied': true})
    ]);
    oldMonth.complete([
      StatsHistoryRecord.fromJson({'date': 'old-account', 'hasStudied': true})
    ]);
    oldHeatmap.complete(const HeatmapResponse(
        data: [HeatmapData(date: 'old-account', wordsStudied: 99)]));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(dashboardProvider).value!.streak.current, 2);
    expect(
        container
            .read(dashboardProvider)
            .value!
            .today
            .vocabularyGoal!
            .answeredCount,
        2);
    expect(container.read(statsHistoryProvider(2026)).value, isEmpty);
    expect(
        container
            .read(statsMonthHistoryProvider((year: 2026, month: 10)))
            .value,
        isEmpty);
    expect(container.read(heatmapProvider(2026)).value!.data, isEmpty);
    expect([home.calls, stats.yearCalls, stats.monthCalls, stats.heatmapCalls],
        [2, 2, 2, 2]);
  });

  test('level changes preserve account-wide history and same-day clock cache',
      () async {
    SharedPreferences.setMockInitialValues({'user_jlpt_level': 'N5'});
    final prefs = await SharedPreferences.getInstance();
    final home = _HomeRepository(() async => DashboardModel.fromJson({}));
    final stats =
        _StatsRepository(history: () async => [], month: () async => []);
    var now = DateTime.utc(2026, 10, 29, 3);
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('account-a'),
      currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
      sharedPreferencesProvider.overrideWithValue(prefs),
      studyClockProvider.overrideWithValue(() => now),
      homeRepositoryProvider.overrideWithValue(home),
      statsRepositoryProvider.overrideWithValue(stats),
    ]);
    addTearDown(container.dispose);
    container.listen(dashboardProvider, (_, __) {});
    container.listen(statsHistoryProvider(2026), (_, __) {});
    container.listen(
        statsMonthHistoryProvider((year: 2026, month: 10)), (_, __) {});
    await container.read(dashboardProvider.future);
    await container.read(statsHistoryProvider(2026).future);
    await container
        .read(statsMonthHistoryProvider((year: 2026, month: 10)).future);
    await container.read(userPreferencesProvider.notifier).setJlptLevel('N4');
    container.read(studyDateProvider.notifier).refresh();
    await container.read(dashboardProvider.future);
    await container.read(statsHistoryProvider(2026).future);
    await container
        .read(statsMonthHistoryProvider((year: 2026, month: 10)).future);
    expect([home.calls, stats.yearCalls, stats.monthCalls], [1, 1, 1]);
    now = DateTime.utc(2026, 10, 29, 15);
    container.read(studyDateProvider.notifier).refresh();
    await container.read(dashboardProvider.future);
    await container.read(statsHistoryProvider(2026).future);
    await container
        .read(statsMonthHistoryProvider((year: 2026, month: 10)).future);
    expect([home.calls, stats.yearCalls, stats.monthCalls], [2, 2, 2]);
  });
}

class _HomeRepository extends Fake implements HomeRepository {
  _HomeRepository(this.result);
  final Future<DashboardModel> Function() result;
  int calls = 0;
  @override
  Future<DashboardModel> fetchDashboard() {
    calls++;
    return result();
  }
}

class _StatsRepository extends Fake implements StatsRepository {
  _StatsRepository({required this.history, required this.month, this.heatmap});
  final Future<List<StatsHistoryRecord>> Function() history;
  final Future<List<StatsHistoryRecord>> Function() month;
  final Future<HeatmapResponse> Function()? heatmap;
  int yearCalls = 0;
  int monthCalls = 0;
  int heatmapCalls = 0;
  @override
  Future<List<StatsHistoryRecord>> fetchHistory(int year) {
    yearCalls++;
    return history();
  }

  @override
  Future<List<StatsHistoryRecord>> fetchMonthHistory(int year, int month) {
    monthCalls++;
    return this.month();
  }

  @override
  Future<HeatmapResponse> fetchHeatmap(int year, {int? month}) {
    heatmapCalls++;
    return heatmap!();
  }
}
