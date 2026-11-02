import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
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
      'option tap saves attendance with selection, Next never duplicates or grades',
      () async {
    final h = ActivityHarness(preferences: prefs);
    addTearDown(h.dispose);
    await h.start();
    h.controller.selectRecognition('b');
    await h.controller.flush();
    await h.sync();
    await activityFlush();
    expect(h.repository.posts, hasLength(1));
    expect(h.repository.posts.single['kind'], 'RECOGNITION');
    expect(h.repository.posts.single['answer'],
        {'questionOrder': 1, 'selectedAnswer': 'b'});
    expect(h.state.recognitionSelection, 'b');
    expect(h.state.answers, isEmpty);
    expect(h.study.submissions, 0);
    h.controller.selectRecognition('a');
    h.controller.answerRecognition(
        h.study.detail, {'order': 1, 'selectedAnswer': 'b', 'responseMs': 0});
    await h.controller.flush();
    await h.sync();
    expect(h.repository.posts, hasLength(1));
    expect(h.state.answers[1]!['selectedAnswer'], 'b');
    expect(h.study.submissions, 0);
  });

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
