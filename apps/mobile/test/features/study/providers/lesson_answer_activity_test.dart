import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:harukoto_mobile/features/study/data/lesson_recognition_feedback_repository.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_recognition_feedback.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_session_state.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_study_activity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lesson_activity_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'first choice records attendance and Confirm saves the final choice without grading',
    () async {
      final h = ActivityHarness(preferences: prefs);
      addTearDown(h.dispose);
      await h.start();
      h.controller.selectRecognition('b', expectedOrder: 99);
      h.controller.confirmRecognition(1);
      expect(h.state.recognitionSelection, isNull);
      expect(h.state.answers, isEmpty);

      h.controller.selectRecognition('b');
      await h.controller.flush();
      await h.sync();
      await activityFlush();
      expect(h.repository.posts, hasLength(1));
      expect(h.repository.posts.single['kind'], 'RECOGNITION');
      expect(h.repository.posts.single['answer'], {
        'questionOrder': 1,
        'selectedAnswer': 'b',
      });
      expect(h.state.recognitionSelection, 'b');
      expect(h.state.answers, isEmpty);
      expect(h.study.submissions, 0);
      h.controller.selectRecognition('a');
      h.controller.confirmRecognition(99);
      expect(h.state.answers, isEmpty);
      h.controller.confirmRecognition(1);
      expect(h.state.recognitionIndex, 0);
      expect(h.state.answers[1]!['selectedAnswer'], 'a');
      h.controller.selectRecognition('b');
      h.controller.confirmRecognition(1);
      h.controller.answerRecognition(h.study.detail, h.state.answers[1]!);
      await h.controller.flush();
      await h.sync();
      expect(h.repository.posts, hasLength(1));
      expect(h.state.answers[1]!['selectedAnswer'], 'a');
      expect(h.state.recognitionSelection, isNull);
      expect(h.study.submissions, 0);
    },
  );

  test('cold restore preserves selected answer and makes no new activity',
      () async {
    final repository = ActivityRepositoryFixture();
    final first =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    await first.start();
    first.controller.selectRecognition('b');
    await first.controller.flush();
    await first.sync();
    await activityFlush();
    final id = repository.posts.single['activityId'];
    first.dispose();
    final cold =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    addTearDown(cold.dispose);
    await cold.controller.initialize(cold.study.detail);
    expect(cold.state.recognitionSelection, 'b');
    expect(cold.state.restored, isTrue);
    cold.controller.selectRecognition('b');
    cold.controller.answerRecognition(cold.study.detail,
        {'order': 1, 'selectedAnswer': 'b', 'responseMs': 0});
    await cold.controller.flush();
    await cold.sync();
    expect(repository.posts, hasLength(1));
    expect(repository.posts.single['activityId'], id);
  });

  test('reviewing an earlier answer preserves the later draft and its receipt',
      () async {
    final repository = ActivityRepositoryFixture();
    final detail = activityDetail(secondRecognition: true);
    final first = ActivityHarness(
        preferences: prefs, detail: detail, activityRepository: repository);
    await first.start();
    first.controller.selectRecognition('a', expectedOrder: 1);
    first.controller.confirmRecognition(1);
    first.controller.nextRecognition(1);
    first.controller.selectRecognition('c', expectedOrder: 7);
    first.controller.previousRecognition(7);
    expect(first.state.recognitionIndex, 0);
    await first.controller.flush();
    await first.sync();
    await activityFlush();
    expect(repository.posts, hasLength(2));
    final activityIds =
        repository.posts.map((post) => post['activityId']).toList();
    first.dispose();

    final cold = ActivityHarness(
        preferences: prefs, detail: detail, activityRepository: repository);
    addTearDown(cold.dispose);
    await cold.controller.initialize(detail);
    expect(cold.state.restored, isTrue);
    expect(cold.state.recognitionIndex, 0);
    expect(cold.state.answers[1]?['selectedAnswer'], 'a');
    expect(cold.state.answers[7], isNull);
    cold.controller.nextRecognition(1);
    expect(cold.state.recognitionIndex, 1);
    expect(cold.state.recognitionSelection, 'c');
    cold.controller.selectRecognition('d', expectedOrder: 7);
    cold.controller.confirmRecognition(7);
    cold.controller.nextRecognition(7);
    await cold.controller.flush();
    await cold.sync();
    expect(cold.state.answers[7]?['selectedAnswer'], 'd');
    expect(repository.posts.map((post) => post['activityId']), activityIds);
    expect(cold.study.submissions, 0);
  });

  test('old selected checkpoint upgraded to new server does not backfill',
      () async {
    final old = ActivityHarness(
        preferences: prefs, detail: activityDetail(enabled: false));
    await old.start();
    old.controller.selectRecognition('b');
    await old.controller.flush();
    expect(old.repository.posts, isEmpty);
    final legacy = await old.store.read(activityOwner, activityLesson);
    expect((jsonDecode(legacy!) as Map<String, dynamic>)['version'], 1);
    old.dispose();
    final current = ActivityHarness(preferences: prefs);
    addTearDown(current.dispose);
    await current.controller.initialize(current.study.detail);
    current.controller.answerRecognition(current.study.detail,
        {'order': 1, 'selectedAnswer': 'b', 'responseMs': 0});
    await current.controller.flush();
    await current.sync();
    expect(current.repository.posts, isEmpty);
    expect(await current.store.pendingActivities(activityOwner), isEmpty);
  });

  test(
      'recognition feedback retries the confirmed answer and restores by version',
      () async {
    final answers = _RecognitionFeedbackFixture();
    final detail = activityDetail(recognitionFeedbackVersion: 'revision-1');
    final first = ActivityHarness(
        preferences: prefs, detail: detail, feedbackRepository: answers);
    await first.start();
    first.controller.selectRecognition('a');
    first.controller.selectRecognition('b');
    first.controller.confirmRecognition(1);
    first.controller.confirmRecognition(1);
    await first.controller.requestRecognitionFeedback(1);
    expect(first.state.recognitionFeedbackInFlight, {1});
    expect(first.state.answers[1]?['selectedAnswer'], 'b');
    expect(answers.pending, hasLength(1));
    first.controller.nextRecognition(1);
    expect(first.state.recognitionIndex, 0);
    expect(first.state.answers[1]?['selectedAnswer'], 'b');

    answers.pending.first.completeError(const ApiException(message: 'offline'));
    await activityFlush();
    expect(first.state.recognitionFeedbackInFlight, isEmpty);
    expect(first.state.recognitionFeedback, isEmpty);
    expect(first.state.answers[1]?['selectedAnswer'], 'b');
    final retry = first.controller.requestRecognitionFeedback(1);
    expect(answers.choices, ['b', 'b']);
    answers.pending.last.complete(_wrongFeedback);
    await retry;
    expect(first.state.recognitionFeedback[1]?.correctAnswer, 'a');
    await first.controller.flush();
    await first.sync();
    expect(first.repository.posts, hasLength(1));
    expect(first.study.submissions, 0);
    first.dispose();

    final cold = ActivityHarness(
        preferences: prefs, detail: detail, feedbackRepository: answers);
    addTearDown(cold.dispose);
    await cold.controller.initialize(detail);
    expect(cold.state.recognitionFeedback[1]?.isCorrect, isFalse);
    await cold.controller.requestRecognitionFeedback(1);
    expect(answers.pending, hasLength(2));
    final edited = activityDetail(recognitionFeedbackVersion: 'revision-2');
    final updated = ActivityHarness(
      preferences: prefs,
      detail: edited,
      feedbackRepository: answers,
    );
    addTearDown(updated.dispose);
    await updated.controller.initialize(edited);
    expect(updated.state.answers[1]?['selectedAnswer'], 'b');
    expect(updated.state.recognitionFeedback, isEmpty);
    final outdated = updated.controller.requestRecognitionFeedback(1);
    answers.pending.last.completeError(
      const ApiException(message: 'stale version', statusCode: 409),
    );
    await outdated;
    expect(updated.state.recognitionFeedbackUnavailable, {1});
    await updated.controller.requestRecognitionFeedback(1);
    expect(answers.pending, hasLength(3));
    updated.controller.nextRecognition(1);
    expect(updated.state.step, LessonStep.matching);
    expect(updated.state.answers[1]?['selectedAnswer'], 'b');
  });

  test('late recognition feedback cannot enter a different account draft',
      () async {
    final answers = _RecognitionFeedbackFixture();
    final h = ActivityHarness(
      preferences: prefs,
      feedbackRepository: answers,
      detail: activityDetail(recognitionFeedbackVersion: 'revision-1'),
    );
    addTearDown(h.dispose);
    await h.start();
    h.controller.selectRecognition('b');
    h.controller.confirmRecognition(1);
    await h.controller.flush();
    h.switchAccount(activityOtherOwner);
    await h.start();
    h.controller.selectRecognition('b');
    h.controller.confirmRecognition(1);
    expect(answers.pending, hasLength(2));

    answers.pending.first.complete(_wrongFeedback);
    await activityFlush();
    expect(h.state.recognitionFeedback, isEmpty);
    expect(h.state.recognitionFeedbackInFlight, {1});
    answers.pending.last.complete(_wrongFeedback);
    await activityFlush();
    expect(h.state.recognitionFeedback[1]?.isCorrect, isFalse);
    expect(h.state.recognitionFeedbackInFlight, isEmpty);
  });

  test(
      'missing/null capability retains existing learning without activity HTTP',
      () async {
    final h = ActivityHarness(
        preferences: prefs, detail: activityDetail(enabled: false));
    addTearDown(h.dispose);
    await h.start();
    h.controller.selectRecognition('a');
    await h.controller.flush();
    await h.sync();
    expect(h.state.recognitionSelection, 'a');
    expect(h.repository.posts, isEmpty);
    expect(h.repository.gets, isEmpty);
    expect(await h.store.readActivityAttemptId(activityOwner, activityLesson),
        isNull);
  });

  test(
      'local activity write failure blocks HTTP and preserves same ID on flush retry',
      () async {
    final store = _FailWriteStore(prefs);
    final h = ActivityHarness(preferences: prefs, checkpointStore: store);
    addTearDown(h.dispose);
    await h.start();
    final before = await store.read(activityOwner, activityLesson);
    h.controller.selectRecognition('b');
    expect(await h.controller.flush(), isFalse);
    expect(h.state.storageError, isTrue);
    expect(h.repository.posts, isEmpty);
    expect(await store.read(activityOwner, activityLesson), before);
    final id = store.captured.single.activityId;
    store.fail = false;
    expect(await h.controller.flush(), isTrue);
    await h.sync();
    await activityFlush();
    expect(h.repository.posts.single['activityId'], id);
    expect(h.state.storageError, isFalse);
  });

  test(
      'full wrong matching attempts have distinct IDs, progress-only changes do not',
      () async {
    final h = ActivityHarness(
        preferences: prefs, detail: activityDetail(recognition: false));
    addTearDown(h.dispose);
    await h.start();
    h.controller.updateMatching(matched: {}, left: 0);
    await h.controller.flush();
    await h.sync();
    expect(h.repository.posts, isEmpty);
    h.controller.answerMatching(
        leftVocabularyId: activityWater,
        rightVocabularyId: activityCoffee,
        matched: {},
        left: 0,
        right: 1);
    await h.controller.flush();
    await h.sync();
    await activityFlush();
    final first = h.repository.posts.single;
    h.controller.updateMatching(matched: {});
    h.controller.answerMatching(
        leftVocabularyId: activityWater,
        rightVocabularyId: activityCoffee,
        matched: {},
        left: 0,
        right: 1);
    await h.controller.flush();
    await h.sync();
    expect(h.repository.posts, hasLength(2));
    expect(h.repository.posts.last['activityId'], isNot(first['activityId']));
    expect(h.repository.posts.last['attemptId'], first['attemptId']);
    expect(h.repository.posts.last['answer'], first['answer']);
    expect(h.study.submissions, 0);
  });

  test(
      'wrong distractor reorder is activity only on confirm, final submit stays separate',
      () async {
    final h = ActivityHarness(
        preferences: prefs, detail: activityDetail(recognition: false));
    addTearDown(h.dispose);
    await h.start();
    await h.controller.completeMatching(detail: h.study.detail);
    h.controller.updateReorder(selected: ['水'], available: ['私', 'です', 'コーヒー']);
    await h.controller.flush();
    await h.sync();
    expect(h.repository.posts, isEmpty);
    await h.controller.answerReorder(detail: h.study.detail, answer: {
      'order': 2,
      'submittedOrder': ['水', 'です'],
      'responseMs': 0
    });
    await h.sync();
    await activityFlush();
    expect(h.repository.posts.single['kind'], 'SENTENCE_REORDER');
    expect(h.repository.posts.single['answer'], {
      'questionOrder': 2,
      'submittedOrder': ['水', 'です']
    });
    expect(h.study.submissions, 1);
    expect(h.state.result!.status, 'COMPLETED');
  });

  test('graded completion and explicit reset retain unknown activity receipt',
      () async {
    final repository = ActivityRepositoryFixture()..failures = 20;
    final h = ActivityHarness(
        preferences: prefs,
        activityRepository: repository,
        detail: activityDetail(reorder: false));
    addTearDown(h.dispose);
    await h.start();
    h.controller.selectRecognition('b');
    await h.controller.flush();
    await h.sync();
    await activityFlush();
    final id = repository.posts.single['activityId'];
    h.controller.answerRecognition(
        h.study.detail, {'order': 1, 'selectedAnswer': 'b', 'responseMs': 0});
    await h.controller.completeMatching(detail: h.study.detail);
    expect(h.state.result!.status, 'COMPLETED');
    expect(await h.store.read(activityOwner, activityLesson), isNull);
    expect(await h.store.listLessonIds(activityOwner), isEmpty);
    expect(
        (await h.store.pendingActivities(activityOwner))
            .single
            .request
            .activityId,
        id);
    await h.controller.reset();
    expect(
        (await h.store.pendingActivities(activityOwner))
            .single
            .request
            .activityId,
        id);
    expect(h.study.submissions, 1);
  });
}

