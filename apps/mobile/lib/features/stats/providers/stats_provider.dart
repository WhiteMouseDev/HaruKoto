import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/study_clock_provider.dart';
import '../data/models/by_category_model.dart';
import '../data/models/heatmap_data_model.dart';
import '../data/models/level_progress_model.dart';
import '../data/models/stats_history_model.dart';
import '../data/models/time_chart_model.dart';
import '../data/models/volume_chart_model.dart';
import '../data/stats_repository.dart';

final statsRepositoryProvider = Provider((ref) {
  return StatsRepository(ref.watch(dioProvider),
      now: ref.watch(studyClockProvider));
});

final statsHistoryProvider =
    FutureProvider.autoDispose.family<List<StatsHistoryRecord>, int>(
  (ref, year) {
    ref.watch(currentAccountIdProvider);
    ref.watch(studyDateProvider);
    return ref.watch(statsRepositoryProvider).fetchHistory(year);
  },
);

final statsMonthHistoryProvider = FutureProvider.autoDispose
    .family<List<StatsHistoryRecord>, ({int year, int month})>(
  (ref, period) {
    ref.watch(currentAccountIdProvider);
    ref.watch(studyDateProvider);
    return ref
        .watch(statsRepositoryProvider)
        .fetchMonthHistory(period.year, period.month);
  },
);

final heatmapProvider = FutureProvider.autoDispose.family<HeatmapResponse, int>(
  (ref, year) {
    ref.watch(currentAccountIdProvider);
    return ref.watch(statsRepositoryProvider).fetchHeatmap(year);
  },
);

final jlptProgressProvider = FutureProvider.autoDispose<JlptProgressResponse>(
  (ref) {
    ref.watch(currentAccountIdProvider);
    return ref.watch(statsRepositoryProvider).fetchJlptProgress();
  },
);

final timeChartProvider =
    FutureProvider.autoDispose.family<TimeChartResponse, int>(
  (ref, days) {
    ref.watch(currentAccountIdProvider);
    return ref.watch(statsRepositoryProvider).fetchTimeChart(days);
  },
);

final volumeChartProvider =
    FutureProvider.autoDispose.family<VolumeChartResponse, int>(
  (ref, days) {
    ref.watch(currentAccountIdProvider);
    return ref.watch(statsRepositoryProvider).fetchVolumeChart(days);
  },
);

final byCategoryProvider = FutureProvider.autoDispose<ByCategoryResponse>(
  (ref) {
    ref.watch(currentAccountIdProvider);
    return ref.watch(statsRepositoryProvider).fetchByCategory();
  },
);
