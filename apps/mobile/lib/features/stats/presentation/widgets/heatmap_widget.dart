import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/heatmap_data_model.dart';

class HeatmapWidget extends StatefulWidget {
  final List<HeatmapData> records;
  final int year;
  final ValueChanged<int> onYearChange;

  const HeatmapWidget({
    super.key,
    required this.records,
    required this.year,
    required this.onYearChange,
  });

  @override
  State<HeatmapWidget> createState() => _HeatmapWidgetState();
}

class _HeatmapWidgetState extends State<HeatmapWidget> {
  String? _hoveredDate;

  static const double _cellSize = 11;
  static const double _gap = 3;

  List<Color> _getIntensityColors(BuildContext context) {
    return AppColors.heatmapColors(Theme.of(context).brightness);
  }

  int _getIntensity(int count, int maxCount) {
    if (count == 0 || maxCount == 0) return 0;
    final ratio = count / maxCount;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  DateTime _getGridStart(int year) {
    final startDate = DateTime.utc(year, 1, 1);
    final startDay = startDate.weekday; // Mon=1, Sun=7
    final mondayOffset = 1 - startDay;
    return startDate.add(Duration(days: mondayOffset));
  }

  List<DayCell> _buildYearGrid() {
    final recordMap = <String, int>{};
    for (final r in widget.records) {
      recordMap[r.date] = r.wordsStudied;
    }

    final endDate = DateTime.utc(widget.year, 12, 31);
    final gridStart = _getGridStart(widget.year);
    final cells = <DayCell>[];
    var current = gridStart;
    var weekIndex = 0;

    while (!current.isAfter(endDate)) {
      final dayIndex = (current.weekday - 1) % 7; // Mon=0
      final dateStr =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';

      cells.add(DayCell(
        date: dateStr,
        count: recordMap[dateStr] ?? 0,
        weekIndex: weekIndex,
        dayIndex: dayIndex,
      ));

      current = current.add(const Duration(days: 1));
      if (current.weekday == 1) weekIndex++;
      if (weekIndex > 53) break;
    }

    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intensityColors = _getIntensityColors(context);
    final cells = _buildYearGrid();

    if (cells.isEmpty) return const SizedBox.shrink();

    final maxCount = cells.fold<int>(1, (m, c) => c.count > m ? c.count : m);
    final totalWeeks = cells.fold<int>(0, (m, c) => c.weekIndex > m ? c.weekIndex : m) + 1;
    final totalStudied = cells.fold<int>(0, (s, c) => s + c.count);
    final activeDays = cells.where((c) => c.count > 0).length;
    final currentYear = DateTime.now().year;

    // Build week columns
    final weekColumns = <List<DayCell?>>[];
    for (var wi = 0; wi < totalWeeks; wi++) {
      final column = <DayCell?>[];
      for (var di = 0; di < 7; di++) {
        final match = cells.cast<DayCell?>().firstWhere(
          (c) => c != null && c.weekIndex == wi && c.dayIndex == di,
          orElse: () => null,
        );
        column.add(match);
      }
      weekColumns.add(column);
    }

    final hoveredCell = _hoveredDate != null
        ? cells.cast<DayCell?>().firstWhere(
            (c) => c?.date == _hoveredDate,
            orElse: () => null,
          )
        : null;

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
                  '연간 학습 히트맵',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => widget.onYearChange(widget.year - 1),
                      child: Icon(
                        LucideIcons.chevronLeft,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${widget.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.year >= currentYear
                          ? null
                          : () => widget.onYearChange(widget.year + 1),
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: widget.year >= currentYear
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.15)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Heatmap grid
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day labels
                  Column(
                    children: ['월', '', '수', '', '금', '', ''].map((label) {
                      return SizedBox(
                        width: 20,
                        height: _cellSize + _gap,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Week columns
                  ...weekColumns.map((column) {
                    return Padding(
                      padding: const EdgeInsets.only(right: _gap),
                      child: Column(
                        children: column.map((cell) {
                          if (cell == null) {
                            return SizedBox(
                              width: _cellSize,
                              height: _cellSize + _gap,
                            );
                          }
                          final intensity = _getIntensity(cell.count, maxCount);
                          return GestureDetector(
                            onTapDown: (_) {
                              setState(() => _hoveredDate = cell.date);
                            },
                            onTapUp: (_) {
                              Future.delayed(
                                const Duration(seconds: 2),
                                () {
                                  if (mounted) {
                                    setState(() => _hoveredDate = null);
                                  }
                                },
                              );
                            },
                            child: Container(
                              width: _cellSize,
                              height: _cellSize,
                              margin: const EdgeInsets.only(bottom: _gap),
                              decoration: BoxDecoration(
                                color: intensityColors[intensity],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Tooltip
            SizedBox(
              height: 20,
              child: Center(
                child: Text(
                  hoveredCell != null
                      ? '${hoveredCell.date} · ${hoveredCell.count}개 학습'
                      : '',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

            // Legend + Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Less',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ...intensityColors.map((color) {
                      return Container(
                        width: _cellSize,
                        height: _cellSize,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                    const SizedBox(width: 2),
                    Text(
                      'More',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                Text(
                  '총 $totalStudied개 · $activeDays일 학습',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
