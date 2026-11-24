import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../stats/providers/stats_provider.dart';
import '../../data/models/dashboard_model.dart';
import '../../providers/home_provider.dart';

class StreakDailyCard extends ConsumerWidget {
  const StreakDailyCard({
    super.key,
    required this.streak,
    required this.today,
    required this.weeklyStats,
    required this.dailyGoal,
  });

  final StreakData streak;
  final TodayStats today;
  final List<WeeklyStatEntry> weeklyStats;
  final int dailyGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owner = ref.watch(currentAccountIdProvider);
    if (owner == null || ref.watch(currentAccountReaderProvider)() != owner) {
      return const SizedBox.shrink();
    }
    final date = ref.watch(studyDateProvider);
    final (title, description) = _streakCopy(streak);
    final isLight = theme.brightness == Brightness.light;
    void openCalendar() {
      if (!context.mounted ||
          ref.read(currentAccountIdProvider) != owner ||
          ref.read(currentAccountReaderProvider)() != owner) {
        return;
      }
      HapticService().light();
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        shape: AppSizes.sheetShape,
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) => DraggableScrollableSheet(
            initialChildSize: (550 / constraints.maxHeight).clamp(0.4, 0.9),
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, controller) => _CalendarSheetContent(
              scrollController: controller,
              accountId: owner,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal),
      child: Semantics(
        key: const ValueKey('streak-calendar-action'),
        container: true,
        explicitChildNodes: true,
        button: true,
        label: '$title. $description. 학습 기록 보기',
        onTap: openCalendar,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: isLight
                ? const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 8),
                  ]
                : null,
          ),
          child: Material(
            color: theme.colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isLight
                    ? const Color(0xFFF1F1F5)
                    : theme.colorScheme.outline,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              excludeFromSemantics: true,
              onTap: openCalendar,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: _StreakStrip(
                  streak: streak,
                  today: date,
                  weeklyStats: weeklyStats,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

(String, String) _streakCopy(StreakData streak) {
  if (streak.studiedToday) {
    return (
      streak.current > 0 ? '${streak.current}일 연속 학습' : '오늘도 학습했어요',
      streak.current > 0 ? '오늘도 학습했어요 · 내일도 이어가요' : '오늘의 학습 기록을 남겼어요',
    );
  }
  if (streak.current > 0) {
    return (
      '${streak.current}일 연속 학습',
      '어제까지의 기록 · 오늘 학습하면 ${streak.current + 1}일'
    );
  }
  if (streak.longest > 0) {
    return ('오늘부터 다시 시작해요', '오늘 한 문제부터 시작해보세요');
  }
  return ('첫 학습을 시작해요', '한 문제만 풀어도 오늘의 기록이 남아요');
}

class _StreakStrip extends StatelessWidget {
  const _StreakStrip({
    required this.streak,
    required this.today,
    required this.weeklyStats,
  });

  final StreakData streak;
  final DateTime today;
  final List<WeeklyStatEntry> weeklyStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final dayLabelSize = MediaQuery.textScalerOf(context).scale(11);
    final countWidth = math.max(87.0, dayLabelSize * 5 + 16);
    final weekMinWidth = 7 * (dayLabelSize + 8);
    const chevronSize = AppSizes.iconSm;
    final count = ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xs, vertical: AppSizes.sm),
        decoration: BoxDecoration(
          color: isLight
              ? const Color(0xFFFEF0F2)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '연속 학습',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 11,
                height: 1.4,
                letterSpacing: -0.275,
                color: isLight
                    ? const Color(0xFF111111)
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                text: '${streak.current}',
                children: const [
                  TextSpan(
                    text: '일',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'Pretendard',
                fontSize: 16,
                height: 1.4,
                letterSpacing: -0.4,
                fontWeight: FontWeight.w600,
                color: isLight
                    ? const Color(0xFFF06292)
                    : AppColors.primaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
    final week = Padding(
      // Center the petals in the strip while leaving room for the date marker.
      padding: const EdgeInsets.only(top: 6),
      child: _StreakWeek(
        today: today,
        studiedToday: streak.studiedToday,
        weeklyStats: weeklyStats,
      ),
    );
    final chevron = SizedBox.square(
      dimension: chevronSize,
      child: Center(
        child: Image.asset(
          'assets/icons/figma-home-streak-arrow.png',
          width: 6.25,
          height: 11,
          color: isLight ? null : AppColors.darkSubtext,
          excludeFromSemantics: true,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <
            countWidth + AppSizes.gap + weekMinWidth + chevronSize) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(child: SizedBox(width: countWidth, child: count)),
                  const Spacer(),
                  chevron,
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              week,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: countWidth, child: count),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: week),
            const SizedBox(width: AppSizes.xs),
            chevron,
          ],
        );
      },
    );
  }
}

