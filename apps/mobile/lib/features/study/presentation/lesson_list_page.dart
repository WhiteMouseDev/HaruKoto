import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/lesson_models.dart';
import '../providers/study_provider.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider('N5'));

    return Scaffold(
      appBar: AppBar(title: const Text('학습')),
      body: chaptersAsync.when(
        data: (data) => _ChapterList(chapters: data.chapters),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('오류가 발생했습니다', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(chaptersProvider('N5')),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterList extends StatelessWidget {
  final List<ChapterModel> chapters;
  const _ChapterList({required this.chapters});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      itemBuilder: (context, index) => _ChapterCard(chapter: chapters[index]),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final ChapterModel chapter;
  const _ChapterCard({required this.chapter});

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
            ...chapter.lessons.map((lesson) => _LessonTile(lesson: lesson)),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final LessonSummaryModel lesson;
  const _LessonTile({required this.lesson});

  IconData get _statusIcon {
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
          ? Text('${lesson.scoreCorrect}/${lesson.scoreTotal}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.green, fontWeight: FontWeight.bold))
          : const Icon(Icons.chevron_right),
      onTap: () => context.push('/study/lessons/${lesson.id}'),
    );
  }
}
