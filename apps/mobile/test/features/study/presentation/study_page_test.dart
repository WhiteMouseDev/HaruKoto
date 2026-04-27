import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/data/models/review_summary_model.dart';
import 'package:harukoto_mobile/features/study/presentation/study_page.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_pilot_telemetry_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StudyPage', () {
    testWidgets('shows recommended lesson copy for the first incomplete lesson',
        (tester) async {
      final events = <LessonPilotEvent>[];

      await _pumpStudyPage(
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

      expect(find.text('추천 레슨'), findsNWidgets(2));
      expect(find.text('전체 레슨'), findsOneWidget);
      expect(find.text('시작하기'), findsOneWidget);
      expect(find.text('추천'), findsOneWidget);
      expect(find.text('Lesson 2'), findsWidgets);

      final viewedEvent = events.singleWhere(
        (event) => event.name == LessonPilotEventNames.lessonListViewed,
      );
      expect(viewedEvent.properties['source'], 'study_home');
      expect(viewedEvent.properties['jlptLevel'], 'N5');
      expect(viewedEvent.properties['chapterCount'], 1);
      expect(viewedEvent.properties['lessonCount'], 2);
      expect(viewedEvent.properties['recommendedLessonId'], 'lesson-2');
    });

    testWidgets('shows resume copy for an in-progress lesson', (tester) async {
      await _pumpStudyPage(
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
                status: 'IN_PROGRESS',
                scoreCorrect: 2,
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

      expect(find.text('이어하기'), findsNWidgets(3));
      expect(find.text('전체 레슨'), findsOneWidget);
      expect(find.text('추천'), findsOneWidget);
      expect(find.text('Lesson 1'), findsWidgets);
      expect(find.text('추천 레슨'), findsNothing);
    });

    testWidgets('tracks review CTA when due items are available',
        (tester) async {
      final events = <LessonPilotEvent>[];

      await _pumpStudyPage(
        tester,
        telemetryEvents: events,
        reviewSummary: const ReviewSummaryModel(
          wordDue: 2,
          grammarDue: 5,
          totalDue: 7,
          wordNew: 0,
          grammarNew: 0,
        ),
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
            ],
          ),
        ],
      );

      expect(find.text('복습 대기 7개'), findsOneWidget);
      expect(find.text('단어 2 · 문법 5'), findsOneWidget);

      await tester.tap(find.text('복습 시작'));

      final event = events.singleWhere(
        (event) => event.name == LessonPilotEventNames.reviewCtaClicked,
      );
      expect(event.properties['jlptLevel'], 'N5');
      expect(event.properties['totalDue'], 7);
      expect(event.properties['wordDue'], 2);
      expect(event.properties['grammarDue'], 5);
      expect(event.properties['quizType'], 'GRAMMAR');
    });
  });
}

Future<void> _pumpStudyPage(
  WidgetTester tester, {
  required List<ChapterModel> chapters,
  List<LessonPilotEvent>? telemetryEvents,
  ReviewSummaryModel reviewSummary = const ReviewSummaryModel(
    wordDue: 0,
    grammarDue: 0,
    totalDue: 0,
    wordNew: 0,
    grammarNew: 0,
  ),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        dashboardProvider.overrideWith(
          (ref) => Future.value(_dashboard()),
        ),
        reviewSummaryProvider('N5').overrideWith(
          (ref) => Future.value(reviewSummary),
        ),
        chaptersProvider('N5').overrideWith(
          (ref) => Future.value(ChapterListModel(chapters: chapters)),
        ),
        if (telemetryEvents != null)
          lessonPilotTelemetrySinkProvider.overrideWith(
            (ref) => telemetryEvents.add,
          ),
      ],
      child: const MaterialApp(home: StudyPage()),
    ),
  );

  await tester.pump();
  await tester.pump();
}

DashboardModel _dashboard() {
  return const DashboardModel(
    showKana: false,
    today: TodayStats(
      wordsStudied: 0,
      quizzesCompleted: 0,
      correctAnswers: 0,
      totalAnswers: 0,
      xpEarned: 0,
      goalProgress: 0,
    ),
    streak: StreakData(current: 0, longest: 0),
    weeklyStats: [],
  );
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
