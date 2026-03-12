import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/stats_repository.dart';
import '../data/models/stats_history_model.dart';

final statsRepositoryProvider = Provider((ref) {
  return StatsRepository(ref.watch(dioProvider));
});

final statsHistoryProvider =
    FutureProvider.autoDispose.family<List<StatsHistoryRecord>, int>(
  (ref, year) {
    return ref.watch(statsRepositoryProvider).fetchHistory(year);
  },
);
