import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/dashboard_model.dart';

class StreakDailyCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Semantics(
      label:
          '${streak.current}일 연속 학습, 오늘 ${today.wordsStudied}개 단어 학습',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(color: const Color(0xFFFCE7EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: Streak header
              _StreakHeader(streak: streak.current),
              const SizedBox(height: 16),

              // 7-day circles
              _StreakWeek(weeklyStats: weeklyStats),
              const SizedBox(height: 20),

              // Divider
              Container(
                height: 1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 20),

              // Bottom: Daily progress header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '오늘의 학습',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${today.wordsStudied}/$dailyGoal',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: LinearProgressIndicator(
                    value: today.goalProgress.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.secondary,
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3-column stats grid
              Row(
                children: [
                  _StatBox(
                    icon: LucideIcons.target,
                    iconColor: theme.colorScheme.primary,
                    label: '목표',
                    value: '${(today.goalProgress * 100).round()}%',
                  ),
                  const SizedBox(width: 12),
                  _StatBox(
                    icon: LucideIcons.bookOpen,
                    iconColor: AppColors.hkBlue(brightness),
                    label: '단어',
                    value: '${today.wordsStudied}개',
                  ),
                  const SizedBox(width: 12),
                  _StatBox(
                    icon: LucideIcons.trophy,
                    iconColor: AppColors.hkYellow(brightness),
                    label: '정답률',
                    value: today.quizzesCompleted > 0 ? '--%' : '--%',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    final brightness = theme.brightness;

    final text = widget.streak > 0
        ? '${widget.streak}일째 연속 학습 중!'
        : '오늘 첫 학습을 시작해보세요!';

    return Row(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            LucideIcons.flame,
            color: AppColors.hkRed(brightness),
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
          bgColor = theme.colorScheme.primary;
          child = const Icon(LucideIcons.check,
              color: AppColors.onGradient, size: 16);
        } else if (isToday) {
          bgColor = theme.colorScheme.secondary;
          child = Text(
            '-',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          );
        } else if (isPast) {
          bgColor = theme.colorScheme.surfaceContainerHigh;
          child = Text(
            '-',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          );
        } else {
          bgColor = theme.colorScheme.secondary;
          child = const SizedBox.shrink();
        }

        return Column(
          children: [
            Text(
              dayLabels[i],
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 32,
              height: 32,
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

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
