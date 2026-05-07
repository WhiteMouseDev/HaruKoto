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

    return Stack(
      children: [
        Positioned(
          left: 14,
          top: isFirst ? 28 : 0,
          bottom: isLast ? 28 : 0,
          child: Container(
            width: 2,
            color: AppColors.lightBorderStrong.withValues(alpha: 0.74),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _ChapterPathNode(
                  chapterNo: chapter.chapterNo,
                  state: state,
                ),
              ),
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
                            _ChapterHeaderRow(
                              chapter: chapter,
                              state: state,
                              accentColor: accentColor,
                              hasRecommendedLesson: hasRecommendedLesson,
                              isExpanded: isExpanded,
                              percentText: percentText,
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
      ],
    );
  }
}

enum _ChapterPathState { done, active, idle }

class _ChapterHeaderRow extends StatelessWidget {
  const _ChapterHeaderRow({
    required this.chapter,
    required this.state,
    required this.accentColor,
    required this.hasRecommendedLesson,
    required this.isExpanded,
    required this.percentText,
  });

  final ChapterModel chapter;
  final _ChapterPathState state;
  final Color accentColor;
  final bool hasRecommendedLesson;
  final bool isExpanded;
  final String percentText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: state == _ChapterPathState.done
                ? AppColors.mintTrack
                : isLight
                    ? AppColors.neutralContainer
                    : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
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
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.sakuraTrack,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                '추천',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryPressed,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
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
    );
  }
}

class _ChapterPathNode extends StatelessWidget {
  const _ChapterPathNode({
    required this.chapterNo,
    required this.state,
  });

  final int chapterNo;
  final _ChapterPathState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return Container(
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
    );
  }
}
