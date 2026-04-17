import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_page.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LessonPage', () {
    testWidgets(
        'shows a snackbar and clears submission error on submit failure',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final detail = _buildDetail();
      final repository = _FakeStudyRepository(
        detail: detail,
        submitError: Exception('network down'),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LessonPage(lessonId: 'lesson-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await container
          .read(lessonSessionProvider('lesson-1').notifier)
          .submitAnswers(lessonId: 'lesson-1');
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('network down'), findsOneWidget);
      expect(
        container
            .read(lessonSessionProvider('lesson-1'))
            .submissionErrorMessage,
        isNull,
      );
    });
  });
}

class _FakeStudyRepository extends Fake implements StudyRepository {
  _FakeStudyRepository({
    required this.detail,
    this.submitError,
  });

  final LessonDetailModel detail;
  final Object? submitError;

  @override
  Future<LessonDetailModel> fetchLessonDetail(String lessonId) async {
    return detail;
  }

  @override
  Future<LessonSubmitResultModel> submitLesson(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) async {
    if (submitError != null) {
      throw submitError!;
    }

    return const LessonSubmitResultModel(
      scoreCorrect: 0,
      scoreTotal: 0,
      srsItemsRegistered: 0,
      results: [],
      status: 'FAILED',
    );
  }
}

LessonDetailModel _buildDetail() {
  return const LessonDetailModel(
    id: 'lesson-1',
    lessonNo: 1,
    chapterLessonNo: 1,
    title: 'Lesson',
    topic: 'Topic',
    estimatedMinutes: 10,
    content: LessonContentModel(
      reading: ReadingModel(script: []),
      questions: [],
    ),
    vocabItems: [],
    grammarItems: [],
  );
}
