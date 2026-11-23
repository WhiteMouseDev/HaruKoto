import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/stats_history_model.dart';

class HeatmapWidget extends ConsumerStatefulWidget {
  const HeatmapWidget({
    super.key,
    required this.records,
    required this.year,
    required this.onYearChange,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
  });

  final List<StatsHistoryRecord> records;
  final int year;
  final ValueChanged<int> onYearChange;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  ConsumerState<HeatmapWidget> createState() => _HeatmapWidgetState();
}

class _HeatmapWidgetState extends ConsumerState<HeatmapWidget> {
  DateTime? _selected;

  @override
  void didUpdateWidget(covariant HeatmapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.year != oldWidget.year) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final border =
        light ? AppColors.redesignOutline : theme.colorScheme.outline;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted = light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final today = ref.watch(studyDateProvider);
    final available = !widget.isLoading && !widget.hasError;
    final records = <String, StatsHistoryRecord>{
      if (available)
        for (final record in widget.records)
          if (record.date.startsWith('${widget.year}-') &&
              record.date.compareTo(studyDateKey(today)) <= 0)
            record.date: record,
    };
    final learnedDays = records.values.where(_learned).length;
    final goalDays =
        records.values.where((record) => record.goalAchieved).length;
    final selected = _selected;
    final textScale = MediaQuery.textScalerOf(context);
    final cellHeight = math.max(16.0, textScale.scale(10) * 1.4 + 2);
    final monthHeight = math.max(16.0, textScale.scale(10) * 1.4 + 2);
    final legend = _heatmapText(10, muted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _YearArrow(
                        label: '이전 연도',
                        icon: LucideIcons.chevronLeft,
                        onPressed: widget.year > 1
                            ? () => widget.onYearChange(widget.year - 1)
                            : null,
                      ),
                      Text(
                        '${widget.year}',
                        style: _heatmapText(14, foreground,
                            weight: FontWeight.w600),
                      ),
                      _YearArrow(
                        label: '다음 연도',
                        icon: LucideIcons.chevronRight,
                        onPressed: widget.year < today.year
                            ? () => widget.onYearChange(widget.year + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                if (available)
                  _CalendarGrid(
                    year: widget.year,
                    today: today,
                    records: records,
                    selected: selected,
                    cellHeight: cellHeight,
                    monthHeight: monthHeight,
                    onSelected: (date) => setState(() => _selected = date),
                  )
                else
                  SizedBox(
                    height: cellHeight * DateTime.daysPerWeek + monthHeight,
                    child: Center(
                      child: widget.isLoading
                          ? const CircularProgressIndicator(
                              semanticsLabel: '학습 기록 불러오는 중',
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '학습 기록을 불러오지 못했어요',
                                  textAlign: TextAlign.center,
                                  style: _heatmapText(12, muted),
                                ),
                                if (widget.onRetry != null)
                                  TextButton(
                                    onPressed: widget.onRetry,
                                    child: const Text('다시 시도'),
                                  ),
                              ],
                            ),
                    ),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: textScale.scale(11) * 1.4),
                      child: available && selected != null
                          ? Text(
                              '${studyDateKey(selected)} (${_weekdays[selected.weekday - 1]}) · '
                              '${_dayStatus(records[studyDateKey(selected)])}',
                              textAlign: TextAlign.center,
                              style: _heatmapText(11, foreground),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _LegendItem(
                  label: '학습일',
                  color: AppColors.redesignVocabulary,
                  style: legend,
                ),
                _LegendItem(
                  label: '목표 달성일',
                  color: AppColors.brandPink,
                  style: legend,
                ),
              ],
            ),
            if (available)
              Text('총 $learnedDays일 · 목표 달성 $goalDays일', style: legend),
          ],
        ),
      ],
    );
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

bool _learned(StatsHistoryRecord record) =>
    record.hasStudyActivity || record.goalAchieved;