const _wrongFeedback = LessonRecognitionFeedback(
  feedbackVersion: 'revision-1',
  questionOrder: 1,
  selectedAnswer: 'b',
  correctAnswer: 'a',
  isCorrect: false,
);

class _RecognitionFeedbackFixture
    implements LessonRecognitionFeedbackRepository {
  final choices = <String>[];
  final pending = <Completer<LessonRecognitionFeedback>>[];

  @override
  Future<LessonRecognitionFeedback> check({
    required String owner,
    required String lessonId,
    required int questionOrder,
    required String feedbackVersion,
    required String selectedAnswer,
  }) {
    choices.add(selectedAnswer);
    final response = Completer<LessonRecognitionFeedback>();
    pending.add(response);
    return response.future;
  }
}

class _FailWriteStore extends PreferencesLessonCheckpointStore {
  _FailWriteStore(super.preferences);
  bool fail = true;
  final captured = <LessonStudyActivityDraft>[];
  @override
  Future<void> writeCheckpointAndActivities(
      String owner,
      String lessonId,
      String checkpoint,
      String attemptId,
      List<LessonStudyActivityDraft> requests) {
    for (final request in requests) {
      if (!captured.any((old) => old.activityId == request.activityId)) {
        captured.add(request);
      }
    }
    if (fail) throw const LessonCheckpointStorageException();
    return super.writeCheckpointAndActivities(
        owner, lessonId, checkpoint, attemptId, requests);
  }
}
