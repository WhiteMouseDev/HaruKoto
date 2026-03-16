import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../home/data/models/dashboard_model.dart';
import '../../data/models/heatmap_data_model.dart';
import '../../data/models/stats_history_model.dart';
import '../../data/models/time_chart_model.dart';
import '../../providers/stats_provider.dart';
import 'heatmap_widget.dart';
import 'stats_bar_chart.dart';

class PeriodTab extends ConsumerWidget {
  final TodayStats today;
  final List<StatsHistoryRecord> historyRecords;
  final int heatmapYear;
  final ValueChanged<int> onHeatmapYearChange;

  const PeriodTab({
    super.key,
    required this.today,
    required this.historyRecords,
    required this.heatmapYear,
    required this.onHeatmapYearChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayRecord = historyRecords.cast<StatsHistoryRecord?>().firstWhere(
          (r) => r?.date == todayStr,
          orElse: () => null,
        );
    final studyMinutes =
        todayRecord != null ? (todayRecord.studyTimeSeconds / 60).round() : 0;
    final totalQuizzes = today.quizzesCompleted;

    // Use heatmap API instead of deriving from history
    final heatmapAsync = ref.watch(heatmapProvider(heatmapYear));
    final heatmapRecords = heatmapAsync.when(
      data: (response) => response.data,
      loading: () => historyRecords
          .map((r) => HeatmapData(date: r.date, wordsStudied: r.wordsStudied))
          .toList(),
      error: (_, __) => historyRecords
          .map((r) => HeatmapData(date: r.date, wordsStudied: r.wordsStudied))
          .toList(),
    );

    // Use time-chart API for daily study minutes
    final timeChartAsync = ref.watch(timeChartProvider(7));

    return Column(
      children: [
        // Today's Summary
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 학습',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.clock,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '총 시간',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                Text(
                                  '$studyMinutes분',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.hkBlue(theme.brightness)
                                    .withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.fileText,
                                size: 20,
                                color: AppColors.hkBlue(theme.brightness),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '총 문제',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                Text(
                                  '$totalQuizzes개',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),

        // Heatmap
        HeatmapWidget(
          records: heatmapRecords,
          year: heatmapYear,
          onYearChange: onHeatmapYearChange,
        ),
        const SizedBox(height: AppSizes.md),

        // Time Chart (daily study minutes for last 7 days)
        timeChartAsync.when(
          data: (response) => _TimeChartCard(entries: response.data),
          loading: () => const _TimeChartCard(entries: []),
          error: (_, __) => const _TimeChartCard(entries: []),
        ),
        const SizedBox(height: AppSizes.md),

        // Bar Chart (existing, from history)
        StatsBarChart(records: historyRecords),
      ],
    );
  }
}

class _TimeChartCard extends StatelessWidget {
  final List<TimeChartEntry> entries;

  const _TimeChartCard({required this.entries});

  static const double _chartHeight = 120;
  static const double _minBarPx = 16;
  static const double _maxBarPx = _chartHeight - 20;

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes분';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder > 0 ? '$hours시간 $remainder분' : '$hours시간';
  }

  String _formatDateLabel(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length >= 3) {
      return '${int.parse(parts[1])}/${int.parse(parts[2])}';
    }
    return dateStr;
  }

  double _calcBarPx(int value, int maxValue) {
    if (value <= 0) return 0;
    if (maxValue <= 0) return _minBarPx;
    final ratio = value / maxValue;
    final scaled = math.sqrt(ratio) * _maxBarPx;
    return scaled.clamp(_minBarPx, _maxBarPx);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '일별 학습 시간 (최근 7일)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '데이터를 불러오는 중...',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    final maxMinutes =
        entries.fold<int>(1, (m, e) => e.minutes > m ? e.minutes : m);
    final totalMinutes = entries.fold<int>(0, (s, e) => s + e.minutes);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '일별 학습 시간 (최근 7일)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: entries.map((entry) {
                  final minutes = entry.minutes;
                  final barPx = _calcBarPx(minutes, maxMinutes);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (minutes > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                _formatMinutes(minutes),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                              ),
                            ),
                          Container(
                            height: minutes > 0 ? barPx : 3,
                            decoration: BoxDecoration(
                              color: minutes > 0
                                  ? AppColors.hkBlue(theme.brightness)
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: entries.map((entry) {
                return Expanded(
                  child: Text(
                    _formatDateLabel(entry.date),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text.rich(
                TextSpan(
                  text: '7일 총 학습 시간 ',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  children: [
                    TextSpan(
                      text: _formatMinutes(totalMinutes),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
