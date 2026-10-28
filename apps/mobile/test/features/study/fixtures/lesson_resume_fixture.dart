import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

const resumeLessonId = 'lesson-resume-fixture';
const inProgress = LessonProgressModel(
    status: 'IN_PROGRESS',
    attempts: 0,
    scoreCorrect: 0,
    scoreTotal: 0,
    startedAt: '2026-10-21T01:00:00Z');
const completedProgress = LessonProgressModel(
    status: 'COMPLETED',
    attempts: 1,
    scoreCorrect: 2,
    scoreTotal: 4,
    startedAt: '2026-10-21T01:00:00Z',
    completedAt: '2026-10-21T02:00:00Z');

LessonDetailModel resumeDetail(
        {LessonProgressModel? progress = inProgress,
        String title = 'Fixture lesson',
        bool withReorder = true,
        bool withRecognition = true}) =>
    LessonDetailModel(
      id: resumeLessonId,
      lessonNo: 1,
      chapterLessonNo: 1,
      title: title,
      topic: '인사',
      estimatedMinutes: 10,
      content: LessonContentModel(
          reading: const ReadingModel(scene: '첫 만남', script: [
            ScriptLineModel(
                speaker: 'A',
                voiceId: 'voice',
                text: 'こんにちは',
                translation: '안녕하세요')
          ]),
          questions: [
            if (withRecognition) ...const [
              LessonQuestionModel(
                  order: 2,
                  type: 'VOCAB_MCQ',
                  prompt: 'First choice',
                  options: [
                    QuizOptionModel(id: 'a', text: '첫 보기'),
                    QuizOptionModel(id: 'b', text: '둘째 보기')
                  ]),
              LessonQuestionModel(
                  order: 7,
                  type: 'CONTEXT_CLOZE',
                  prompt: 'Second choice',
                  options: [
                    QuizOptionModel(id: 'c', text: '다음 보기'),
                    QuizOptionModel(id: 'd', text: '마지막 보기')
                  ]),
            ],
            if (withReorder) ...const [
              LessonQuestionModel(
                  order: 11,
                  type: 'SENTENCE_REORDER',
                  prompt: 'First reorder',
                  tokens: ['は', 'は', 'です']),
              LessonQuestionModel(
                  order: 19,
                  type: 'SENTENCE_REORDER',
                  prompt: 'Second reorder',
                  tokens: ['私', 'です']),
            ],
          ]),
      vocabItems: const [
        VocabItemModel(
            id: 'v1',
            word: '犬',
            reading: 'いぬ',
            meaningKo: '개',
            partOfSpeech: 'NOUN'),
        VocabItemModel(
            id: 'v2',
            word: '猫',
            reading: 'ねこ',
            meaningKo: '고양이',
            partOfSpeech: 'NOUN'),
        VocabItemModel(
            id: 'v3',
            word: '本',
            reading: 'ほん',
            meaningKo: '책',
            partOfSpeech: 'NOUN')
      ],
      grammarItems: const [
        GrammarItemModel(
            id: 'g1', pattern: 'です', meaningKo: '입니다', explanation: '설명1'),
        GrammarItemModel(
            id: 'g2', pattern: 'は', meaningKo: '은/는', explanation: '설명2')
      ],
      progress: progress,
    );

class MemoryCheckpointStore implements LessonCheckpointStore {
  final values = <String, String>{};
  final operations = <String>[];
  bool failRead = false;
  bool failWrite = false;
  bool failRemove = false;
  Completer<void>? writeGate;

  Future<void> _queue = Future<void>.value();
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  String key(String owner, String lesson) => '$owner/$lesson';
  @override
  Future<String?> read(String accountId, String lessonId) =>
      _serialized(() async {
        operations.add('read:$accountId');
        if (failRead) throw const LessonCheckpointStorageException();
        return values[key(accountId, lessonId)];
      });

  @override
  Future<void> write(String accountId, String lessonId, String value) =>
      _serialized(() async {
        operations.add('write:$accountId');
        await writeGate?.future;
        if (failWrite) throw const LessonCheckpointStorageException();
        values[key(accountId, lessonId)] = value;
      });

  @override
  Future<void> remove(String accountId, String lessonId) =>
      _serialized(() async {
        operations.add('remove:$accountId');
        if (failRemove) throw const LessonCheckpointStorageException();
        values.remove(key(accountId, lessonId));
      });
}

class ResumeStudyRepository extends Fake implements StudyRepository {
  ResumeStudyRepository({LessonDetailModel? detail})
      : detail = detail ?? resumeDetail();
  LessonDetailModel detail;
  int fetchCalls = 0;
  int startCalls = 0;
  int submitCalls = 0;
  Object? startError;
  Object? submitError;
  Completer<LessonProgressModel>? startGate;
  Completer<LessonSubmitResultModel>? submitGate;
  List<Map<String, dynamic>>? submittedAnswers;
  @override
  Future<LessonDetailModel> fetchLessonDetail(String lessonId) async {
    fetchCalls++;
    return detail;
  }

  @override
  Future<LessonProgressModel> startLesson(String lessonId) async {
    startCalls++;
    if (startError != null) throw startError!;
    return startGate != null
        ? await startGate!.future
        : detail.progress ?? inProgress;
  }

  @override
  Future<LessonSubmitResultModel> submitLesson(
      String lessonId, List<Map<String, dynamic>> answers) async {
    submitCalls++;
    submittedAnswers = answers;
    if (submitError != null) throw submitError!;
    return submitGate != null
        ? await submitGate!.future
        : const LessonSubmitResultModel(
            scoreCorrect: 2, scoreTotal: 4, results: [], status: 'COMPLETED');
  }
}

class ResumeHarness {
  ResumeHarness(
      {MemoryCheckpointStore? store,
      ResumeStudyRepository? repository,
      DateTime Function()? clock,
      this.account = 'account-a'})
      : store = store ?? MemoryCheckpointStore(),
        repository = repository ?? ResumeStudyRepository() {
    container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => account),
      currentAccountReaderProvider.overrideWithValue(() => account),
      lessonCheckpointStoreProvider.overrideWithValue(this.store),
      studyRepositoryProvider.overrideWithValue(this.repository),
      if (clock != null) lessonStudyClockProvider.overrideWithValue(clock),
    ]);
    subscription =
        container.listen(lessonSessionProvider(resumeLessonId), (_, __) {});
  }
  final MemoryCheckpointStore store;
  final ResumeStudyRepository repository;
  String account;
  late final ProviderContainer container;
  late final ProviderSubscription<LessonSessionState> subscription;
  LessonSessionController get controller =>
      container.read(lessonSessionProvider(resumeLessonId).notifier);
  LessonSessionState get state =>
      container.read(lessonSessionProvider(resumeLessonId));
  Future<void> initialize() => controller.initialize(repository.detail);
  Future<void> recognition() async {
    await initialize();
    await controller.startPractice(repository.detail);
  }

  Future<void> matching() async {
    await recognition();
    if (state.hasRecognitionStep) {
      controller.answerRecognition(repository.detail,
          {'order': 2, 'selectedAnswer': 'a', 'responseMs': 0});
      controller.answerRecognition(repository.detail,
          {'order': 7, 'selectedAnswer': 'd', 'responseMs': 0});
    }
  }

  Future<void> reorder() async {
    await matching();
    await controller.completeMatching(
        detail: repository.detail, jlptLevel: 'N5');
  }

  void dispose() {
    subscription.close();
    container.dispose();
  }
}
