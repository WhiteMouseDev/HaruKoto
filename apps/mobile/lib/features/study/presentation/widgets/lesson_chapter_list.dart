import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

/// Reusable chapter list widget used both inline in StudyPage
/// and in the standalone LessonListPage.
class LessonChapterList extends StatelessWidget {
  final List<ChapterModel> chapters;
  final EdgeInsetsGeometry padding;

  const LessonChapterList({
    super.key,
    required this.chapters,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: chapters.length,
      itemBuilder: (context, index) => ChapterCard(chapter: chapters[index]),
    );
  }
}

/// A card displaying a single chapter with its progress and lessons.
class ChapterCard extends StatelessWidget {
  final ChapterModel chapter;
  const ChapterCard({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final progress = chapter.totalLessons > 0
        ? chapter.completedLessons / chapter.totalLessons
        : 0.0;
    final isComplete = progress >= 1.0;
    final percentText = '${(progress * 100).round()}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    'Ch.${chapter.chapterNo}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryStrong,
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
                Text(
                  percentText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isComplete
                        ? AppColors.success(brightness)
                        : AppColors.primaryStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.progressRadius),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: AppSizes.progressHeight,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                color: isComplete
                    ? AppColors.success(brightness)
                    : AppColors.primaryStrong,
              ),
            ),
            const SizedBox(height: 12),
            ...chapter.lessons.map((lesson) => LessonTile(lesson: lesson)),
          ],
        ),
      ),
    );
  }
}

/// A single lesson row inside a chapter card.
class LessonTile extends StatelessWidget {
  final LessonSummaryModel lesson;
  const LessonTile({super.key, required this.lesson});

  bool get _isPerfect =>
      lesson.status == 'COMPLETED' &&
      lesson.scoreCorrect == lesson.scoreTotal &&
      lesson.scoreTotal > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    // Determine state-dependent styles
    final Color bgColor;
    final IconData iconData;
    final Color iconColor;

    if (_isPerfect) {
      bgColor = AppColors.hkYellowLight.withValues(alpha: 0.22);
      iconData = LucideIcons.sparkles;
      iconColor = AppColors.hkYellow(brightness);
    } else {
      switch (lesson.status) {
        case 'COMPLETED':
          bgColor = AppColors.success(brightness).withValues(alpha: 0.14);
          iconData = LucideIcons.checkCircle2;
          iconColor = AppColors.success(brightness);
        case 'IN_PROGRESS':
          bgColor = AppColors.primary.withValues(alpha: 0.12);
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
          ),
          child: Row(
            children: [
              Icon(iconData, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        ? AppColors.hkYellowLight.withValues(alpha: 0.30)
                        : AppColors.success(brightness).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    '${lesson.scoreCorrect}/${lesson.scoreTotal}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _isPerfect
                          ? AppColors.hkYellow(brightness)
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