class _StreakWeek extends StatelessWidget {
  const _StreakWeek({
    required this.today,
    required this.studiedToday,
    required this.weeklyStats,
  });

  final DateTime today;
  final bool studiedToday;
  final List<WeeklyStatEntry> weeklyStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final dates = {
      for (final entry in weeklyStats) entry.date: entry.hasStudied
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (index) {
        final date = monday.add(Duration(days: index));
        final isToday = date == today;
        final future = date.isAfter(today);
        final studied = !future &&
            (isToday ? studiedToday : dates[studyDateKey(date)] == true);
        return Expanded(
          child: Semantics(
            container: true,
            label: '${date.month}월 ${date.day}일 ${_weekdays[index]}요일, '
                '${isToday ? '오늘, ' : ''}'
                '${studied ? '학습 기록 있음' : future ? '예정' : '학습 기록 없음'}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: LayoutBuilder(builder: (context, constraints) {
                  final width = math.min(
                    constraints.maxWidth,
                    MediaQuery.textScalerOf(context).scale(22.25),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: width,
                        height: width * 26 / 22.25,
                        child: Stack(
                          alignment: Alignment.center,
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              studied
                                  ? 'assets/icons/figma-home-petal-active.png'
                                  : 'assets/icons/figma-home-petal-inactive.png',
                              fit: BoxFit.contain,
                              color: isLight
                                  ? null
                                  : studied
                                      ? AppColors.sakuraOn
                                      : AppColors.darkSecondary,
                              excludeFromSemantics: true,
                            ),
                            Center(
                                child: Text(
                              _weekdays[index],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontFamily: 'Pretendard',
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                                letterSpacing: -0.275,
                                color: studied
                                    ? Colors.white
                                    : isLight
                                        ? const Color(0xFF767676)
                                        : AppColors.darkSubtext,
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox.square(
                        dimension: 4,
                        child: isToday
                            ? const DecoratedBox(
                                key: ValueKey('streak-week-today'),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF59BA7),
                                ),
                              )
                            : null,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CalendarSheetContent extends ConsumerStatefulWidget {
  const _CalendarSheetContent({
    required this.scrollController,
    required this.accountId,
  });

  final String accountId;
  final ScrollController scrollController;

  @override
  ConsumerState<_CalendarSheetContent> createState() =>
      _CalendarSheetContentState();
}

class _CalendarSheetContentState extends ConsumerState<_CalendarSheetContent> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = ref.read(studyDateProvider);
    _month = DateTime.utc(today.year, today.month);
  }

  bool get _scopeCurrent =>
      mounted &&
      ref.read(currentAccountIdProvider) == widget.accountId &&
      ref.read(currentAccountReaderProvider)() == widget.accountId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(currentAccountIdProvider);
    ref.watch(currentAccountReaderProvider);
    if (!_scopeCurrent) {
      return ListView(controller: widget.scrollController, children: const [
        Padding(
            padding: EdgeInsets.all(24),
            child: Text('계정이 변경됐어요. 학습 기록을 다시 열어주세요.')),
      ]);
    }
    final today = ref.watch(studyDateProvider);
    final dashboard = ref.watch(dashboardProvider);
    final streakCount = dashboard.isLoading || dashboard.hasError
        ? null
        : dashboard.asData?.value.streak.current;
    final period = (year: _month.year, month: _month.month);
    final history = ref.watch(statsMonthHistoryProvider(period));
    final palette = _StreakPalette(theme.brightness);
    final calendar = _CalendarColors(theme.brightness);
    final isCurrentMonth =
        _month.year == today.year && _month.month == today.month;
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        AppSizes.pageHorizontal,
        20,
        AppSizes.pageHorizontal,
        math.max(40, MediaQuery.paddingOf(context).bottom),
      ),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: calendar.handle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CalendarMonthHeader(
          month: _month,
          colors: calendar,
          previous: () => setState(
              () => _month = DateTime.utc(_month.year, _month.month - 1)),
          next: isCurrentMonth
              ? null
              : () => setState(
                  () => _month = DateTime.utc(_month.year, _month.month + 1)),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: calendar.streakBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text.rich(
              TextSpan(
                text: '연속 학습 ',
                children: [
                  TextSpan(
                    text: streakCount == null ? '—' : '$streakCount',
                    style: _calendarTextStyle(
                      size: 16,
                      lineHeight: 1.4,
                      weight: FontWeight.w600,
                      color: calendar.streakAccent,
                    ),
                  ),
                  TextSpan(
                    text: streakCount == null ? '' : '일',
                    style: _calendarTextStyle(
                      size: 13,
                      color: calendar.streakAccent,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: _calendarTextStyle(
                color: calendar.foreground,
                size: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 19),
        history.when(
          skipLoadingOnRefresh: false,
          data: (records) => _CalendarGrid(
            month: _month,
            today: today,
            colors: calendar,
            studiedDates: {
              for (final record in records)
                if (record.hasStudyActivity) record.date,
            },
            achievedDates: {
              for (final record in records)
                if (record.goalAchieved) record.date,
            },
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
                child:
                    CircularProgressIndicator(semanticsLabel: '학습 기록 불러오는 중')),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text('학습 기록을 불러오지 못했어요',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                    switch (error) {
                      DioException() =>
                        ApiException.fromDioException(error).userMessage,
                      ApiException() => error.userMessage,
                      _ => const ApiException(message: '연결을 확인하고 다시 시도해주세요')
                          .userMessage,
                    },
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: palette.secondary)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: palette.accent,
                    side: BorderSide(color: palette.outline),
                  ),
                  onPressed: () {
                    if (_scopeCurrent) {
                      ref.invalidate(statsMonthHistoryProvider(period));
                    }
                  },
                  icon: const Icon(LucideIcons.rotateCw, size: 18),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.month,
    required this.colors,
    required this.previous,
    required this.next,
  });

  final DateTime month;
  final _CalendarColors colors;
  final VoidCallback previous;
  final VoidCallback? next;

  @override
  Widget build(BuildContext context) {
    final monthWidth =
        math.max(58.0, MediaQuery.textScalerOf(context).scale(48));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _arrow('이전 달', LucideIcons.chevronLeft, previous),
        SizedBox(
          width: monthWidth,
          child: Semantics(
            header: true,
            liveRegion: true,
            label: '${month.year}년 ${month.month}월',
            excludeSemantics: true,
            child: Column(
              children: [
                Text('${month.year}',
                    style: _calendarTextStyle(
                      size: 13,
                      color: colors.secondary,
                    )),
                Text('${month.month}월',
                    style: _calendarTextStyle(
                      size: 20,
                      lineHeight: 1.4,
                      weight: FontWeight.w600,
                      color: colors.foreground,
                    )),
              ],
            ),
          ),
        ),
        _arrow('다음 달', LucideIcons.chevronRight, next),
      ],
    );
  }

  Widget _arrow(String tooltip, IconData icon, VoidCallback? onPressed) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: colors.arrow,
        disabledForegroundColor: colors.pastDay,
      ),
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.arrowBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox.square(dimension: 32, child: Icon(icon, size: 16)),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.colors,
    required this.studiedDates,
    required this.achievedDates,
  });

  final DateTime month;
  final DateTime today;
  final _CalendarColors colors;
  final Set<String> studiedDates;
  final Set<String> achievedDates;

  @override
  Widget build(BuildContext context) {
    final start = month.weekday % DateTime.daysPerWeek;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final weeks =
        (start + days + DateTime.daysPerWeek - 1) ~/ DateTime.daysPerWeek;
    final fontSize = MediaQuery.textScalerOf(context).scale(13);
    final rowHeight = math.max(49.0, fontSize * 1.5 + 10);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              for (final label in _calendarWeekdays)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _calendarTextStyle(
                      size: 13,
                      color: colors.foreground,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: colors.divider),
        const SizedBox(height: 2),
        for (var week = 0; week < weeks; week++)
          SizedBox(
            height: rowHeight,
            child: Row(
              children: List.generate(DateTime.daysPerWeek, (index) {
                final day = week * DateTime.daysPerWeek + index - start + 1;
                if (day < 1 || day > days) {
                  return const Expanded(child: SizedBox());
                }
                final date = DateTime.utc(month.year, month.month, day);
                final isToday = date == today;
                final future = date.isAfter(today);
                final dateKey = studyDateKey(date);
                final studied = !future && studiedDates.contains(dateKey);
                final achieved = studied && achievedDates.contains(dateKey);
                return Expanded(
                  child: _CalendarDay(
                    date: date,
                    isToday: isToday,
                    future: future,
                    studied: studied,
                    achieved: achieved,
                    colors: colors,
                  ),
                );
              }),
            ),
          ),
        const SizedBox(height: 12),
        _CalendarLegend(colors: colors),
        const SizedBox(height: 9),
        Text(
          '한 문제라도 풀면 학습일로 기록해요. 날짜는 한국 시간 기준이에요.',
          textAlign: TextAlign.center,
          style: _calendarTextStyle(
            size: 11,
            color: colors.footer,
          ),
        ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.isToday,
    required this.future,
    required this.studied,
    required this.achieved,
    required this.colors,
  });

  final DateTime date;
  final bool isToday;
  final bool future;
  final bool studied;
  final bool achieved;
  final _CalendarColors colors;

  @override
  Widget build(BuildContext context) {
    final weekday = _calendarWeekdays[date.weekday % DateTime.daysPerWeek];
    final activity = studied
        ? '학습 기록 있음'
        : future
            ? '예정'
            : '학습 기록 없음';
    final textScale = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${date.year}년 ${date.month}월 ${date.day}일 $weekday요일, '
          '${isToday ? '오늘, ' : ''}$activity'
          '${achieved ? ', 하루 목표 달성' : ''}',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: SizedBox(
            width: 46,
            height: math.max(46.0, textScale.scale(13) * 1.5 + 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(color: AppColors.primary) : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (achieved)
                    _CalendarTrophy(size: textScale.scale(24), opacity: 0.6)
                  else if (studied)
                    Container(
                      width: textScale.scale(21),
                      height: textScale.scale(21),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.learnedDay,
                      ),
                    ),
                  Text(
                    '${date.day}',
                    style: _calendarTextStyle(
                      size: 13,
                      color: isToday
                          ? AppColors.primary
                          : future
                              ? colors.foreground
                              : colors.pastDay,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.colors});

  final _CalendarColors colors;

  @override
  Widget build(BuildContext context) {
    final style = _calendarTextStyle(size: 11, color: colors.footer);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.legendBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2DD4C0), width: 3),
                ),
              ),
              const SizedBox(width: 4),
              Text('학습한 날', style: style),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CalendarTrophy(size: 14),
              const SizedBox(width: 4),
              Text('목표 달성', style: style),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarTrophy extends StatelessWidget {
  const _CalendarTrophy({required this.size, this.opacity = 1.0});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/streak_trophy.png',
      width: size,
      height: size,
      opacity: AlwaysStoppedAnimation(opacity),
      excludeFromSemantics: true,
    );
  }
}

TextStyle _calendarTextStyle({
  required double size,
  required Color color,
  double lineHeight = 1.5,
  FontWeight weight = FontWeight.w400,
}) =>
    TextStyle(
      fontFamily: 'Pretendard',
      fontSize: size,
      color: color,
      height: lineHeight,
      letterSpacing: -size * 0.025,
      fontWeight: weight,
    );

const _calendarWeekdays = ['일', '월', '화', '수', '목', '금', '토'];
const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

class _CalendarColors {
  const _CalendarColors(this.brightness);

