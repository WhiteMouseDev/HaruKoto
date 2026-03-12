import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../home/data/models/dashboard_model.dart';
import '../../data/models/heatmap_data_model.dart';
import '../../data/models/stats_history_model.dart';
import 'heatmap_widget.dart';
import 'stats_bar_chart.dart';

class PeriodTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayRecord = historyRecords.cast<StatsHistoryRecord?>().firstWhere(
      (r) => r?.date == todayStr,
      orElse: () => null,
    );
    final studyMinutes =
        todayRecord != null ? (todayRecord.studyTimeSeconds / 60).round() : 0;
    final totalQuizzes = today.quizzesCompleted;

    final heatmapRecords = historyRecords
        .map((r) => HeatmapData(date: r.date, wordsStudied: r.wordsStudied))
        .toList();

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
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
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

        // Bar Chart
        StatsBarChart(records: historyRecords),
      ],
    );
  }
}
