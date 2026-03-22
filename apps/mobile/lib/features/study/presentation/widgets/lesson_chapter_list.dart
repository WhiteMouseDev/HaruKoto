import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

/// Reusable chapter list widget used both inline in StudyPage
/// and in the standalone LessonListPage.
class LessonChapterList extends StatefulWidget {
  final List<ChapterModel> chapters;
  final EdgeInsetsGeometry padding;

  const LessonChapterList({
    super.key,
    required this.chapters,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<LessonChapterList> createState() => _LessonChapterListState();
}

class _LessonChapterListState extends State<LessonChapterList> {
  String? _expandedChapterId;

  @override
  void initState() {
    super.initState();
    _expandedChapterId = _findDefaultExpanded();
  }

  @override
  void didUpdateWidget(covariant LessonChapterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapters != widget.chapters) {
      _expandedChapterId = _findDefaultExpanded();
    }
  }

  /// Find the chapter to expand by default:
  /// 1. First chapter with IN_PROGRESS lessons
  /// 2. First chapter that's not fully complete
  /// 3. First chapter
  String? _findDefaultExpanded() {
    // 1. In-progress chapter
    for (final ch in widget.chapters) {
      if (ch.lessons.any((l) => l.status == 'IN_PROGRESS')) return ch.id;
    }
    // 2. First incomplete chapter
    for (final ch in widget.chapters) {
      if (ch.completedLessons < ch.totalLessons) return ch.id;
    }
    // 3. First chapter
    return widget.chapters.isNotEmpty ? widget.chapters.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: widget.padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.chapters.length,
      itemBuilder: (context, index) {
        final chapter = widget.chapters[index];
        return ChapterCard(
          chapter: chapter,
          isExpanded: _expandedChapterId == chapter.id,
          onToggle: () {
            setState(() {
              _expandedChapterId =
                  _expandedChapterId == chapter.id ? null : chapter.id;
            });
          },
        );
      },
    );
  }
}

/// A card displaying a single chapter with accordion expand/collapse.
class ChapterCard extends StatelessWidget {
  final ChapterModel chapter;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.isExpanded,
    required this.onToggle,
  });

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
      child: Column(
        children: [
          // Header (tappable for accordion toggle)
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
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusFull),
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
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
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
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      color: isComplete
                          ? AppColors.success(brightness)
                          : AppColors.primaryStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lesson list (animated expand/collapse)
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
                          .map((lesson) => LessonTile(lesson: lesson))
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

    // State-dependent styles — pink brand + green success 2-axis
    final Color bgColor;
    final IconData iconData;
    final Color iconColor;

    if (_isPerfect) {
      // Perfect: brand pink highlight (instead of yellow)
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
