import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_list_page.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_pilot_telemetry_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LessonListPage', () {
    testWidgets('frames the recommendation as guidance in the full list',
        (tester) async {
      final events = <LessonPilotEvent>[];

      await _pumpLessonListPage(
        tester,
        telemetryEvents: events,
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

      expect(find.text('학습'), findsOneWidget);
      expect(find.text('전체 레슨'), findsOneWidget);
      expect(find.text('이어갈 위치를 먼저 보여주고, 전체 경로도 함께 확인해요'), findsOneWidget);
      expect(find.text('추천 레슨 · Ch.1 · 2/2'), findsOneWidget);
      expect(find.text('바로 시작'), findsOneWidget);
      expect(find.text('추천'), findsOneWidget);
      expect(find.text('다음'), findsOneWidget);
      expect(find.text('Lesson 1'), findsOneWidget);
      expect(find.text('Lesson 2'), findsWidgets);

      final viewedEvent = events.singleWhere(
        (event) => event.name == LessonPilotEventNames.lessonListViewed,
      );
      expect(viewedEvent.properties['source'], 'lesson_list');
      expect(viewedEvent.properties['jlptLevel'], 'N5');
      expect(viewedEvent.properties['chapterCount'], 1);
      expect(viewedEvent.properties['lessonCount'], 2);
      expect(viewedEvent.properties['recommendedLessonId'], 'lesson-2');
    });

    testWidgets('shows a readiness empty state for levels without lessons',
        (tester) async {
      final events = <LessonPilotEvent>[];

      await _pumpLessonListPage(
        tester,
        jlptLevel: 'N4',
        telemetryEvents: events,
        chapters: const [],
      );

      expect(find.text('전체 레슨'), findsOneWidget);
      expect(find.text('N4'), findsOneWidget);
      expect(find.text('N4 레슨 준비 중'), findsOneWidget);
      expect(find.text('N5 레슨 보기'), findsOneWidget);
      expect(find.text('추천 레슨'), findsNothing);

      final viewedEvent = events.singleWhere(
        (event) => event.name == LessonPilotEventNames.lessonListViewed,
      );
      expect(viewedEvent.properties['source'], 'lesson_list');
      expect(viewedEvent.properties['jlptLevel'], 'N4');
      expect(viewedEvent.properties['chapterCount'], 0);
      expect(viewedEvent.properties['lessonCount'], 0);
      expect(viewedEvent.properties['recommendedLessonId'], isNull);
    });
  });
}

Future<void> _pumpLessonListPage(
  WidgetTester tester, {
  required List<ChapterModel> chapters,
  String jlptLevel = 'N5',
  List<LessonPilotEvent>? telemetryEvents,
}) async {
  SharedPreferences.setMockInitialValues({'user_jlpt_level': jlptLevel});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        chaptersProvider(jlptLevel).overrideWith(
          (ref) => Future.value(ChapterListModel(chapters: chapters)),
        ),
        if (telemetryEvents != null)
          lessonPilotTelemetrySinkProvider.overrideWith(
            (ref) => telemetryEvents.add,
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
