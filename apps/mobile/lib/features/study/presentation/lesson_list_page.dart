import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('학습')),
      body: chaptersAsync.when(
        data: (data) => SingleChildScrollView(
          child: LessonChapterList(
            chapters: data.chapters,
            recommendedLessonId: recommendedLesson?.lesson.id,
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
