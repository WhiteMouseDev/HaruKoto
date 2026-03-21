import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    final progress = chapter.totalLessons > 0
        ? chapter.completedLessons / chapter.totalLessons
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ch.${chapter.chapterNo}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(chapter.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Text(
                  '${chapter.completedLessons}/${chapter.totalLessons}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
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

  IconData get _statusIcon {
    if (_isPerfect) return Icons.star;
    switch (lesson.status) {
      case 'COMPLETED':
        return Icons.check_circle;
      case 'IN_PROGRESS':
        return Icons.play_circle;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _statusColor(ThemeData theme) {
    if (_isPerfect) return Colors.amber;
    switch (lesson.status) {
      case 'COMPLETED':
        return Colors.green;
      case 'IN_PROGRESS':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_statusIcon, color: _statusColor(theme)),
      title: Text(lesson.title, style: theme.textTheme.bodyMedium),
      subtitle: Text('${lesson.estimatedMinutes}분 · ${lesson.topic}',
          style: theme.textTheme.bodySmall),
      trailing: lesson.status == 'COMPLETED'
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '복습 예약',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${lesson.scoreCorrect}/${lesson.scoreTotal}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: () => context.push('/study/lessons/${lesson.id}'),
    );
  }
}
