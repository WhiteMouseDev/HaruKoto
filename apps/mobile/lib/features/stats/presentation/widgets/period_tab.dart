import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../home/data/models/dashboard_model.dart';
import '../../data/models/stats_history_model.dart';
import 'heatmap_widget.dart';
import 'stats_bar_chart.dart';

class PeriodTab extends ConsumerStatefulWidget {
  const PeriodTab({
    super.key,
    required this.today,
    this.questionStats,
    this.isDashboardLoading = false,
    required this.historyRecords,
    required this.heatmapYear,
    required this.onHeatmapYearChange,
    this.isHistoryLoading = false,
    this.hasHistoryError = false,
    this.onRetryHistory,
  });

  final TodayStats? today;
  final bool isDashboardLoading;
  final List<WeeklyQuestionStatEntry>? questionStats;
  final List<StatsHistoryRecord> historyRecords;
  final int heatmapYear;
  final ValueChanged<int>? onHeatmapYearChange;
  final bool isHistoryLoading;
  final bool hasHistoryError;
  final VoidCallback? onRetryHistory;

  @override
  ConsumerState<PeriodTab> createState() => _PeriodTabState();
}

class _PeriodTabState extends ConsumerState<PeriodTab> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(studyDateProvider);
    final week = _QuestionWeek(
      today: today,
      todayStats: widget.today,
      questionStats: widget.questionStats,
    );
    final selectedDay = week.days
            .where((day) => day.date == _selectedDate && day.total != null)
            .firstOrNull ??
        (week.today.total == null ? null : week.today);
    final first = week.days.first.date;
    final last = week.days.last.date;
    final theme = Theme.of(context);
    final foreground = theme.brightness == Brightness.light
        ? AppColors.redesignForeground
        : theme.colorScheme.onSurface;
    final titleStyle = _periodText(
      16,
      foreground,
      weight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('오늘의 학습', style: titleStyle),
        const SizedBox(height: 12),
        _QuestionSummary(
          today: week.today.total,
          week: week.total,
          isLoading: widget.isDashboardLoading,
        ),
        const SizedBox(height: 40),
        Text('요일별 문제풀이', style: titleStyle),
        const SizedBox(height: 12),
        StatsBarChart(
          dateRangeLabel:
              '${first.month}.${first.day}~${last.month}.${last.day}',
          days: week.days,
          isLoading: widget.isDashboardLoading,
          selectedDate: selectedDay?.date,
          today: today,
          onDateSelected: (date) {
            if (date == selectedDay?.date) return;
            HapticService().selection();
            setState(() => _selectedDate = date);
          },
          emptyMessage: week.days.any((day) => day.total != null)
              ? null
              : '문제풀이 집계를 확인할 수 없어요',
        ),
        if (widget.isDashboardLoading || selectedDay != null) ...[
          const SizedBox(height: 8),
          _DayQuestions(day: selectedDay),
        ],
        const SizedBox(height: 40),
        Text('연간 학습 히트맵', style: titleStyle),
        const SizedBox(height: 12),
        HeatmapWidget(
          records: widget.historyRecords,
          year: widget.heatmapYear,
          onYearChange: widget.onHeatmapYearChange,
          isLoading: widget.isHistoryLoading,
          hasError: widget.hasHistoryError,
          onRetry: widget.onRetryHistory,
        ),
      ],
    );
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

class _QuestionWeek {
  factory _QuestionWeek({
    required DateTime today,
    required TodayStats? todayStats,
    required List<WeeklyQuestionStatEntry>? questionStats,
  }) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final byDate = <String, StatsBarCounts>{
      for (final day in questionStats ?? const <WeeklyQuestionStatEntry>[])
        day.date: (
          vocabulary: day.vocabularyAnsweredCount,
          grammar: day.grammarAnsweredCount,
          sentences: day.sentenceArrangeAnsweredCount,
        ),
    };
    final goals = todayStats?.categoryGoals;
    final todayKey = studyDateKey(today);
    if (goals != null && goals.date == todayKey) {
      byDate.putIfAbsent(
        todayKey,
        () => (
          vocabulary: goals.vocabulary.answeredCount,
          grammar: goals.grammar.answeredCount,
          sentences: goals.sentence.answeredCount,
        ),
      );
    }

