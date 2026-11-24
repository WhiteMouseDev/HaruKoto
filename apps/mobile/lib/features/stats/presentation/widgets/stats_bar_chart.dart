import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_skeleton.dart';

typedef StatsBarCounts = ({int vocabulary, int grammar, int sentences});

class StatsBarDay {
  const StatsBarDay({
    required this.date,
    required this.label,
    required this.counts,
    this.isFuture = false,
  });

  final DateTime date;
  final String label;
  final StatsBarCounts? counts;
  final bool isFuture;

  int? get total {
    final values = counts;
    if (isFuture || values == null) return null;
    return values.vocabulary + values.grammar + values.sentences;
  }
}

class StatsBarChart extends StatelessWidget {
  const StatsBarChart({
    super.key,
    required this.dateRangeLabel,
    required this.days,
    this.selectedDate,
    this.today,
    this.onDateSelected,
    this.emptyMessage,
    this.isLoading = false,
  });

  final String dateRangeLabel;
  final List<StatsBarDay> days;
  final DateTime? selectedDate;
  final DateTime? today;
  final ValueChanged<DateTime>? onDateSelected;
  final String? emptyMessage;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final foreground =
        isLight ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted = isLight
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final maxCount = days.fold(0, (max, day) => math.max(max, day.total ?? 0));
    final extraTextScale =
        math.max(0.0, MediaQuery.textScalerOf(context).scale(14) / 14 - 1);
    final plotHeight = 132 + extraTextScale * 64;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.redesignSurface
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(dateRangeLabel, style: _labelStyle(foreground)),
              _ChartLegend(foreground: foreground),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: isLoading ? '문제풀이 그래프를 불러오는 중' : null,
            excludeSemantics: isLoading,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (final day in days)
                      Expanded(
                        child: _DayColumn(
                          day: day,
                          selected: day.date == selectedDate,
                          isToday: day.date == today,
                          plotHeight: plotHeight,
                          maxCount: maxCount,
                          foreground: foreground,
                          muted: muted,
                          isLoading: isLoading,
                          onTap: !isLoading &&
                                  onDateSelected != null &&
                                  day.total != null
                              ? () => onDateSelected!(day.date)
                              : null,
                        ),
                      ),
                  ],
                ),
                if (!isLoading && emptyMessage != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: plotHeight,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          emptyMessage!,
                          textAlign: TextAlign.center,
                          style: _labelStyle(muted, size: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _labelStyle(
  Color color, {
  double size = 11,
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

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.foreground});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    const legend = [
      ('단어', AppColors.redesignVocabulary),
      ('문법', AppColors.redesignGrammar),
      ('문장배열', AppColors.redesignSentence),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final (label, color) in legend)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 2),
              Text(label, style: _labelStyle(foreground)),
            ],
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.plotHeight,
    required this.maxCount,
    required this.foreground,
    required this.muted,
    required this.onTap,
    required this.isLoading,
  });

  final StatsBarDay day;
  final bool selected;
  final bool isToday;
  final double plotHeight;
  final int maxCount;
  final Color foreground;
  final Color muted;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final total = day.total;
    final weekday = _weekdays[day.date.weekday - DateTime.monday];
    final status = switch (total) {
      final count? => '$count문제',
      null => day.isFuture ? '예정' : '집계 확인 필요',
    };
    final column = Column(
      children: [
        SizedBox(
          height: plotHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: isLoading
                ? (day.isFuture
                    ? null
                    : const AppSkeletonBlock(width: 12, height: 64, radius: 4))
                : switch (total) {
                    0 => Container(
                        key: ValueKey('stats-zero-${studyDateKey(day.date)}'),
                        width: 12,
                        height: 1,
                        color: muted,
                      ),
                    final count? => _StackedBar(
                        key: ValueKey('stats-bar-${studyDateKey(day.date)}'),
                        counts: day.counts!,
                        height: plotHeight * count / maxCount,
                      ),
                    null => null,
                  },
          ),
        ),
        const SizedBox(height: 4),
        Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 18),
          decoration: selected
              ? BoxDecoration(
                  color: isLight
                      ? const Color(0xFFD9D9DD)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            day.label,
            textAlign: TextAlign.center,
            style: _labelStyle(
              day.isFuture || total == null ? muted : foreground,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 4,
          child: isToday
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brandPink,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 4),
                )
              : null,
        ),
      ],
    );

    return Semantics(
      container: true,
      label: '${studyDateKey(day.date)} $weekday요일, $status',
      button: onTap != null,
      selected: onTap == null ? null : selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: onTap == null
            ? column
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  excludeFromSemantics: true,
                  onTap: onTap,
                  child: column,
                ),
              ),
      ),
    );
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

class _StackedBar extends StatelessWidget {
  const _StackedBar({super.key, required this.counts, required this.height});

  final StatsBarCounts counts;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 12,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (counts.vocabulary > 0)
              Expanded(
                flex: counts.vocabulary,
                child: const ColoredBox(color: AppColors.redesignVocabulary),
              ),
            if (counts.grammar > 0)
              Expanded(
                flex: counts.grammar,
                child: const ColoredBox(color: AppColors.redesignGrammar),
              ),
            if (counts.sentences > 0)
              Expanded(
                flex: counts.sentences,
                child: const ColoredBox(color: AppColors.redesignSentence),
              ),
          ],
        ),
      ),
    );
  }
}
