import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/data/models/review_summary_model.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_list_page.dart';
import 'package:harukoto_mobile/features/study/presentation/study_page.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final fullList in [false, true]) {
      testWidgets(
        '${fullList ? 'LessonListPage' : 'StudyPage'} supports 320px large text in $brightness',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          SharedPreferences.setMockInitialValues({
            'user_jlpt_level': 'N5',
            'user_show_kana': true,
          });
          final preferences = await SharedPreferences.getInstance();
          await tester.pumpWidget(ProviderScope(
            overrides: [
              currentAccountIdProvider.overrideWithValue('test-account'),
              currentAccountReaderProvider
                  .overrideWithValue(() => 'test-account'),
              sharedPreferencesProvider.overrideWithValue(preferences),
              dashboardProvider.overrideWith((ref) async => _dashboard),
              reviewSummaryProvider('N5').overrideWith((ref) async =>
                  const ReviewSummaryModel(
                      wordDue: 2,
                      grammarDue: 5,
                      totalDue: 7,
                      wordNew: 0,
                      grammarNew: 0)),
              chaptersProvider('N5').overrideWith((ref) async => _chapters),
            ],
            child: MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                  brightness: brightness,
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: fullList ? const LessonListPage() : const StudyPage(),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scroll = fullList
              ? find.byType(SingleChildScrollView).first
              : find.byType(CustomScrollView).first;
          for (var index = 0; index < 6; index++) {
            await tester.drag(scroll, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (!fullList) expect(find.text('가나 부트캠프'), findsOneWidget);
        },
      );
    }
  }
}

const _chapters = ChapterListModel(chapters: [
  ChapterModel(
      id: 'chapter-1',
      jlptLevel: 'N5',
      partNo: 1,
      chapterNo: 1,
      title: '인사와 자기소개를 익혀요',
      completedLessons: 0,
      totalLessons: 1,
      lessons: [
        LessonSummaryModel(
            id: 'lesson-1',
            lessonNo: 1,
            chapterLessonNo: 1,
            title: '처음 만난 사람에게 인사하기',
            topic: '기초 인사와 자기소개',
            estimatedMinutes: 5,
            status: 'IN_PROGRESS',
            scoreCorrect: 0,
            scoreTotal: 0),
      ]),
]);
const _dashboard = DashboardModel(
  showKana: true,
  today: TodayStats(
      wordsStudied: 0,
      quizzesCompleted: 0,
      correctAnswers: 0,
      totalAnswers: 0,
      xpEarned: 0,
      goalProgress: 0,
      hasStudied: false),
  streak: StreakData(
      current: 0, longest: 0, studiedToday: false, needsActionToday: false),
  weeklyStats: [],
  kanaProgress: KanaProgressData(
    hiragana: KanaStat(learned: 5, total: 46, pct: 10),
    katakana: KanaStat(learned: 0, total: 46, pct: 0),
  ),
);