    return _QuestionWeek._(
      List.generate(DateTime.daysPerWeek, (index) {
        final date = monday.add(Duration(days: index));
        final future = date.isAfter(today);
        return StatsBarDay(
          date: date,
          label: _weekdays[index],
          isFuture: future,
          counts: future ? null : byDate[studyDateKey(date)],
        );
      }),
      today.weekday - 1,
    );
  }

  const _QuestionWeek._(this.days, this._todayIndex);

  final List<StatsBarDay> days;
  final int _todayIndex;

  StatsBarDay get today => days[_todayIndex];

  int? get total {
    var total = 0;
    for (final day in days.take(_todayIndex + 1)) {
      final count = day.total;
      if (count == null) return null;
      total += count;
    }
    return total;
  }
}

class _QuestionSummary extends StatelessWidget {
  const _QuestionSummary({
    required this.today,
    required this.week,
    required this.isLoading,
  });

  final int? today;
  final int? week;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.redesignSurface
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _QuestionMetric(
                count: today,
                isLoading: isLoading,
                label: '오늘 푼 문제',
                iconAsset: 'assets/icons/figma-stats-period-today.png',
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isLight
                  ? AppColors.redesignOutline
                  : theme.colorScheme.outline,
            ),
            Expanded(
              child: _QuestionMetric(
                count: week,
                isLoading: isLoading,
                label: '이번 주 푼 문제',
                iconAsset: 'assets/icons/figma-stats-period-week.png',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionMetric extends StatelessWidget {
  const _QuestionMetric({
    required this.count,
    required this.isLoading,
    required this.label,
    required this.iconAsset,
  });

  final int? count;
  final bool isLoading;
  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final foreground =
        isLight ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted = isLight
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;

    final status = isLoading
        ? '불러오는 중'
        : count == null
            ? '집계 확인 필요'
            : '$count문제';
    return Semantics(
      container: true,
      label: '$label, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconAsset,
              width: 24,
              height: 24,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 2),
            if (isLoading)
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(18) * 1.4,
                child: const Center(
                    child: AppSkeletonBlock(width: 46, height: 14)),
              )
            else
              Text.rich(
                TextSpan(
                  text: count == null ? '—' : '$count',
                  children: [
                    if (count != null)
                      TextSpan(
                        text: '문제',
                        style: _periodText(12, foreground),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: _periodText(18, foreground, weight: FontWeight.w600),
              ),
            const SizedBox(height: 1),
            Text(label,
                style: _periodText(12, muted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DayQuestions extends StatelessWidget {
  const _DayQuestions({required this.day});

  final StatsBarDay? day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final foreground =
        isLight ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted = isLight
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final day = this.day;
    final textScale = MediaQuery.textScalerOf(context);
    return Semantics(
      liveRegion: true,
      label: day == null ? '선택 날짜의 문제풀이를 불러오는 중' : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isLight ? AppColors.redesignOutline : theme.colorScheme.outline,
          ),
        ),
        child: Column(
          children: [
            if (day == null) ...[
              SizedBox(
                height: textScale.scale(14) * 1.4,
                child: const Center(
                    child: AppSkeletonBlock(width: 100, height: 12)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: textScale.scale(12) * 1.4,
                child: const Center(
                    child: AppSkeletonBlock(width: 142, height: 10)),
              ),
            ] else ...[
              Text(
                '${day.date.month}월 ${day.date.day}일 (${day.label}) · ${day.total}문제',
                textAlign: TextAlign.center,
                style: _periodText(14, foreground, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '단어 ${day.counts!.vocabulary} · 문법 ${day.counts!.grammar} · 문장배열 ${day.counts!.sentences}',
                textAlign: TextAlign.center,
                style: _periodText(12, muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

TextStyle _periodText(
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
