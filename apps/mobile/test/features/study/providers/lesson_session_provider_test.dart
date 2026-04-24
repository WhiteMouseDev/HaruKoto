import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_pilot_telemetry_provider.dart';
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

    test('startPractice tracks a lesson_started pilot event', () async {
      final repository = _FakeStudyRepository();
      final events = <LessonPilotEvent>[];
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
          lessonPilotTelemetrySinkProvider.overrideWith((ref) => events.add),
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
              type: 'SENTENCE_REORDER',
              prompt: 'reorder-1',
              tokens: ['a', 'b'],
            ),
          ],
        ),
      );

      final startedEvent = events.singleWhere(
        (event) => event.name == LessonPilotEventNames.lessonStarted,
      );
      expect(startedEvent.properties['lessonId'], 'lesson-1');
      expect(startedEvent.properties['lessonNo'], 1);
      expect(startedEvent.properties['hasRecognitionStep'], isTrue);
      expect(startedEvent.properties['hasReorderStep'], isTrue);
      expect(startedEvent.properties['recognitionQuestionCount'], 1);
      expect(startedEvent.properties['reorderQuestionCount'], 1);
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

    test('startPractice exposes an error and does not advance on start failure',
        () async {
      final repository = _FakeStudyRepository()
        ..startError = Exception('locked');
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
          ],
        ),
      );

      final state = container.read(lessonSessionProvider('lesson-1'));
      expect(repository.startLessonCalls, 1);
      expect(state.step, LessonStep.contextPreview);
      expect(state.startErrorMessage, contains('locked'));
      expect(state.answers, isEmpty);
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

    test('successful submit tracks submitted and completed pilot events',
        () async {
      final repository = _FakeStudyRepository();
      final events = <LessonPilotEvent>[];
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
          lessonPilotTelemetrySinkProvider.overrideWith((ref) => events.add),
        ],
      );
      final sub =
          container.listen(lessonSessionProvider('lesson-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final detail = _buildDetail(questions: const []);
      final notifier =
          container.read(lessonSessionProvider('lesson-1').notifier);
      await notifier.startPractice(detail);
      await notifier.completeMatching(
        detail: detail,
        jlptLevel: 'N5',
      );

      expect(
        events.map((event) => event.name),
        containsAllInOrder([
          LessonPilotEventNames.lessonStepCompleted,
          LessonPilotEventNames.lessonSubmitted,
          LessonPilotEventNames.lessonCompleted,
        ]),
      );
      final submittedEvent = events.singleWhere(
        (event) => event.name == LessonPilotEventNames.lessonSubmitted,
      );
      expect(submittedEvent.properties['outcome'], 'success');
      expect(submittedEvent.properties['answerCount'], 0);
      expect(submittedEvent.properties['status'], 'COMPLETED');
      expect(submittedEvent.properties['srsItemsRegistered'], 1);
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

    test('submit failure is exposed through submissionErrorMessage', () async {
      final repository = _FakeStudyRepository()
        ..submitError = Exception('network down');
      final events = <LessonPilotEvent>[];
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
          lessonPilotTelemetrySinkProvider.overrideWith((ref) => events.add),
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
      expect(state.step, LessonStep.matching);
      expect(state.submitting, isFalse);
      expect(state.submissionErrorMessage, contains('network down'));
      final submittedEvent = events.singleWhere(
        (event) => event.name == LessonPilotEventNames.lessonSubmitted,
      );
      expect(submittedEvent.properties['outcome'], 'failure');
      expect(submittedEvent.properties['errorType'], contains('Exception'));
    });

    test('reset tracks a lesson_retry_clicked pilot event', () async {
      final repository = _FakeStudyRepository();
      final events = <LessonPilotEvent>[];
      final container = ProviderContainer(
        overrides: [
          studyRepositoryProvider.overrideWith((ref) => repository),
          lessonPilotTelemetrySinkProvider.overrideWith((ref) => events.add),
        ],
      );
      final sub =
          container.listen(lessonSessionProvider('lesson-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      container.read(lessonSessionProvider('lesson-1').notifier).reset();

      expect(events.single.name, LessonPilotEventNames.lessonRetryClicked);
      expect(events.single.properties['lessonId'], 'lesson-1');
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
  Object? startError;
  Object? submitError;

  @override
  Future<LessonProgressModel> startLesson(String lessonId) async {
    startLessonCalls++;
    if (startError != null) {
      throw startError!;
    }
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
    if (submitError != null) {
      throw submitError!;
    }
    return const LessonSubmitResultModel(
      scoreCorrect: 2,
      scoreTotal: 2,
      results: [],
      status: 'COMPLETED',
      srsItemsRegistered: 1,
    );
  }
}
