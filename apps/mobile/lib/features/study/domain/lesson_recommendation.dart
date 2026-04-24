import '../data/models/lesson_models.dart';

class RecommendedLessonTarget {
  const RecommendedLessonTarget({
    required this.chapter,
    required this.lesson,
    required this.reason,
  });

  final ChapterModel chapter;
  final LessonSummaryModel lesson;
  final String reason;
}

RecommendedLessonTarget? findRecommendedLesson(List<ChapterModel> chapters) {
  for (final chapter in chapters) {
    for (final lesson in chapter.lessons) {
      if (lesson.status == 'IN_PROGRESS') {
        return RecommendedLessonTarget(
          chapter: chapter,
          lesson: lesson,
          reason: '이어하기',
        );
      }
    }
  }

  for (final chapter in chapters) {
    for (final lesson in chapter.lessons) {
      if (lesson.status != 'COMPLETED') {
        return RecommendedLessonTarget(
          chapter: chapter,
          lesson: lesson,
          reason: '추천 레슨',
        );
      }
    }
  }

  if (chapters.isEmpty || chapters.first.lessons.isEmpty) {
    return null;
  }

  return RecommendedLessonTarget(
    chapter: chapters.first,
    lesson: chapters.first.lessons.first,
    reason: '다시 보기 추천',
  );
}
