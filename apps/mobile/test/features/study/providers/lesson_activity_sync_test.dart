import 'dart:async';

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

  Future<LessonStudyActivityDraft> enqueue(ActivityHarness h,
      {String lessonId = activityLesson}) async {
    final request = activityDraft();
    await h.store.writeCheckpointAndActivities(
        activityOwner, lessonId, '{"version":1}', request.attemptId, [request]);
    return request;
  }

  test('first POST starts only after durable request and ACK refreshes day',
      () async {
    final h = ActivityHarness(preferences: prefs);
    addTearDown(h.dispose);
    final request = await enqueue(h);
    expect(h.repository.posts, isEmpty);
    await h.sync();
    await activityFlush();
    expect(h.repository.posts.single, request.toJson());
    expect(h.repository.gets, isEmpty);
    expect(await h.store.pendingActivities(activityOwner), isEmpty);
    expect(h.refreshes, 1);
    expect(h.syncState.pendingCount, 0);
    expect(h.study.submissions, 0);
  });

  test('failed first save retries GET then the identical frozen POST',
      () async {
    final h = ActivityHarness(
        preferences: prefs,
        activityRepository: ActivityRepositoryFixture()..failures = 1);
    addTearDown(h.dispose);
    final request = await enqueue(h);
    await h.sync();
    await activityFlush();
    expect(h.repository.receipts, isEmpty);
    expect(h.refreshes, 0);
    expect(h.syncState.pendingCount, 1);
    expect(h.syncState.error, isNotNull);
    expect((await h.store.pendingActivities(activityOwner)).single.attempted,
        isTrue);
    await h.sync();
    await activityFlush();
    expect(h.repository.gets, [request.activityId]);
    expect(h.repository.posts, [request.toJson(), request.toJson()]);
    expect(h.repository.receipts, hasLength(1));
    expect(h.refreshes, 1);
    expect(h.syncState.pendingCount, 0);
  });

  test('commit response loss and cold restart use GET only, even next KST day',
      () async {
    final repository = ActivityRepositoryFixture()
      ..failures = 1
      ..commitBeforeFailure = true;
    final first =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    final request = await enqueue(first);
    await first.sync();
    await activityFlush();
    expect(first.refreshes, 0);
    expect(repository.receipts, hasLength(1));
    await first.store.remove(activityOwner, activityLesson);
    expect(await first.store.listLessonIds(activityOwner), isEmpty);
    first.dispose();
    repository.serverNow = DateTime.utc(2026, 11, 3, 9);
    final cold =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    addTearDown(cold.dispose);
    await cold.sync();
    await activityFlush();
    expect(repository.posts, hasLength(1));
    expect(repository.gets, [request.activityId]);
    expect(repository.receipts[request.activityId]!.studyDate, '2026-11-02');
    expect(cold.refreshes, 1);
    expect(await cold.store.pendingActivities(activityOwner), isEmpty);
  });

  test(
      'first delayed offline acceptance uses server day, not device answer date',
      () async {
    final repository = ActivityRepositoryFixture()
      ..serverNow = DateTime.utc(2026, 11, 3, 0);
    final h =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    addTearDown(h.dispose);
    final request = await enqueue(h);
    expect(request.toJson().keys, isNot(contains('studyDate')));
    await h.sync();
    expect(repository.receipts[request.activityId]!.studyDate, '2026-11-03');
    expect(repository.posts.single, request.toJson());
  });

  test('changed lesson remains pending without blocking another lesson',
      () async {
    final repository = ActivityRepositoryFixture()
      ..rejectedLessons.add(activityLesson);
    final h =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    addTearDown(h.dispose);
    final changed = await enqueue(h);
    final valid = await enqueue(h, lessonId: activityOtherLesson);
    await h.sync();
    await activityFlush();
    expect(repository.posts, hasLength(2));
    expect(repository.receipts.keys, [valid.activityId]);
    expect(
        (await h.store.pendingActivities(activityOwner))
            .single
            .request
            .activityId,
        changed.activityId);
    expect(h.syncState.pendingCount, 1);
    expect(h.syncState.error, isNotNull);
    expect(h.refreshes, 1);
  });

  test('account switch during response does not acknowledge A or refresh B',
      () async {
    final repository = ActivityRepositoryFixture()
      ..postGate = Completer<void>();
    final h =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    addTearDown(h.dispose);
    final request = await enqueue(h);
    final saving = h.sync();
    await activityFlush();
    expect(repository.posts, hasLength(1));
    h.switchAccount(activityOtherOwner);
    await activityFlush();
    repository.postGate!.complete();
    await saving;
    await activityFlush();
    expect(h.refreshes, 0);
    expect(
        (await h.store.pendingActivities(activityOwner))
            .single
            .request
            .activityId,
        request.activityId);
    expect(await h.store.pendingActivities(activityOtherOwner), isEmpty);
    expect(repository.posts, hasLength(1));
  });

  test(
      'malformed journal stays stored and exposes storage failure without HTTP',
      () async {
    final h = ActivityHarness(preferences: prefs);
    addTearDown(h.dispose);
    const broken = '{"version":3,"protocolVersion":88}';
    final key =
        PreferencesLessonCheckpointStore.key(activityOwner, activityLesson);
    await prefs.setString(key, broken);
    await h.sync();
    expect(h.syncState.storageError, isTrue);
    expect(h.syncState.error, isNotNull);
    expect(prefs.getString(key), broken);
    expect(h.repository.posts, isEmpty);
    expect(h.repository.gets, isEmpty);
    expect(h.refreshes, 0);
  });

  test(
      'failed local ACK retains request and recovers original receipt without rePOST',
      () async {
    final store = _FailAckStore(prefs);
    final h = ActivityHarness(preferences: prefs, checkpointStore: store);
    addTearDown(h.dispose);
    await enqueue(h);
    await h.sync();
    await activityFlush();
    expect(h.repository.receipts, hasLength(1));
    expect(h.syncState.pendingCount, 1);
    expect(h.refreshes, 0);
    store.fail = false;
    await h.sync();
    await activityFlush();
    expect(h.repository.posts, hasLength(1));
    expect(h.repository.gets, hasLength(1));
    expect(h.syncState.pendingCount, 0);
    expect(h.refreshes, 1);
  });
}

class _FailAckStore extends PreferencesLessonCheckpointStore {
  _FailAckStore(super.preferences);
  bool fail = true;
  @override
  Future<void> acknowledgeActivity(
      String owner, String lessonId, String activityId) {
    if (fail) throw const LessonCheckpointStorageException();
    return super.acknowledgeActivity(owner, lessonId, activityId);
  }
}
