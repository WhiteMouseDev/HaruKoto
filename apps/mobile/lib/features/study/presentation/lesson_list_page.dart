import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../domain/lesson_recommendation.dart';
import '../providers/study_provider.dart';
import 'widgets/lesson_chapter_list.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jlptLevel = ref.watch(userPreferencesProvider).jlptLevel;
    final chaptersAsync = ref.watch(chaptersProvider(jlptLevel));
    final recommendedLesson = chaptersAsync.hasValue
        ? findRecommendedLesson(chaptersAsync.value!.chapters)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('전체 레슨')),
      body: chaptersAsync.when(
        data: (data) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LessonListIntro(target: recommendedLesson),
              LessonChapterList(
                chapters: data.chapters,
                recommendedLessonId: recommendedLesson?.lesson.id,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('오류가 발생했습니다', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(chaptersProvider(jlptLevel)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonListIntro extends StatelessWidget {
  const _LessonListIntro({required this.target});

  final RecommendedLessonTarget? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = this.target;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.compass,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '추천 경로와 전체 레슨',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            target == null
                ? '관심 있는 주제부터 골라도 돼요'
                : '추천은 먼저 펼쳐두고, 관심 있는 주제도 바로 시작할 수 있어요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.lightSubtext,
            ),
          ),
          if (target != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryStrong.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                '${target.reason} · Ch.${target.chapter.chapterNo} ${target.lesson.title}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
