import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

/// A single lesson row inside a chapter card.
class LessonTile extends StatelessWidget {
  final LessonSummaryModel lesson;
  final bool isRecommended;

  const LessonTile({
    super.key,
    required this.lesson,
    this.isRecommended = false,
  });

  bool get _isPerfect =>
      lesson.status == 'COMPLETED' &&
      lesson.scoreCorrect == lesson.scoreTotal &&
      lesson.scoreTotal > 0;

  bool get _isCompleted => lesson.status == 'COMPLETED';

  bool get _isInProgress => lesson.status == 'IN_PROGRESS';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final highlightNext = isRecommended && !_isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/study/lessons/${lesson.id}'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.fromLTRB(4, 9, 10, 9),
            decoration: BoxDecoration(
              color: _stoneColor(
                theme: theme,
                isLight: isLight,
                highlightNext: highlightNext,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlightNext
                    ? AppColors.primaryStrong.withValues(alpha: 0.20)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                _LessonStateIcon(
                  isPerfect: _isPerfect,
                  isCompleted: _isCompleted,
                  isInProgress: _isInProgress,
                  isRecommended: highlightNext,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _isCompleted
                              ? AppColors.lightText
                              : AppColors.neutralOn,
                          fontWeight:
                              highlightNext ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lesson.estimatedMinutes}분 · ${lesson.topic}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.lightSubtext,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (highlightNext)
                  _LessonNextPill(label: _isInProgress ? '이어하기' : '다음')
                else if (_isCompleted)
                  _LessonScorePill(
                    isPerfect: _isPerfect,
                    correct: lesson.scoreCorrect,
                    total: lesson.scoreTotal,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _stoneColor({
    required ThemeData theme,
    required bool isLight,
    required bool highlightNext,
  }) {
    if (highlightNext) {
      return AppColors.sakuraTrack.withValues(alpha: 0.48);
    }
    if (_isCompleted) {
      return AppColors.mintTrack.withValues(alpha: 0.46);
    }
    if (_isInProgress) {
      return isLight
          ? AppColors.neutralContainer.withValues(alpha: 0.50)
          : theme.colorScheme.surfaceContainerHigh;
    }
    return Colors.transparent;
  }
}

class _LessonStateIcon extends StatelessWidget {
  const _LessonStateIcon({
    required this.isPerfect,
    required this.isCompleted,
    required this.isInProgress,
    required this.isRecommended,
  });

  final bool isPerfect;
  final bool isCompleted;
  final bool isInProgress;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;

    if (isRecommended) {
      backgroundColor = AppColors.primaryStrong;
      borderColor = AppColors.primaryStrong;
      iconColor = Colors.white;
      icon = isInProgress ? LucideIcons.playCircle : LucideIcons.arrowRight;
    } else if (isPerfect) {
      backgroundColor = AppColors.mintPressed;
      borderColor = AppColors.mintPressed;
      iconColor = Colors.white;
      icon = LucideIcons.sparkles;
    } else if (isCompleted) {
      backgroundColor = AppColors.mintPressed;
      borderColor = AppColors.mintPressed;
      iconColor = Colors.white;
      icon = LucideIcons.check;
    } else if (isInProgress) {
      backgroundColor = AppColors.sakuraTrack;
      borderColor = AppColors.primaryStrong.withValues(alpha: 0.28);
      iconColor = AppColors.primaryStrong;
      icon = LucideIcons.playCircle;
    } else {
      backgroundColor = Colors.transparent;
      borderColor = AppColors.lightBorderStrong;
      iconColor = AppColors.lightSubtext;
      icon = LucideIcons.circle;
    }

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
        boxShadow: isRecommended
            ? [
                BoxShadow(
                  color: AppColors.primaryStrong.withValues(alpha: 0.20),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: 16, color: iconColor),
    );
  }
}

class _LessonNextPill extends StatelessWidget {
  const _LessonNextPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(
          color: AppColors.primaryStrong.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.primaryPressed,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LessonScorePill extends StatelessWidget {
  const _LessonScorePill({
    required this.isPerfect,
    required this.correct,
    required this.total,
  });

  final bool isPerfect;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isPerfect ? AppColors.mintPressed : AppColors.mintTrack,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        '$correct/$total',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isPerfect ? Colors.white : AppColors.mintOn,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
