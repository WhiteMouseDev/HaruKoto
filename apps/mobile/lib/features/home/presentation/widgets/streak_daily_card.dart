import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../../stats/providers/stats_provider.dart';
import '../../data/models/dashboard_model.dart';

class StreakDailyCard extends ConsumerWidget {
  final StreakData streak;
  final TodayStats today;
  final List<WeeklyStatEntry> weeklyStats;
  final int dailyGoal;

  const StreakDailyCard({
    super.key,
    required this.streak,
    required this.today,
    required this.weeklyStats,
    required this.dailyGoal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${streak.current}일 연속 학습, 오늘 ${today.wordsStudied}개 단어 학습',
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            onTap: () {
              HapticService().light();
              _showCalendarSheet(context, ref);
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Streak info + chevron
                  Row(
                    children: [
                      _StreakHeader(streak: streak.current),
                      const Spacer(),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 7-day circles
                  _StreakWeek(weeklyStats: weeklyStats),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCalendarSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: AppSizes.sheetShape,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return _CalendarSheetContent(
              scrollController: scrollController,
              streak: streak,
            );
          },
        );
      },
    );
  }
}

class _CalendarSheetContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final StreakData streak;

  const _CalendarSheetContent({
    required this.scrollController,
    required this.streak,
  });

  @override
  ConsumerState<_CalendarSheetContent> createState() =>
      _CalendarSheetContentState();
}

class _CalendarSheetContentState extends ConsumerState<_CalendarSheetContent> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(statsHistoryProvider(_displayedMonth.year));

    // Build a set of dates that have study activity
    final studiedDates = <String>{};
    if (historyAsync.hasValue) {
      for (final record in historyAsync.value!) {
        if (record.wordsStudied > 0 ||
            record.quizzesCompleted > 0 ||
            record.conversationCount > 0) {
          studiedDates.add(record.date);
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const AppSheetHandle(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.flame,
                    size: 20,
                    color: AppColors.streak,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.streak.current}일 연속 학습',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '최장 기록: ${widget.streak.longest}일',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        // Month navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 20),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                '${_displayedMonth.year}년 ${_displayedMonth.month}월',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight, size: 20),
                onPressed: _displayedMonth.year == DateTime.now().year &&
                        _displayedMonth.month == DateTime.now().month
                    ? null
                    : () {
                        setState(() {
                          _displayedMonth = DateTime(
                            _displayedMonth.year,
                            _displayedMonth.month + 1,
                          );
                        });
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCalendarGrid(
                context, studiedDates, historyAsync.isLoading),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(
      BuildContext context, Set<String> studiedDates, bool isLoading) {
    final theme = Theme.of(context);
    const dayLabels = ['일', '월', '화', '수', '목', '금', '토'];
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // Sunday = 0
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Column(
      children: [
        // Day labels
        Row(
          children: dayLabels
              .map((label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )
        else
          // Calendar weeks
          ...List.generate(
            ((startWeekday + daysInMonth + 6) / 7).ceil(),
            (week) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: List.generate(7, (dayOfWeek) {
                    final dayNum = week * 7 + dayOfWeek - startWeekday + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 40));
                    }

                    final dateStr =
                        '$year-${month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                    final hasStudied = studiedDates.contains(dateStr);
                    final isToday = dateStr == todayStr;

                    return Expanded(
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: hasStudied
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.15)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday
                              ? Border.all(
                                  color: theme.colorScheme.primary, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: hasStudied
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (hasStudied)
                                Positioned(
                                  bottom: 2,
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StreakHeader extends StatefulWidget {
  final int streak;

  const _StreakHeader({required this.streak});

  @override
  State<_StreakHeader> createState() => _StreakHeaderState();
}

class _StreakHeaderState extends State<_StreakHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text =
        widget.streak > 0 ? '${widget.streak}일째 연속 학습 중!' : '오늘 첫 학습을 시작해보세요!';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: const Icon(
            LucideIcons.flame,
            color: AppColors.streak,
            size: 20,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StreakWeek extends StatelessWidget {
  final List<WeeklyStatEntry> weeklyStats;

  const _StreakWeek({required this.weeklyStats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final todayStr = _formatDate(DateTime.now());
    final inactiveDayColor = AppColors.streakContainer.withValues(alpha: 0.42);
    final pastDayColor = AppColors.streakContainer.withValues(alpha: 0.3);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final hasDate = i < weeklyStats.length;
        final date = hasDate ? weeklyStats[i].date : '';
        final studied = hasDate ? weeklyStats[i].wordsStudied : 0;
        final isToday = date == todayStr;
        final isPast = hasDate && date.compareTo(todayStr) < 0;

        Color bgColor;
        Widget child;

        if (studied > 0) {
          bgColor = AppColors.streak;
          child = const Icon(LucideIcons.check,
              color: AppColors.onGradient, size: 14);
        } else if (isToday) {
          bgColor = AppColors.streakContainer;
          child = const Text(
            '-',
            style: TextStyle(
              color: AppColors.streak,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
        } else if (isPast) {
          bgColor = pastDayColor;
          child = Text(
            '-',
            style: TextStyle(
              color: AppColors.streak.withValues(alpha: 0.42),
              fontSize: 12,
            ),
          );
        } else {
          bgColor = inactiveDayColor;
          child = const SizedBox.shrink();
        }

        return Column(
          children: [
            Text(
              dayLabels[i],
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(child: child),
            ),
          ],
        );
      }),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
