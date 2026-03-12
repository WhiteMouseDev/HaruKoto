import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'models/stats_history_model.dart';

class StatsRepository {
  final Dio _dio;

  StatsRepository(this._dio);

  Future<List<StatsHistoryRecord>> fetchHistory(int year) async {
    final now = DateTime.now();
    final currentYear = now.year;
    final maxMonth = year == currentYear ? now.month : 12;

    final futures = List.generate(maxMonth, (i) async {
      final month = i + 1;
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/stats/history',
          queryParameters: {'year': year, 'month': month},
        );
        final records = response.data?['records'] as List<dynamic>? ?? [];
        return records
            .map((e) => StatsHistoryRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        Sentry.captureException(e, stackTrace: StackTrace.current);
        return <StatsHistoryRecord>[];
      }
    });

    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }
}
