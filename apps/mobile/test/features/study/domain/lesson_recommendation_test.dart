import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_recommendation.dart';

void main() {
  group('findRecommendedLesson', () {
    test('prefers an in-progress lesson', () {
      final chapters = [
        _chapter(
          chapterNo: 1,
          lessons: const [
            LessonSummaryModel(
              id: 'lesson-1',
              lessonNo: 1,
              chapterLessonNo: 1,
              title: 'Lesson 1',
              topic: 'Intro',
              estimatedMinutes: 10,
              status: 'COMPLETED',
              scoreCorrect: 5,
              scoreTotal: 5,
            ),
            LessonSummaryModel(
              id: 'lesson-2',
              lessonNo: 2,
              chapterLessonNo: 2,
              title: 'Lesson 2',
              topic: 'Continue',
              estimatedMinutes: 10,
              status: 'IN_PROGRESS',
              scoreCorrect: 0,
              scoreTotal: 0,
            ),
          ],
        ),
      ];

      final target = findRecommendedLesson(chapters);

      expect(target?.lesson.id, 'lesson-2');
      expect(target?.reason, '이어하기');
    });

    test('falls back to the first incomplete lesson', () {
      final chapters = [
        _chapter(
          chapterNo: 1,
          lessons: const [
            LessonSummaryModel(
              id: 'lesson-1',
              lessonNo: 1,
              chapterLessonNo: 1,
              title: 'Lesson 1',
              topic: 'Intro',
              estimatedMinutes: 10,
              status: 'COMPLETED',
              scoreCorrect: 5,
              scoreTotal: 5,
            ),
            LessonSummaryModel(
              id: 'lesson-2',
              lessonNo: 2,
              chapterLessonNo: 2,
              title: 'Lesson 2',
              topic: 'Next',
              estimatedMinutes: 10,
              status: 'NOT_STARTED',
              scoreCorrect: 0,
              scoreTotal: 0,
            ),
          ],
        ),
      ];

      final target = findRecommendedLesson(chapters);

      expect(target?.lesson.id, 'lesson-2');
      expect(target?.reason, '추천 레슨');
    });

    test('returns a review suggestion when everything is complete', () {
      final chapters = [
        _chapter(
          chapterNo: 1,
          lessons: const [
            LessonSummaryModel(
              id: 'lesson-1',
              lessonNo: 1,
              chapterLessonNo: 1,
              title: 'Lesson 1',
              topic: 'Intro',
              estimatedMinutes: 10,
              status: 'COMPLETED',
              scoreCorrect: 5,
              scoreTotal: 5,
            ),
          ],
        ),
      ];

      final target = findRecommendedLesson(chapters);

      expect(target?.lesson.id, 'lesson-1');
      expect(target?.reason, '다시 보기 추천');
    });
  });
}

ChapterModel _chapter({
  required int chapterNo,
  required List<LessonSummaryModel> lessons,
}) {
  return ChapterModel(
    id: 'chapter-$chapterNo',
    jlptLevel: 'N5',
    partNo: 1,
    chapterNo: chapterNo,
    title: 'Chapter $chapterNo',
    lessons: lessons,
    completedLessons:
        lessons.where((lesson) => lesson.status == 'COMPLETED').length,
    totalLessons: lessons.length,
  );
}
