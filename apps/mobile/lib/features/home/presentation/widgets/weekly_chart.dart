import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/dashboard_model.dart';

class WeeklyChart extends StatefulWidget {
  const WeeklyChart({
    super.key,
    required this.weeklyStats,
    this.questionStats,
    this.studyDate,
    this.isLoading = false,
    this.hasError = false,
  });

  final List<WeeklyStatEntry> weeklyStats;
  final List<WeeklyQuestionStatEntry>? questionStats;
  final DateTime? studyDate;
  final bool isLoading;
  final bool hasError;

  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart> {
  String? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = widget.studyDate ?? studyDateInKorea(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final dates =
        List.generate(7, (index) => monday.add(Duration(days: index)));
    final elapsedDates = dates.where((date) => !date.isAfter(today));
    final questionsByDate = {
      for (final day in widget.questionStats ?? <WeeklyQuestionStatEntry>[])
        day.date: day,
    };
    final hasQuestions = elapsedDates.every(
      (date) => questionsByDate.containsKey(studyDateKey(date)),
    );
    final week = [
      for (final date in dates)
        if (date.isAfter(today)) null else questionsByDate[studyDateKey(date)],
    ];
    final knownDays = week.whereType<WeeklyQuestionStatEntry>();
    final total =
        hasQuestions ? knownDays.fold(0, (n, day) => n + _count(day)) : null;
    final legacyByDate = {for (final day in widget.weeklyStats) day.date: day};
    final legacyDaysKnown = elapsedDates.every(
      (date) => legacyByDate.containsKey(studyDateKey(date)),
    );
    final studyDays = hasQuestions
        ? knownDays.where((day) => day.hasStudied).length
        : legacyDaysKnown
            ? elapsedDates
                .where((date) => legacyByDate[studyDateKey(date)]!.hasStudied)
                .length
            : null;
    final maxDaily = hasQuestions
        ? knownDays.fold(0, (maximum, day) => math.max(maximum, _count(day)))
        : 0;
    final showExamples = total == 0;
    final message = switch ((
      hasQuestions,
      total,
      studyDays,
      widget.isLoading,
      widget.hasError
    )) {
      (true, 0, 0, _, _) => '이번 주 학습 기록이 아직 없어요',
      (true, 0, _, _, _) => '이번 주 문제풀이 기록은 아직 없어요',
      (true, _, _, _, _) => null,
      (false, _, _, true, _) => '주간 학습 기록을 불러오는 중이에요',
      (false, _, _, _, true) => '주간 학습 기록을 불러오지 못했어요',
      _ => '주간 문제풀이 기록을 확인할 수 없어요',
    };
    final selectedIndex =
        dates.indexWhere((date) => studyDateKey(date) == _selectedDate);
    final selected =
        hasQuestions && selectedIndex >= 0 ? week[selectedIndex] : null;

    return Padding(
      padding: AppSizes.pageHorizontalEdge,
      child: Column(
        children: [
          Text(
            '주간 학습',
            style: _chartText(theme, 20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 21, 24, 20),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? AppColors.redesignSurface
                  : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${monday.month}.${monday.day}~${dates.last.month}.${dates.last.day}',
                        style: _chartText(theme, 11),
                      ),
                      const _ChartLegend(),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final plotHeight = 132 + math.max(0.0, largeText - 1) * 78;
                    final popupWidth =
                        math.min(132.0 * largeText, constraints.maxWidth - 8);
                    final targetX =
                        (selectedIndex + 0.5) * constraints.maxWidth / 7;
                    final popupLeft = (targetX - popupWidth / 2)
                        .clamp(4.0, constraints.maxWidth - popupWidth - 4);
                    return Stack(
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < dates.length; i++)
                              Expanded(
                                child: _WeeklyDay(
                                  date: dates[i],
                                  column: i,
                                  today: today,
                                  stats: hasQuestions ? week[i] : null,
                                  maxDaily: maxDaily,
                                  plotHeight: plotHeight,
                                  showExample: showExamples,
                                  selected:
                                      selected != null && selectedIndex == i,
                                  onTap: hasQuestions && week[i] != null
                                      ? () {
                                          HapticService().selection();
                                          final key = studyDateKey(dates[i]);
                                          setState(() => _selectedDate =
                                              _selectedDate == key
                                                  ? null
                                                  : key);
                                        }
                                      : null,
                                ),
                              ),
                          ],
                        ),
                        if (message != null && selected == null)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: plotHeight,
                            child: IgnorePointer(
                              child: Align(
                                alignment: showExamples
                                    ? const Alignment(0, 0.38)
                                    : Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      message,
                                      textAlign: TextAlign.center,
                                      style: _chartText(theme, 14,
                                          weight: FontWeight.w600),
                                    ),
                                    if (showExamples && studyDays == 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '오늘 단어 1개만 학습해도 그래프가 채워져요!',
                                        textAlign: TextAlign.center,
                                        style: _chartText(
                                          theme,
                                          13,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (selected != null)
                          Positioned(
                            top: 0,
                            left: popupLeft,
                            width: popupWidth,
                            child: IgnorePointer(
                              child: _DayBreakdown(
                                date: dates[selectedIndex],
                                day: selected,
                                pointerX: (targetX - popupLeft)
                                    .clamp(8.0, popupWidth - 8),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _WeekTotals(total: total, studyDays: studyDays),
              ],
            ),
          ),
          const SizedBox(height: 11),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 6),
              shape: const StadiumBorder(),
              foregroundColor: _chartForeground(theme),
              side: BorderSide(color: _chartBorder(theme)),
              textStyle: _chartText(theme, 13, weight: FontWeight.w600),
            ),
            onPressed: () {
              HapticService().selection();
              context.push('/stats');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Flexible(child: Text('학습 통계 자세히 보기')),
                const SizedBox(width: 6),
                SizedBox.square(
                  dimension: 16,
                  child: Center(
                    child: Image.asset(
                      'assets/icons/figma-home-arrow.png',
                      width: 6.25,
                      height: 11,
                      color: theme.brightness == Brightness.light
                          ? null
                          : theme.colorScheme.onSurface,
                      excludeFromSemantics: true,
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

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
const _wordColor = AppColors.redesignVocabulary;
const _grammarColor = AppColors.redesignGrammar;
const _sentenceColor = AppColors.redesignSentence;

Color _chartBorder(ThemeData theme) => theme.brightness == Brightness.light
    ? AppColors.redesignOutline
    : theme.colorScheme.outline;

Color _chartForeground(ThemeData theme) => theme.brightness == Brightness.light
    ? AppColors.redesignForeground
    : theme.colorScheme.onSurface;

Color _chartSecondary(ThemeData theme) => theme.brightness == Brightness.light
    ? const Color(0xFF666666)
    : theme.colorScheme.onSurfaceVariant;

TextStyle? _chartText(
  ThemeData theme,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
}) =>
    theme.textTheme.bodyMedium?.copyWith(
      fontFamily: redesignFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: 1.4,
      letterSpacing: -0.025 * size,
      color: color ?? _chartForeground(theme),
    );

int _count(WeeklyQuestionStatEntry day) =>
    day.vocabularyAnsweredCount +
    day.grammarAnsweredCount +
    day.sentenceArrangeAnsweredCount;

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('단어', _wordColor),
      ('문법', _grammarColor),
      ('문장배열', _sentenceColor),
    ];
    final theme = Theme.of(context);
    return Wrap(
      spacing: 9,
      runSpacing: 4,
      children: [
        for (final (label, color) in items)
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
              Text(label, style: _chartText(theme, 11)),
            ],
          ),
      ],
    );
  }
}

class _WeeklyDay extends StatelessWidget {
  const _WeeklyDay({
    required this.date,
    required this.column,
    required this.today,
    required this.stats,
    required this.maxDaily,
    required this.plotHeight,
    required this.showExample,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final int column;
  final DateTime today;
  final WeeklyQuestionStatEntry? stats;
  final int maxDaily;
  final double plotHeight;
  final bool showExample;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = stats;
    final key = studyDateKey(date);
    final future = date.isAfter(today);
    final isToday = date == today;
    final total = day == null ? null : _count(day);
    final muted = _chartSecondary(theme);
    final placeholder = theme.brightness == Brightness.light
        ? const Color(0xFFEFEFF3)
        : theme.colorScheme.surfaceContainerHighest;
    const exampleHeights = [92.0, 132.0, 72.0, 72.0, 92.0, 72.0, 92.0];
    final hasBar = total != null && total > 0;
    final status = total != null
        ? '$total문제${day!.hasStudied ? ', 학습한 날' : ', 학습일 기록 없음'}'
        : future
            ? '예정'
            : '기록 확인 중';
    return Semantics(
      label: '$key ${_weekdays[column]}요일${isToday ? ', 오늘' : ''}, $status',
      button: onTap != null,
      selected: onTap == null ? null : selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('weekly-day-$key'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              SizedBox(
                height: plotHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: showExample
                      ? Container(
                          width: 12,
                          height: exampleHeights[column],
                          decoration: BoxDecoration(
                            color: placeholder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      : hasBar
                          ? _StackedBar(
                              key: ValueKey('weekly-question-bar-$key'),
                              day: day!,
                              height: plotHeight * total / maxDaily,
                            )
                          : total == 0
                              ? Container(
                                  key: ValueKey('weekly-zero-bar-$key'),
                                  width: 12,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: muted.withValues(alpha: 0.52),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                )
                              : null,
                ),
              ),
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: !selected
                      ? null
                      : theme.brightness == Brightness.light
                          ? const Color(0xFFD9D9DD)
                          : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 18),
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1,
                    child: Text(
                      _weekdays[column],
                      style: _chartText(
                        theme,
                        11,
                        weight: isToday || selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: showExample
                            ? muted.withValues(alpha: 0.25)
                            : future
                                ? muted
                                : _chartForeground(theme),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 4,
                child: isToday && !showExample && stats != null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Color(0xFFFF6A87)),
                        child: SizedBox(width: 4),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({super.key, required this.day, required this.height});

  final WeeklyQuestionStatEntry day;
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
            if (day.vocabularyAnsweredCount > 0)
              Expanded(
                  flex: day.vocabularyAnsweredCount,
                  child: const ColoredBox(color: _wordColor)),
            if (day.grammarAnsweredCount > 0)
              Expanded(
                  flex: day.grammarAnsweredCount,
                  child: const ColoredBox(color: _grammarColor)),
            if (day.sentenceArrangeAnsweredCount > 0)
              Expanded(
                  flex: day.sentenceArrangeAnsweredCount,
                  child: const ColoredBox(color: _sentenceColor)),
          ],
        ),
      ),
    );
  }
}

class _DayBreakdown extends StatelessWidget {
  const _DayBreakdown({
    required this.date,
    required this.day,
    required this.pointerX,
  });

  final DateTime date;
  final WeeklyQuestionStatEntry day;
  final double pointerX;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerLowest;
    final title =
        '${date.month}월 ${date.day}일 (${_weekdays[date.weekday - 1]})';
    return Semantics(
      liveRegion: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: pointerX - 4,
            bottom: -3,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: ColoredBox(
                  color: surface, child: const SizedBox.square(dimension: 8)),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 10)
              ],
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$title · ${_count(day)}문제',
                      style: _chartText(theme, 11, weight: FontWeight.w600)),
                  Text(
                      '단어 ${day.vocabularyAnsweredCount} · 문법 ${day.grammarAnsweredCount} · 문장배열 ${day.sentenceArrangeAnsweredCount}',
                      style:
                          _chartText(theme, 11, color: _chartSecondary(theme))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekTotals extends StatelessWidget {
  const _WeekTotals({required this.total, required this.studyDays});

  final int? total;
  final int? studyDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerLowest;
    final muted = _chartSecondary(theme);
    Widget metric(String label, String value, int? count) {
      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(label, style: _chartText(theme, 13, color: muted)),
          Text(value,
              style: _chartText(theme, 13,
                  color: count == null || count == 0
                      ? muted
                      : theme.colorScheme.onSurface,
                  weight: FontWeight.w600)),
        ],
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      color: surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: metric('문제풀이', total == null ? '—' : '$total개', total)),
          const SizedBox(width: 8),
          Container(width: 1, height: 10, color: _chartBorder(theme)),
          const SizedBox(width: 8),
          Expanded(
              child: metric(
                  '학습일', studyDays == null ? '—' : '$studyDays일', studyDays)),
        ],
      ),
    );
  }
}
