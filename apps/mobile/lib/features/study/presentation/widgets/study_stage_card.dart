import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/stage_model.dart';

/// A single stage card showing stage number, title, progress, and lock status.
class StudyStageCard extends StatelessWidget {
  final StageModel stage;
  final VoidCallback? onTap;

  const StudyStageCard({
    super.key,
    required this.stage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = !stage.isLocked && !stage.isCompleted;

    final Color borderColor;
    final Color bgColor;
    final double borderWidth;

    if (stage.isLocked) {
      borderColor = theme.colorScheme.outline.withValues(alpha: 0.3);
      bgColor = theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.3);
      borderWidth = 1;
    } else if (stage.isCompleted) {
      borderColor = AppColors.success(theme.brightness).withValues(alpha: 0.3);
      bgColor = AppColors.success(theme.brightness).withValues(alpha: 0.04);
      borderWidth = 1;
    } else {
      borderColor = theme.colorScheme.outline;
      bgColor = theme.brightness == Brightness.light
          ? AppColors.cardWarm
          : theme.colorScheme.surfaceContainerLow;
      borderWidth = 1.2;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: stage.isLocked ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            children: [
              _StageBadge(
                stageNumber: stage.stageNumber,
                isLocked: stage.isLocked,
                isCompleted: stage.isCompleted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StageDetails(stage: stage, isCurrent: isCurrent),
              ),
              _StageStatusIcon(stage: stage),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageDetails extends StatelessWidget {
  final StageModel stage;
  final bool isCurrent;

  const _StageDetails({
    required this.stage,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stage.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: stage.isLocked
                ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${stage.contentCount}개 항목',
              style: theme.textTheme.bodySmall?.copyWith(
                color: stage.isLocked
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (stage.userProgress != null &&
                stage.userProgress!.attempts > 0) ...[
              const SizedBox(width: 12),
              Text(
                '${stage.userProgress!.attempts}회 도전',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
        if (!stage.isLocked && stage.bestScore > 0) ...[
          const SizedBox(height: 8),
          _StageProgressBar(stage: stage),
        ],
      ],
    );
  }
}

class _StageProgressBar extends StatelessWidget {
  final StageModel stage;

  const _StageProgressBar({required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = stage.isCompleted
        ? AppColors.success(theme.brightness)
        : theme.colorScheme.primary;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stage.bestScore / 100,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              color: progressColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${stage.bestScore}%',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: progressColor,
          ),
        ),
      ],
    );
  }
}

class _StageBadge extends StatelessWidget {
  final int stageNumber;
  final bool isLocked;
  final bool isCompleted;

  const _StageBadge({
    required this.stageNumber,
    required this.isLocked,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color bgColor;
    final Color textColor;

    if (isLocked) {
      bgColor = theme.colorScheme.surfaceContainerHigh;
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (isCompleted) {
      bgColor = AppColors.success(theme.brightness).withValues(alpha: 0.1);
      textColor = AppColors.success(theme.brightness);
    } else {
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.1);
      textColor = theme.colorScheme.primary;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$stageNumber',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _StageStatusIcon extends StatelessWidget {
  final StageModel stage;

  const _StageStatusIcon({required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (stage.isLocked) {
      return Icon(
        LucideIcons.lock,
        size: 18,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
      );
    }

    if (stage.isCompleted) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.success(theme.brightness).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.check,
          size: 16,
          color: AppColors.success(theme.brightness),
        ),
      );
    }

    return Icon(
      LucideIcons.chevronRight,
      size: 20,
      color: theme.colorScheme.primary,
    );
  }
}
