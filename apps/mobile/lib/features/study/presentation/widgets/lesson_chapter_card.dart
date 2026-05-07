import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_tile.dart';

/// A card displaying a single chapter with accordion expand/collapse.
class ChapterCard extends StatelessWidget {
  final ChapterModel chapter;
  final String? recommendedLessonId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ChapterCard({
    super.key,
    required this.chapter,
    this.recommendedLessonId,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isLight = brightness == Brightness.light;
    final cardColor =
        isLight ? AppColors.cardWarm : theme.colorScheme.surfaceContainerLow;
    final outlineColor =
        isLight ? AppColors.lightBorder : theme.colorScheme.outline;
    final mutedSurface = isLight
        ? AppColors.surfaceMuted
        : theme.colorScheme.surfaceContainerHigh;
    final progress = chapter.totalLessons > 0
        ? chapter.completedLessons / chapter.totalLessons
        : 0.0;
    final isComplete = progress >= 1.0;
    final hasRecommendedLesson = recommendedLessonId != null &&
        chapter.lessons.any((lesson) => lesson.id == recommendedLessonId);
    final percentText = '${(progress * 100).round()}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: outlineColor),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLight
                              ? AppColors.neutralContainer
                              : theme.colorScheme.surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusFull),
                        ),
                        child: Text(
                          'Ch.${chapter.chapterNo}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isLight
                                ? AppColors.neutralOn
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          chapter.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (hasRecommendedLesson) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Text(
                            '추천',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        percentText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isComplete
                              ? AppColors.success(brightness)
                              : progress > 0
                                  ? AppColors.primaryStrong
                                  : AppColors.neutralOn,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          LucideIcons.chevronDown,
                          size: 18,
                          color: AppColors.lightSubtext,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppSizes.progressRadius),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: AppSizes.progressHeight,
                      backgroundColor: mutedSurface,
                      color: isComplete
                          ? AppColors.success(brightness)
                          : AppColors.primaryStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: Column(
                      children: chapter.lessons
                          .map(
                            (lesson) => LessonTile(
                              lesson: lesson,
                              isRecommended: lesson.id == recommendedLessonId,
                            ),
                          )
                          .toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
