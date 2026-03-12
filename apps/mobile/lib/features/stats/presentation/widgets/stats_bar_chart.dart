import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/stats_history_model.dart';

enum BarChartViewMode { week, month, year }

class _BarData {
  final String label;
  final int value; // seconds

  const _BarData({required this.label, required this.value});
}

class StatsBarChart extends StatefulWidget {
  final List<StatsHistoryRecord> records;

  const StatsBarChart({super.key, required this.records});

  @override
  State<StatsBarChart> createState() => _StatsBarChartState();
}

class _StatsBarChartState extends State<StatsBarChart> {
  BarChartViewMode _viewMode = BarChartViewMode.week;

  static const double _chartHeight = 120;
  static const double _minBarPx = 16;
  static const double _maxBarPx = _chartHeight - 20;

  String _formatMinutes(int seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins분';
    final hours = mins ~/ 60;
    final remainder = mins % 60;
    return remainder > 0 ? '$hours시간 $remainder분' : '$hours시간';
  }

  double _calcBarPx(int value, int maxValue) {
    if (value <= 0) return 0;
    if (maxValue <= 0) return _minBarPx;
    final ratio = value / maxValue;
    final scaled = math.sqrt(ratio) * _maxBarPx;
    return scaled.clamp(_minBarPx, _maxBarPx);
  }

  List<_BarData> _getWeekBars() {
    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final today = DateTime.now();
    final dayOfWeek = today.weekday; // Mon=1
    final monday = today.subtract(Duration(days: dayOfWeek - 1));

    return List.generate(7, (i) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final record = widget.records.cast<StatsHistoryRecord?>().firstWhere(
        (r) => r?.date == dateStr,
        orElse: () => null,
      );
      return _BarData(label: dayLabels[i], value: record?.studyTimeSeconds ?? 0);
    });
  }

  List<_BarData> _getMonthBars() {
    final today = DateTime.now();
    return List.generate(5, (w) {
      final weekEnd = today.subtract(Duration(days: (4 - w) * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));
      var totalSeconds = 0;
      for (final r in widget.records) {
        final parts = r.date.split('-');
        if (parts.length == 3) {
          final rDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          if (!rDate.isBefore(weekStart) && !rDate.isAfter(weekEnd)) {
            totalSeconds += r.studyTimeSeconds;
          }
        }
      }
      return _BarData(
        label: '${weekStart.month}/${weekStart.day}',
        value: totalSeconds,
      );
    });
  }

  List<_BarData> _getYearBars() {
    const monthLabels = [
      '1월', '2월', '3월', '4월', '5월', '6월',
      '7월', '8월', '9월', '10월', '11월', '12월',
    ];
    final monthTotals = List<int>.filled(12, 0);
    for (final r in widget.records) {
      final parts = r.date.split('-');
      if (parts.length >= 2) {
        final month = int.parse(parts[1]) - 1;
        if (month >= 0 && month < 12) {
          monthTotals[month] += r.studyTimeSeconds;
        }
      }
    }
    return List.generate(
      12,
      (i) => _BarData(label: monthLabels[i], value: monthTotals[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bars = switch (_viewMode) {
      BarChartViewMode.week => _getWeekBars(),
      BarChartViewMode.month => _getMonthBars(),
      BarChartViewMode.year => _getYearBars(),
    };

    final maxValue = bars.fold<int>(1, (m, b) => b.value > m ? b.value : m);
    final totalSeconds = bars.fold<int>(0, (s, b) => s + b.value);

    const viewModes = [
      (BarChartViewMode.week, '주'),
      (BarChartViewMode.month, '월'),
      (BarChartViewMode.year, '년'),
    ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '학습 시간',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    children: viewModes.map((mode) {
                      final isSelected = _viewMode == mode.$1;
                      return GestureDetector(
                        onTap: () => setState(() => _viewMode = mode.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            mode.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chart
            SizedBox(
              height: _chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars.map((bar) {
                  final barPx = _calcBarPx(bar.value, maxValue);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (bar.value > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                _formatMinutes(bar.value),
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
                            height: bar.value > 0 ? barPx : 3,
                            decoration: BoxDecoration(
                              color: bar.value > 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.1),
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

            // Labels
            Row(
              children: bars.map((bar) {
                return Expanded(
                  child: Text(
                    bar.label,
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

            // Total
            Center(
              child: Text.rich(
                TextSpan(
                  text: '총 학습 시간 ',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  children: [
                    TextSpan(
                      text: _formatMinutes(totalSeconds),
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
