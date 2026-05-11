import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colors.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../my/providers/settings_sync_provider.dart';
import '../domain/lesson_recommendation.dart';
import '../providers/lesson_pilot_telemetry_provider.dart';
import '../providers/study_provider.dart';
import 'widgets/lesson_chapter_list.dart';
import 'widgets/lesson_continue_banner.dart';
import 'widgets/lesson_level_empty_state.dart';

class LessonListPage extends ConsumerStatefulWidget {
  const LessonListPage({super.key});

  @override
  ConsumerState<LessonListPage> createState() => _LessonListPageState();
}

class _LessonListPageState extends ConsumerState<LessonListPage> {
  final _trackedLessonListViews = <String>{};

  @override
  Widget build(BuildContext context) {
    final jlptLevel = ref.watch(userPreferencesProvider).jlptLevel;
    final chaptersAsync = ref.watch(chaptersProvider(jlptLevel));
    final recommendedLesson = chaptersAsync.hasValue
        ? findRecommendedLesson(chaptersAsync.value!.chapters)
        : null;
    final chapterList = chaptersAsync.hasValue ? chaptersAsync.value! : null;
    if (chapterList != null) {
      _trackLessonListViewedOnce(
        jlptLevel: jlptLevel,
        source: 'lesson_list',
        chapterCount: chapterList.chapters.length,
        lessonCount: chapterList.chapters.fold<int>(
          0,
          (total, chapter) => total + chapter.lessons.length,
        ),
        recommendedLessonId: recommendedLesson?.lesson.id,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('학습')),
      body: chaptersAsync.when(
        data: (data) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LessonListHeader(
                jlptLevel: jlptLevel,
                target: recommendedLesson,
              ),
              if (recommendedLesson != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: LessonContinueBanner(target: recommendedLesson),
                ),
              if (data.chapters.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: LessonLevelEmptyState(
                    jlptLevel: jlptLevel,
                    onSwitchToN5: jlptLevel == 'N5'
                        ? null
                        : () => ref
                            .read(settingsSyncServiceProvider)
                            .updateJlptLevel('N5'),
                  ),
                )
              else
                LessonChapterList(
                  chapters: data.chapters,
                  recommendedLessonId: recommendedLesson?.lesson.id,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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

  void _trackLessonListViewedOnce({
    required String jlptLevel,
    required String source,
    required int chapterCount,
    required int lessonCount,
    String? recommendedLessonId,
  }) {
    final key = [
      source,
      jlptLevel,
      chapterCount,
      lessonCount,
      recommendedLessonId,
    ].join(':');
    if (!_trackedLessonListViews.add(key)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(lessonPilotTelemetryProvider).trackLessonListViewed(
            jlptLevel: jlptLevel,
            source: source,
            chapterCount: chapterCount,
            lessonCount: lessonCount,
            recommendedLessonId: recommendedLessonId,
          );
    });
  }
}

class _LessonListHeader extends StatelessWidget {
  const _LessonListHeader({
    required this.jlptLevel,
    required this.target,
  });

  final String jlptLevel;
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
              Expanded(
                child: Text(
                  '전체 레슨',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neutralContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  jlptLevel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.neutralOn,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            target == null
                ? '관심 있는 주제부터 골라도 돼요'
                : '이어갈 위치를 먼저 보여주고, 전체 경로도 함께 확인해요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.lightSubtext,
            ),
          ),
        ],
      ),
    );
  }
}