  final Brightness brightness;
  bool get _light => brightness == Brightness.light;

  Color get foreground => _light ? const Color(0xFF111111) : AppColors.darkText;
  Color get secondary =>
      _light ? const Color(0xFF777777) : AppColors.darkSubtext;
  Color get footer => _light ? const Color(0xFF505050) : AppColors.darkSubtext;
  Color get pastDay => _light ? const Color(0xFF999999) : AppColors.darkSubtext;
  Color get handle => _light ? const Color(0xFFC9C9CF) : AppColors.darkSubtext;
  Color get arrow => _light ? const Color(0xFF494B59) : AppColors.darkText;
  Color get arrowBackground =>
      _light ? const Color(0xFFF1F1F5) : AppColors.darkSecondary;
  Color get streakBackground =>
      _light ? const Color(0xFFFEF0F2) : AppColors.darkSecondary;
  Color get streakAccent =>
      _light ? const Color(0xFFF06292) : AppColors.primaryContainer;
  Color get divider => _light ? const Color(0xFFE5E5EC) : AppColors.darkBorder;
  Color get legendBackground =>
      _light ? const Color(0xFFF7F7FB) : AppColors.darkSecondary;
  Color get learnedDay =>
      _light ? const Color(0xFF96E9DF) : const Color(0xFF226658);
}

class _StreakPalette {
  const _StreakPalette(this.brightness);
  final Brightness brightness;
  bool get _light => brightness == Brightness.light;
  Color get secondary =>
      _light ? AppColors.lightSubtext : AppColors.darkSubtext;
  Color get accent => _light ? AppColors.sakuraOn : AppColors.primaryContainer;
  Color get outline => _light ? AppColors.primaryPressed : AppColors.primary;
}
