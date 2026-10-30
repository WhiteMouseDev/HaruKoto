import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_service.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('LessonSessionService.startLesson', () {
    late _FakeStudyRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = _FakeStudyRepository();
      container = ProviderContainer(
        overrides: [studyRepositoryProvider.overrideWith((ref) => repository)],
      );
      for (final level in ['N5', 'N4']) {
        container.listen(chaptersProvider(level), (_, __) {});
      }
    });

    tearDown(() => container.dispose());

    test(
      'refreshes cached chapter progress after starting any level',
      () async {
        final n5Before = await container.read(chaptersProvider('N5').future);
        final n4Before = await container.read(chaptersProvider('N4').future);
        expect(_status(n4Before), 'NOT_STARTED');

        await container
            .read(lessonSessionServiceProvider)
            .startLesson('N4-lesson');

        final n5After = await container.read(chaptersProvider('N5').future);
        final n4After = await container.read(chaptersProvider('N4').future);
        expect(repository.fetchCalls, {'N5': 2, 'N4': 2});
        expect(identical(n5After, n5Before), isFalse);
        expect(_status(n5After), 'NOT_STARTED');
        expect(_status(n4After), 'IN_PROGRESS');
      },
    );

    test('preserves cached chapters when starting a lesson fails', () async {
      final n5Before = await container.read(chaptersProvider('N5').future);
      final n4Before = await container.read(chaptersProvider('N4').future);
      repository.startError = StateError('Start failed');

      await expectLater(
        container.read(lessonSessionServiceProvider).startLesson('N4-lesson'),
        throwsStateError,
      );

      final n5After = await container.read(chaptersProvider('N5').future);
      final n4After = await container.read(chaptersProvider('N4').future);
      expect(repository.fetchCalls, {'N5': 1, 'N4': 1});
      expect(identical(n5After, n5Before), isTrue);
      expect(identical(n4After, n4Before), isTrue);
      expect(_status(n4After), 'NOT_STARTED');
    });
  });
}

String _status(ChapterListModel chapters) =>
    chapters.chapters.single.lessons.single.status;

class _FakeStudyRepository extends Fake implements StudyRepository {
  final fetchCalls = <String, int>{};
  String? startedLessonId;
  Object? startError;

  @override
  Future<ChapterListModel> fetchChapters(String jlptLevel) async {
    fetchCalls.update(jlptLevel, (count) => count + 1, ifAbsent: () => 1);
    final lessonId = '$jlptLevel-lesson';
    return ChapterListModel(
      chapters: [
        ChapterModel(
          id: '$jlptLevel-chapter',
          jlptLevel: jlptLevel,
          partNo: 1,
          chapterNo: 1,
          title: 'Chapter',
          lessons: [
            LessonSummaryModel(
              id: lessonId,
              lessonNo: 1,
              chapterLessonNo: 1,
              title: 'Lesson',
              topic: 'Topic',
              estimatedMinutes: 10,
              status:
                  startedLessonId == lessonId ? 'IN_PROGRESS' : 'NOT_STARTED',
              scoreCorrect: 0,
              scoreTotal: 0,
            ),
          ],
          completedLessons: 0,
          totalLessons: 1,
        ),
      ],
    );
  }

  @override
  Future<LessonProgressModel> startLesson(String lessonId) async {
    if (startError != null) throw startError!;
    startedLessonId = lessonId;
    return const LessonProgressModel(
      status: 'IN_PROGRESS',
      attempts: 1,
      scoreCorrect: 0,
      scoreTotal: 0,
    );
  }
}
