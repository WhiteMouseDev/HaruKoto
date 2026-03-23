import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_provider.dart';
import '../providers/study_provider.dart';
import 'widgets/lesson_chapter_list.dart';

class LessonListPage extends ConsumerWidget {
  const LessonListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final jlptLevel =
        profileAsync.hasValue ? profileAsync.value!.jlptLevel : 'N5';
    final chaptersAsync = ref.watch(chaptersProvider(jlptLevel));

    return Scaffold(
      appBar: AppBar(title: const Text('학습')),
      body: chaptersAsync.when(
        data: (data) => SingleChildScrollView(
          child: LessonChapterList(
            chapters: data.chapters,
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
