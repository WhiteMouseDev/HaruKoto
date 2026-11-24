import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';

class QuizProgressBar extends StatelessWidget {
  final double progress;
  final int streak;
  final bool showStreak;
  final int? currentQuestion;
  final int? totalQuestions;

  const QuizProgressBar({
    super.key,
    required this.progress,
    this.streak = 0,
    this.showStreak = false,
    this.currentQuestion,
    this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = currentQuestion;
    final total = totalQuestions;
    final hasLabels = current != null && total != null;
    final isLight = theme.brightness == Brightness.light;
    final labelStyle = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 12,
      height: 1.4,
      letterSpacing: -0.3,
      color: isLight
          ? AppColors.redesignMutedForeground
          : theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(hasLabels ? 500 : 4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: hasLabels ? 12 : 6,
                backgroundColor: hasLabels && isLight
                    ? AppColors.redesignProgressTrack
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: hasLabels ? BorderRadius.circular(500) : null,
                trackGap: hasLabels ? 0 : null,
                color: AppColors.primaryStrong,
                semanticsLabel: hasLabels ? '전체 $total문제 중 $current번째' : null,
              );
            },
          ),
        ),
        if (hasLabels) ...[
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$current개', style: labelStyle),
                Text('$total개', style: labelStyle),
              ],
            ),
          ),
        ],
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
