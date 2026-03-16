import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'models/by_category_model.dart';
import 'models/heatmap_data_model.dart';
import 'models/level_progress_model.dart';
import 'models/stats_history_model.dart';
import 'models/time_chart_model.dart';
import 'models/volume_chart_model.dart';

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
        unawaited(Sentry.captureException(e, stackTrace: StackTrace.current));
        return <StatsHistoryRecord>[];
      }
    });

    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }

  Future<HeatmapResponse> fetchHeatmap(int year, {int? month}) async {
    try {
      final params = <String, dynamic>{'year': year};
      if (month != null) params['month'] = month;
      final response = await _dio.get<Map<String, dynamic>>(
        '/stats/heatmap',
        queryParameters: params,
      );
      return HeatmapResponse.fromJson(response.data ?? {});
    } catch (e) {
      unawaited(Sentry.captureException(e, stackTrace: StackTrace.current));
      return const HeatmapResponse(data: []);
    }
  }

  Future<JlptProgressResponse> fetchJlptProgress() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/stats/jlpt-progress',
      );
      return JlptProgressResponse.fromJson(response.data ?? {});
    } catch (e) {
      unawaited(Sentry.captureException(e, stackTrace: StackTrace.current));
      return const JlptProgressResponse(levels: []);
    }
  }

  Future<TimeChartResponse> fetchTimeChart(int days) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/stats/time-chart',
        queryParameters: {'days': days},
      );
      return TimeChartResponse.fromJson(response.data ?? {});
    } catch (e) {
      unawaited(Sentry.captureException(e, stackTrace: StackTrace.current));
      return const TimeChartResponse(data: []);
    }
  }

  Future<VolumeChartResponse> fetchVolumeChart(int days) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/stats/volume-chart',
        queryParameters: {'days': days},
      );
      return VolumeChartResponse.fromJson(response.data ?? {});
    } catch (e) {
      unawaited(Sentry.captureException(e, stackTrace: StackTrace.current));
      return const VolumeChartResponse(data: []);
    }
  }

  Future<ByCategoryResponse> fetchByCategory() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/stats/by-category',
      );
      return ByCategoryResponse.fromJson(response.data ?? {});
    } catch (e) {
      unawaited(Sentry.captureException(e, stackTrace: StackTrace.current));
      return const ByCategoryResponse(
        vocabulary: CategoryStats(total: 0, daily: []),
        grammar: CategoryStats(total: 0, daily: []),
        sentences: CategoryStats(total: 0, daily: []),
      );
    }
  }
}
