import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/lesson_models.dart';
import '../../providers/study_map_config.dart';
import 'legacy_lesson_chapter_list.dart';
import 'lesson_station_list.dart';

export 'lesson_chapter_card.dart';
export 'lesson_tile.dart';

/// Shared presentation switch for StudyPage and LessonListPage.
class LessonChapterList extends ConsumerWidget {
  const LessonChapterList({
    super.key,
    required this.chapters,
    this.padding = const EdgeInsets.all(16),
    this.recommendedLessonId,
  });

  final List<ChapterModel> chapters;
  final EdgeInsetsGeometry padding;
  final String? recommendedLessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(studyMapEnabledProvider)) {
      return LegacyLessonChapterList(
        chapters: chapters,
        padding: padding,
        recommendedLessonId: recommendedLessonId,
      );
    }
    return LessonStationList(
      chapters: chapters,
      padding: padding,
      recommendedLessonId: recommendedLessonId,
    );
  }
}
