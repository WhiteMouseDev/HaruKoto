import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('LessonSessionController', () {
    test('startPractice enters recognition when recognition questions exist',
        () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      final sub =
          container.listen(lessonSessionProvider('lesson-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier =
          container.read(lessonSessionProvider('lesson-1').notifier);
      await notifier.startPractice(
        _buildDetail(
          questions: const [
            LessonQuestionModel(
              order: 1,
              type: 'VOCAB_MCQ',
              prompt: 'question-1',
            ),
            LessonQuestionModel(
              order: 2,
              type: 'CONTEXT_CLOZE',
              prompt: 'question-2',
            ),
          ],
        ),
      );

      final state = container.read(lessonSessionProvider('lesson-1'));
      expect(repository.startLessonCalls, 1);
      expect(state.step, LessonStep.recognition);
      expect(state.recognitionIndex, 0);
      expect(state.answers, isEmpty);
    });

    test('answerRecognition advances through questions into matching',
        () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      final sub =
          container.listen(lessonSessionProvider('lesson-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final detail = _buildDetail(
        questions: const [
          LessonQuestionModel(
            order: 1,
            type: 'VOCAB_MCQ',
            prompt: 'question-1',
          ),
          LessonQuestionModel(
            order: 2,
            type: 'CONTEXT_CLOZE',
            prompt: 'question-2',
          ),
        ],
      );

      final notifier =
          container.read(lessonSessionProvider('lesson-1').notifier);
      await notifier.startPractice(detail);
      notifier.answerRecognition(detail, const {
        'order': 1,
        'selectedAnswer': 'a',
        'responseMs': 0,
      });

      var state = container.read(lessonSessionProvider('lesson-1'));
      expect(state.step, LessonStep.recognition);
      expect(state.recognitionIndex, 1);
      expect(state.answers.keys, contains(1));

      notifier.answerRecognition(detail, const {
        'order': 2,
        'selectedAnswer': 'b',
        'responseMs': 0,
      });

      state = container.read(lessonSessionProvider('lesson-1'));
      expect(state.step, LessonStep.matching);
      expect(state.answers.keys.toSet(), equals({1, 2}));
    });

    test('completeMatching submits immediately when no reorder exists',
        () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      final sub =
          container.listen(lessonSessionProvider('lesson-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final detail = _buildDetail(
        questions: const [],
      );
      final notifier =
          container.read(lessonSessionProvider('lesson-1').notifier);
      await notifier.startPractice(detail);
      await notifier.completeMatching(
        detail: detail,
        jlptLevel: 'N4',
      );

      final state = container.read(lessonSessionProvider('lesson-1'));
      expect(repository.submitLessonCalls, 1);
      expect(repository.submittedLessonId, detail.id);
      expect(state.step, LessonStep.result);
      expect(state.result, isNotNull);
    });

    test('answerReorder submits after the final reorder answer', () async {
      final repository = _FakeStudyRepository();
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      final sub =
          container.listen(lessonSessionProvider('lesson-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final detail = _buildDetail(
        questions: const [
          LessonQuestionModel(
            order: 3,
            type: 'SENTENCE_REORDER',
            prompt: 'reorder-1',
            tokens: ['a', 'b'],
          ),
          LessonQuestionModel(
            order: 4,
            type: 'SENTENCE_REORDER',
            prompt: 'reorder-2',
            tokens: ['c', 'd'],
          ),
        ],
      );

      final notifier =
          container.read(lessonSessionProvider('lesson-1').notifier);
      await notifier.startPractice(detail);
      await notifier.completeMatching(
        detail: detail,
        jlptLevel: 'N4',
      );

      var state = container.read(lessonSessionProvider('lesson-1'));
      expect(state.step, LessonStep.sentenceReorder);

      await notifier.answerReorder(
        detail: detail,
        jlptLevel: 'N4',
        answer: const {
          'order': 3,
          'submittedOrder': ['a', 'b'],
          'responseMs': 0,
        },
      );

      state = container.read(lessonSessionProvider('lesson-1'));
      expect(state.step, LessonStep.sentenceReorder);
      expect(state.reorderIndex, 1);

      await notifier.answerReorder(
        detail: detail,
        jlptLevel: 'N4',
        answer: const {
          'order': 4,
          'submittedOrder': ['c', 'd'],
          'responseMs': 0,
        },
      );

      state = container.read(lessonSessionProvider('lesson-1'));
      expect(repository.submitLessonCalls, 1);
      expect(repository.submittedAnswers!.map((e) => e['order']), [3, 4]);
      expect(state.step, LessonStep.result);
    });
  });
}

LessonDetailModel _buildDetail({
  required List<LessonQuestionModel> questions,
}) {
  return LessonDetailModel(
    id: 'lesson-1',
    lessonNo: 1,
    chapterLessonNo: 1,
    title: 'Lesson',
    topic: 'Topic',
    estimatedMinutes: 10,
    content: LessonContentModel(
      reading: const ReadingModel(
        script: [],
      ),
      questions: questions,
    ),
    vocabItems: const [],
    grammarItems: const [],
  );
}

class _FakeStudyRepository extends Fake implements StudyRepository {
  int startLessonCalls = 0;
  int submitLessonCalls = 0;
  String? submittedLessonId;
  List<Map<String, dynamic>>? submittedAnswers;

  @override
  Future<LessonProgressModel> startLesson(String lessonId) async {
    startLessonCalls++;
    return const LessonProgressModel(
      status: 'IN_PROGRESS',
      attempts: 1,
      scoreCorrect: 0,
      scoreTotal: 0,
    );
  }

  @override
  Future<LessonSubmitResultModel> submitLesson(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) async {
    submitLessonCalls++;
    submittedLessonId = lessonId;
    submittedAnswers = answers;
    return const LessonSubmitResultModel(
      scoreCorrect: 2,
      scoreTotal: 2,
      results: [],
      status: 'COMPLETED',
      srsItemsRegistered: 1,
    );
  }
}
