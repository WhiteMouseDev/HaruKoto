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
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: openCalendar,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.flame,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text('연속 학습',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                      color: palette.secondary,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Icon(LucideIcons.chevronRight,
                                size: 18, color: palette.secondary),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(title,
                            style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 21,
                                height: 1.3,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text(description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                height: 1.5,
                                color: palette.secondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StreakWeek(
                    today: date,
                    studiedToday: streak.studiedToday,
                    weeklyStats: weeklyStats,
                  ),
                  const SizedBox(height: 12),
                  ExcludeSemantics(
                    child: Text('기록 보기 · 한국 시간 기준',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 11, color: palette.secondary)),
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

(String, String) _streakCopy(StreakData streak) {
  if (streak.studiedToday) {
    return (
      streak.current > 0 ? '${streak.current}일 연속 학습' : '오늘 학습 완료',
      streak.current > 0 ? '오늘 학습 완료 · 내일도 이어가요' : '오늘의 학습 기록을 남겼어요',
    );
  }
  if (streak.current > 0) {
    return (
      '${streak.current}일 연속 학습',
      '어제까지의 기록 · 오늘 마치면 ${streak.current + 1}일'
    );
  }
  if (streak.longest > 0) {
    return ('오늘부터 다시 시작해요', '학습 하나를 마치고 새로운 기록을 쌓아보세요');
  }
  return ('첫 학습을 시작해요', '학습 하나를 마치면 오늘의 기록이 남아요');
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
                '${studied ? '학습 완료' : future ? '예정' : '학습 기록 없음'}',
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Text(_weekdays[index],
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontSize: 11, color: palette.secondary)),
                  const SizedBox(height: 7),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: studied ? palette.completedSurface : palette.idle,
                      border: isToday
                          ? Border.all(color: palette.outline, width: 2)
                          : null,
                    ),
                    child: studied
                        ? Icon(LucideIcons.check,
                            size: 16, color: palette.accent)
                        : isToday
                            ? Icon(Icons.circle, size: 5, color: palette.accent)
                            : null,
                  ),
                  const SizedBox(height: 5),
                  Text(isToday ? '오늘' : '',
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: palette.accent)),
                ],
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
                if (record.hasStudyActivity) record.date
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
  const _CalendarGrid(
      {required this.month, required this.today, required this.studiedDates});
  final DateTime month;
  final DateTime today;
  final Set<String> studiedDates;

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
                final studied =
                    !future && studiedDates.contains(studyDateKey(date));
                return Expanded(
                  child: Semantics(
                    container: true,
                    label:
                        '${date.year}년 ${date.month}월 ${date.day}일 ${_weekdays[index]}요일, '
                        '${isToday ? '오늘, ' : ''}${studied ? '학습 완료' : future ? '예정' : '학습 기록 없음'}',
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
                                    ? Icon(LucideIcons.check,
                                        size: 12, color: palette.accent)
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
        Text('체크는 학습 완료 · 테두리는 오늘',
            style:
                theme.textTheme.bodySmall?.copyWith(color: palette.secondary)),
        const SizedBox(height: 8),
        Text('학습 활동이 기록된 날을 표시해요. 기록은 한국 시간을 기준으로 확인해요.',
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
  Color get surface => _light ? AppColors.cardWarm : AppColors.darkCard;
  Color get secondary =>
      _light ? AppColors.lightSubtext : AppColors.darkSubtext;
  Color get accent => _light ? AppColors.sakuraOn : AppColors.primaryContainer;
  Color get outline => _light ? AppColors.primaryPressed : AppColors.primary;
  Color get idle =>
      _light ? AppColors.neutralContainer : AppColors.darkSecondary;
  Color get completedSurface => _light
      ? AppColors.primaryContainer
      : Color.alphaBlend(
          AppColors.primary.withValues(alpha: 0.18), AppColors.darkCard);
}
