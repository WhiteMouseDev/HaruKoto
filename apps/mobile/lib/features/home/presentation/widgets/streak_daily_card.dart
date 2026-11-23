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
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../../stats/providers/stats_provider.dart';
import '../../data/models/dashboard_model.dart';

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
    final palette = _StreakPalette(theme.brightness);
    final (title, description) = _streakCopy(streak);
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
        shape: AppSizes.sheetShape,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, controller) => _CalendarSheetContent(
            scrollController: controller,
            streak: streak,
            accountId: owner,
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
        child: Material(
          color: theme.colorScheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: openCalendar,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.xs + 2),
              child: _StreakStrip(
                streak: streak,
                today: date,
                weeklyStats: weeklyStats,
                palette: palette,
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
    required this.palette,
  });

  final StreakData streak;
  final DateTime today;
  final List<WeeklyStatEntry> weeklyStats;
  final _StreakPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayLabelSize = MediaQuery.textScalerOf(context).scale(11);
    final countWidth = math.max(86.0, dayLabelSize * 5 + 16);
    final weekMinWidth = 7 * (dayLabelSize + 8);
    const chevronSize = AppSizes.iconSm;
    final count = ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 53),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xs, vertical: AppSizes.sm),
        decoration: BoxDecoration(
          color: palette.countSurface,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '연속 학습',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${streak.current}일',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.accent,
              ),
            ),
          ],
        ),
      ),
    );
    final week = _StreakWeek(
      today: today,
      studiedToday: streak.studiedToday,
      weeklyStats: weeklyStats,
    );
    final chevron = Icon(LucideIcons.chevronRight,
        size: chevronSize, color: palette.secondary);

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
    final palette = _StreakPalette(theme.brightness);
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
                    MediaQuery.textScalerOf(context).scale(22),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: width,
                        height: width * 1.1,
                        child: CustomPaint(
                          painter: _PetalPainter(studied
                              ? palette.studiedPetal
                              : palette.idlePetal),
                          child: Center(
                            child: Text(
                              _weekdays[index],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: studied
                                    ? palette.accent
                                    : palette.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox.square(
                        dimension: 4,
                        child: isToday
                            ? DecoratedBox(
                                key: const ValueKey('streak-week-today'),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.outline,
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

class _PetalPainter extends CustomPainter {
  const _PetalPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Size(:width, :height) = size;
    final path = Path()
      ..moveTo(width * .60, height * .15)
      ..cubicTo(width * .49, height * .01, width * .32, height * .06,
          width * .20, height * .24)
      ..cubicTo(width * .05, height * .41, width * .04, height * .62,
          width * .10, height * .78)
      ..cubicTo(width * .15, height * .93, width * .27, height * .99,
          width * .45, height * .95)
      ..cubicTo(width * .66, height * .90, width * .87, height * .75,
          width * .93, height * .53)
      ..cubicTo(width * .99, height * .33, width * .90, height * .09,
          width * .76, height * .11)
      ..cubicTo(width * .72, height * .11, width * .69, height * .18,
          width * .66, height * .22)
      ..quadraticBezierTo(width * .64, height * .24, width * .60, height * .15)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PetalPainter oldDelegate) => color != oldDelegate.color;
}

class _CalendarSheetContent extends ConsumerStatefulWidget {
  const _CalendarSheetContent({
    required this.scrollController,
    required this.streak,
    required this.accountId,
  });

  final String accountId;
  final ScrollController scrollController;
  final StreakData streak;

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
    final period = (year: _month.year, month: _month.month);
    final history = ref.watch(statsMonthHistoryProvider(period));
    final palette = _StreakPalette(theme.brightness);
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
          18, 16, 18, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        const Center(child: AppSheetHandle()),
        const SizedBox(height: 18),
        Text('학습 기록',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('최장 ${widget.streak.longest}일 · 한국 시간 기준',
            style:
                theme.textTheme.bodyMedium?.copyWith(color: palette.secondary)),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(LucideIcons.chevronLeft, size: 20),
              onPressed: () => setState(
                  () => _month = DateTime.utc(_month.year, _month.month - 1)),
            ),
            Expanded(
              child: Text('${_month.year}년 ${_month.month}월',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: '다음 달',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(LucideIcons.chevronRight, size: 20),
              onPressed:
                  _month.year == today.year && _month.month == today.month
                      ? null
                      : () => setState(() =>
                          _month = DateTime.utc(_month.year, _month.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        history.when(
          skipLoadingOnRefresh: false,
          data: (records) => _CalendarGrid(
            month: _month,
            today: today,
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

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.studiedDates,
    required this.achievedDates,
  });

  final DateTime month;
  final DateTime today;
  final Set<String> studiedDates;
  final Set<String> achievedDates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _StreakPalette(theme.brightness);
    final start = month.weekday - DateTime.monday;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final weeks = (start + days + 6) ~/ 7;
    final fontSize = MediaQuery.textScalerOf(context).scale(13);
    return Column(
      children: [
        Row(children: [
          for (final label in _weekdays)
            Expanded(
                child: Center(
                    child: Text(label,
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11, color: palette.secondary))))
        ]),
        const SizedBox(height: 8),
        for (var week = 0; week < weeks; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (index) {
                final day = week * 7 + index - start + 1;
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
                  child: Semantics(
                    container: true,
                    label:
                        '${date.year}년 ${date.month}월 ${date.day}일 ${_weekdays[index]}요일, '
                        '${isToday ? '오늘, ' : ''}${studied ? '학습 기록 있음' : future ? '예정' : '학습 기록 없음'}'
                        '${achieved ? ', 하루 목표 달성' : ''}',
                    child: ExcludeSemantics(
                      child: Container(
                        constraints: BoxConstraints(minHeight: fontSize + 30),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: studied ? palette.completedSurface : null,
                          border: isToday
                              ? Border.all(color: palette.outline, width: 1.5)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text('$day',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    fontWeight: isToday
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: studied
                                        ? palette.accent
                                        : palette.secondary)),
                            SizedBox(
                                height: 14,
                                child: studied
                                    ? Icon(
                                        achieved
                                            ? LucideIcons.trophy
                                            : LucideIcons.check,
                                        size: 12,
                                        color: palette.accent,
                                      )
                                    : null),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        const SizedBox(height: 8),
        Text('체크는 학습한 날 · 트로피는 목표를 달성한 날 · 테두리는 오늘',
            style:
                theme.textTheme.bodySmall?.copyWith(color: palette.secondary)),
        const SizedBox(height: 8),
        Text('한 문제라도 풀면 학습일로 기록해요. 날짜는 한국 시간 기준이에요.',
            style: theme.textTheme.bodySmall
                ?.copyWith(height: 1.5, color: palette.secondary)),
      ],
    );
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

class _StreakPalette {
  const _StreakPalette(this.brightness);
  final Brightness brightness;
  bool get _light => brightness == Brightness.light;
  Color get secondary =>
      _light ? AppColors.lightSubtext : AppColors.darkSubtext;
  Color get accent => _light ? AppColors.sakuraOn : AppColors.primaryContainer;
  Color get outline => _light ? AppColors.primaryPressed : AppColors.primary;
  Color get idlePetal =>
      _light ? AppColors.lightSecondary : AppColors.darkSecondary;
  Color get countSurface => _light ? AppColors.sakuraTrack : completedSurface;
  Color get studiedPetal => _light
      ? Color.alphaBlend(
          AppColors.primary.withValues(alpha: 0.38), AppColors.primaryContainer)
      : completedSurface;
  Color get completedSurface => _light
      ? AppColors.primaryContainer
      : Color.alphaBlend(
          AppColors.primary.withValues(alpha: 0.18), AppColors.darkCard);
}
