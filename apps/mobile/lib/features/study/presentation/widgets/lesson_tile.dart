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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final Color bgColor;
    final IconData iconData;
    final Color iconColor;

    if (isRecommended && lesson.status != 'COMPLETED') {
      bgColor = AppColors.primaryStrong.withValues(alpha: 0.10);
      iconData = lesson.status == 'IN_PROGRESS'
          ? LucideIcons.playCircle
          : LucideIcons.sparkles;
      iconColor = AppColors.primaryStrong;
    } else if (_isPerfect) {
      bgColor = AppColors.primary.withValues(alpha: 0.14);
      iconData = LucideIcons.sparkles;
      iconColor = AppColors.primaryStrong;
    } else {
      switch (lesson.status) {
        case 'COMPLETED':
          bgColor = AppColors.success(brightness).withValues(alpha: 0.10);
          iconData = LucideIcons.checkCircle2;
          iconColor = AppColors.success(brightness);
        case 'IN_PROGRESS':
          bgColor = AppColors.primary.withValues(alpha: 0.08);
          iconData = LucideIcons.playCircle;
          iconColor = AppColors.primaryStrong;
        default:
          bgColor = Colors.transparent;
          iconData = LucideIcons.circle;
          iconColor = AppColors.lightSubtext;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => context.push('/study/lessons/${lesson.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: isRecommended && lesson.status != 'COMPLETED'
                ? Border.all(
                    color: AppColors.primaryStrong.withValues(alpha: 0.22),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(iconData, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isRecommended && lesson.status != 'COMPLETED') ...[
                      Text(
                        lesson.status == 'IN_PROGRESS' ? '이어하기' : '추천 레슨',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      lesson.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lesson.estimatedMinutes}분 · ${lesson.topic}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
              ),
              if (lesson.status == 'COMPLETED')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPerfect
                        ? AppColors.primaryStrong.withValues(alpha: 0.14)
                        : AppColors.success(brightness).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    '${lesson.scoreCorrect}/${lesson.scoreTotal}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _isPerfect
                          ? AppColors.primaryStrong
                          : AppColors.success(brightness),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
