import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_tile.dart';

/// A card displaying a single chapter with accordion expand/collapse.
class ChapterCard extends StatelessWidget {
  final ChapterModel chapter;
  final bool isFirst;
  final bool isLast;
  final String? recommendedLessonId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.isFirst,
    required this.isLast,
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
        ? (chapter.completedLessons / chapter.totalLessons)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;
    final isComplete = progress >= 1.0;
    final hasRecommendedLesson = recommendedLessonId != null &&
        chapter.lessons.any((lesson) => lesson.id == recommendedLessonId);
    final state = isComplete
        ? _ChapterPathState.done
        : hasRecommendedLesson || progress > 0
            ? _ChapterPathState.active
            : _ChapterPathState.idle;
    final percentText = '${(progress * 100).round()}%';
    final accentColor = switch (state) {
      _ChapterPathState.done => AppColors.mintPressed,
      _ChapterPathState.active => AppColors.primaryStrong,
      _ChapterPathState.idle => AppColors.neutralOn,
    };
    final borderColor = switch (state) {
      _ChapterPathState.done => AppColors.mintTrack,
      _ChapterPathState.active when hasRecommendedLesson =>
        AppColors.sakuraTrack,
      _ => outlineColor,
    };
    final progressColor = switch (state) {
      _ChapterPathState.done => AppColors.mintPressed,
      _ChapterPathState.active => AppColors.primaryStrong,
      _ChapterPathState.idle => AppColors.neutralOn.withValues(alpha: 0.22),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChapterPathNode(
            chapterNo: chapter.chapterNo,
            state: state,
            isFirst: isFirst,
            isLast: isLast,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
                boxShadow: isLight
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(
                            alpha: hasRecommendedLesson ? 0.10 : 0.04,
                          ),
                          blurRadius: hasRecommendedLesson ? 20 : 14,
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
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: state == _ChapterPathState.done
                                      ? AppColors.mintTrack
                                      : isLight
                                          ? AppColors.neutralContainer
                                          : theme
                                              .colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  'Ch.${chapter.chapterNo}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: state == _ChapterPathState.done
                                        ? AppColors.mintOn
                                        : isLight
                                            ? AppColors.neutralOn
                                            : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  chapter.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (hasRecommendedLesson) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.sakuraTrack,
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    '추천 · 이어하기',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.primaryPressed,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                percentText,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  LucideIcons.chevronDown,
                                  size: 18,
                                  color: accentColor.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSizes.progressRadius,
                            ),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: AppSizes.progressHeight,
                              backgroundColor: mutedSurface,
                              color: progressColor,
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
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              bottom: 12,
                            ),
                            child: Column(
                              children: chapter.lessons
                                  .map(
                                    (lesson) => LessonTile(
                                      lesson: lesson,
                                      isRecommended:
                                          lesson.id == recommendedLessonId,
                                    ),
                                  )
                                  .toList(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChapterPathState { done, active, idle }

class _ChapterPathNode extends StatelessWidget {
  const _ChapterPathNode({
    required this.chapterNo,
    required this.state,
    required this.isFirst,
    required this.isLast,
  });

  final int chapterNo;
  final _ChapterPathState state;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = AppColors.lightBorderStrong.withValues(alpha: 0.74);
    final nodeColor = switch (state) {
      _ChapterPathState.done => AppColors.mintPressed,
      _ChapterPathState.active => AppColors.primaryStrong,
      _ChapterPathState.idle => AppColors.neutralContainer,
    };
    final borderColor = switch (state) {
      _ChapterPathState.done => AppColors.mintTrack,
      _ChapterPathState.active => AppColors.sakuraTrack,
      _ChapterPathState.idle => AppColors.lightBorderStrong,
    };
    final textColor =
        state == _ChapterPathState.idle ? AppColors.neutralOn : Colors.white;

    return SizedBox(
      width: 30,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 2,
                color: isFirst ? Colors.transparent : trackColor,
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: nodeColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
              boxShadow: state == _ChapterPathState.active
                  ? [
                      BoxShadow(
                        color: AppColors.primaryStrong.withValues(alpha: 0.24),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '$chapterNo',
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 2,
                color: isLast ? Colors.transparent : trackColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
