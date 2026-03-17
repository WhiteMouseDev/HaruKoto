import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';

class QuizProgressBar extends StatelessWidget {
  final double progress;
  final int streak;
  final bool showStreak;

  const QuizProgressBar({
    super.key,
    required this.progress,
    this.streak = 0,
    this.showStreak = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                color: AppColors.primaryStrong,
              );
            },
          ),
        ),
        if (showStreak && streak >= 3) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.flame,
                  size: 14,
                  color: AppColors.warning(Theme.of(context).brightness)),
              const SizedBox(width: 4),
              Text(
                '$streak연속 정답!',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warning(Theme.of(context).brightness),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