String _dayStatus(StatsHistoryRecord? record) {
  if (record == null) return '기록 없음';
  if (record.goalAchieved) return '목표 달성';
  return record.hasStudyActivity ? '학습일' : '기록 없음';
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.year,
    required this.today,
    required this.records,
    required this.selected,
    required this.cellHeight,
    required this.monthHeight,
    required this.onSelected,
  });

  final int year;
  final DateTime today;
  final Map<String, StatsHistoryRecord> records;
  final DateTime? selected;
  final double cellHeight;
  final double monthHeight;
  final ValueChanged<DateTime> onSelected;

  static const double _columnWidth = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final start = DateTime.utc(year);
    final firstMonday =
        start.subtract(Duration(days: start.weekday - DateTime.monday));
    final end = DateTime.utc(year, DateTime.december, 31);
    final weeks =
        end.difference(firstMonday).inDays ~/ DateTime.daysPerWeek + 1;
    final weekdayWidth =
        math.max(12.0, MediaQuery.textScalerOf(context).scale(10) + 2);

    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: weekdayWidth,
            child: Column(
              children: [
                for (final label in _weekdays)
                  SizedBox(
                    height: cellHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(label, style: _heatmapText(10, muted)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('heatmap-grid-$year'),
              scrollDirection: Axis.horizontal,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var week = 0; week < weeks; week++)
                          SizedBox(
                            width: _columnWidth,
                            child: Column(
                              children: [
                                for (var day = 0;
                                    day < DateTime.daysPerWeek;
                                    day++)
                                  _CalendarCell(
                                    date: firstMonday.add(Duration(
                                      days: week * DateTime.daysPerWeek + day,
                                    )),
                                    displayedYear: year,
                                    today: today,
                                    records: records,
                                    selected: selected,
                                    height: cellHeight,
                                    onSelected: onSelected,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      width: _columnWidth * weeks,
                      height: monthHeight,
                      child: Stack(
                        children: [
                          for (var month = 1;
                              month <= DateTime.monthsPerYear;
                              month++)
                            Positioned(
                              left: 2 +
                                  _columnWidth *
                                      (DateTime.utc(year, month)
                                              .difference(firstMonday)
                                              .inDays ~/
                                          DateTime.daysPerWeek),
                              top: 2,
                              child: Text('$month월',
                                  style: _heatmapText(10, muted)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.displayedYear,
    required this.today,
    required this.records,
    required this.selected,
    required this.height,
    required this.onSelected,
  });

  final DateTime date;
  final int displayedYear;
  final DateTime today;
  final Map<String, StatsHistoryRecord> records;
  final DateTime? selected;
  final double height;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    if (date.year != displayedYear) return SizedBox(height: height);
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final isSelected = selected == date;
    final key = studyDateKey(date);
    final future = date.isAfter(today);
    final record = records[key];
    final status = future ? '예정' : _dayStatus(record);
    final color = switch (status) {
      '목표 달성' => AppColors.brandPink,
      '학습일' => AppColors.redesignVocabulary,
      '예정' => light
          ? AppColors.redesignControl
          : theme.colorScheme.surfaceContainerLowest,
      _ => light
          ? AppColors.redesignOutline
          : theme.colorScheme.surfaceContainerHigh,
    };
    void select() => onSelected(date);

    return Semantics(
      container: true,
      label: '$key ${_weekdays[date.weekday - 1]}요일, $status',
      button: !future,
      selected: future ? null : isSelected,
      onTap: future ? null : select,
      child: ExcludeSemantics(
        child: InkWell(
          excludeFromSemantics: true,
          onTap: future ? null : select,
          child: SizedBox(
            height: height,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: color,
                  border: isSelected
                      ? Border.all(
                          color: light
                              ? AppColors.redesignForeground
                              : theme.colorScheme.onSurface,
                        )
                      : null,
                ),
                child: const SizedBox.square(dimension: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YearArrow extends StatelessWidget {
  const _YearArrow({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        visualDensity: VisualDensity.standard,
        foregroundColor:
            light ? AppColors.redesignStrong : theme.colorScheme.onSurface,
      ),
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: light
              ? AppColors.redesignControl
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SizedBox.square(
          dimension: 24,
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    required this.style,
  });

  final String label;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const SizedBox.square(dimension: 10),
          ),
          const SizedBox(width: 3),
          Text(label, style: style),
        ],
      );
}

TextStyle _heatmapText(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
}) =>
    TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: 1.4,
      letterSpacing: -size * 0.025,
      color: color,
    );
