import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class LessonResultScoreBadge extends StatelessWidget {
  final bool isPerfect;

  const LessonResultScoreBadge({
    super.key,
    required this.isPerfect,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPerfect
              ? AppColors.success(brightness).withValues(alpha: 0.12)
              : AppColors.primary.withValues(alpha: 0.12),
        ),
        child: Icon(
          isPerfect ? LucideIcons.trophy : LucideIcons.clipboardCheck,
          size: 36,
          color: isPerfect
              ? AppColors.success(brightness)
              : AppColors.primaryStrong,
        ),
      ),
    );
  }
}

class LessonResultScoreText extends StatelessWidget {
  final int score;
  final int scoreCorrect;
  final int scoreTotal;

  const LessonResultScoreText({
    super.key,
    required this.score,
    required this.scoreCorrect,
    required this.scoreTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '$value%',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Center(
          child: Text(
            '$scoreCorrect/$scoreTotal 정답',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.lightSubtext,
            ),
          ),
        ),
      ],
    );
  }
}

class LessonResultSrsBanner extends StatelessWidget {
  final int registeredCount;

  const LessonResultSrsBanner({
    super.key,
    required this.registeredCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.gap,
      ),
      decoration: BoxDecoration(
        color: AppColors.success(brightness).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
          color: AppColors.success(brightness).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.checkCircle2,
            color: AppColors.success(brightness),
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              '$registeredCount개 항목이 복습 예약되었습니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
