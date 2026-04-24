import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_list_page.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LessonListPage', () {
    testWidgets('frames the recommendation as guidance in the full list',
        (tester) async {
      await _pumpLessonListPage(
        tester,
        chapters: [
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
                estimatedMinutes: 12,
                status: 'NOT_STARTED',
                scoreCorrect: 0,
                scoreTotal: 0,
              ),
            ],
          ),
        ],
      );

      expect(find.text('전체 레슨'), findsOneWidget);
      expect(find.text('추천 경로와 전체 레슨'), findsOneWidget);
      expect(find.text('추천은 먼저 펼쳐두고, 관심 있는 주제도 바로 시작할 수 있어요'), findsOneWidget);
      expect(find.text('추천 레슨 · Ch.1 Lesson 2'), findsOneWidget);
      expect(find.text('Lesson 1'), findsOneWidget);
      expect(find.text('Lesson 2'), findsOneWidget);
    });
  });
}

Future<void> _pumpLessonListPage(
  WidgetTester tester, {
  required List<ChapterModel> chapters,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        chaptersProvider('N5').overrideWith(
          (ref) => Future.value(ChapterListModel(chapters: chapters)),
        ),
      ],
      child: const MaterialApp(home: LessonListPage()),
    ),
  );

  await tester.pump();
  await tester.pump();
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
