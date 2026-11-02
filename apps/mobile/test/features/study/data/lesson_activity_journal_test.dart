import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lesson_activity_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late PreferencesLessonCheckpointStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'auth-fixture': 'kept', 'show_kana': true});
    prefs = await SharedPreferences.getInstance();
    store = PreferencesLessonCheckpointStore(prefs);
  });

  for (final version in [1, 2]) {
    test('legacy v$version remains byte-identical and creates no activities',
        () async {
      final raw =
          '{"version":$version,"lessonId":"$activityLesson","answers":{}}';
      await store.write(activityOwner, activityLesson, raw);
      expect(await store.read(activityOwner, activityLesson), raw);
      expect(await store.pendingActivities(activityOwner), isEmpty);
      expect(
          prefs.getString(PreferencesLessonCheckpointStore.key(
              activityOwner, activityLesson)),
          raw);
      expect(await store.readActivityAttemptId(activityOwner, activityLesson),
          isNull);
    });
  }

  test(
      'one durable write contains both answer checkpoint and immutable request',
      () async {
    final request = activityDraft();
    const checkpoint = '{"version":1,"recognitionSelection":"b"}';
    await store.writeCheckpointAndActivities(activityOwner, activityLesson,
        checkpoint, request.attemptId, [request]);
    final raw = jsonDecode(prefs.getString(PreferencesLessonCheckpointStore.key(
        activityOwner, activityLesson))!) as Map<String, dynamic>;
    expect(raw['version'], 3);
    expect(raw['checkpoint'], checkpoint);
    expect(raw['activities'], hasLength(1));
    final cold = PreferencesLessonCheckpointStore(prefs);
    expect(await cold.read(activityOwner, activityLesson), checkpoint);
    expect(
        canonicalActivity(
            (await cold.pendingActivities(activityOwner)).single.request),
        canonicalActivity(request));
    expect(await cold.readActivityAttemptId(activityOwner, activityLesson),
        request.attemptId);
    expect(prefs.getString('auth-fixture'), 'kept');
    expect(prefs.getBool('show_kana'), isTrue);
  });

  test('ACK, route persistence and attempted marking serialize without clobber',
      () async {
    final a = activityDraft();
    final b = activityDraft(attemptId: a.attemptId);
    await store.writeCheckpointAndActivities(
        activityOwner, activityLesson, 'before', a.attemptId, [a, b]);
    final ack =
        store.acknowledgeActivity(activityOwner, activityLesson, a.activityId);
    final write =
        store.write(activityOwner, activityLesson, 'newer route position');
    final attempted = store.markActivityAttempted(
        activityOwner, activityLesson, b.activityId);
    await Future.wait([ack, write, attempted]);
    final pending = await store.pendingActivities(activityOwner);
    expect(pending.single.request.activityId, b.activityId);
    expect(pending.single.attempted, isTrue);
    expect(await store.read(activityOwner, activityLesson),
        'newer route position');
  });

  test('new answer concurrent with ACK keeps new event and latest checkpoint',
      () async {
    final a = activityDraft();
    final b = activityDraft(attemptId: a.attemptId);
    await store.writeCheckpointAndActivities(
        activityOwner, activityLesson, 'first', a.attemptId, [a]);
    final newAnswer = store.writeCheckpointAndActivities(
        activityOwner, activityLesson, 'second', a.attemptId, [b]);
    final ack =
        store.acknowledgeActivity(activityOwner, activityLesson, a.activityId);
    await Future.wait([newAnswer, ack]);
    expect(await store.read(activityOwner, activityLesson), 'second');
    expect(
        (await store.pendingActivities(activityOwner))
            .single
            .request
            .activityId,
        b.activityId);
  });

  test(
      'final submission cleanup keeps pending tombstone reachable after cold restart',
      () async {
    final request = activityDraft();
    await store.writeCheckpointAndActivities(activityOwner, activityLesson,
        '{"version":2,"submission":"unchanged"}', request.attemptId, [request]);
    await store.remove(activityOwner, activityLesson);
    final cold = PreferencesLessonCheckpointStore(prefs);
    expect(await cold.read(activityOwner, activityLesson), isNull);
    expect(await cold.listLessonIds(activityOwner), isEmpty);
    expect(
        (await cold.pendingActivities(activityOwner)).single.request.activityId,
        request.activityId);
    await cold.acknowledgeActivity(
        activityOwner, activityLesson, request.activityId);
    expect(await cold.pendingActivities(activityOwner), isEmpty);
    expect(
        prefs.containsKey(PreferencesLessonCheckpointStore.key(
            activityOwner, activityLesson)),
        isFalse);
  });

  test(
      'explicit new attempt preserves old pending request and separates identity',
      () async {
    final old = activityDraft();
    await store.writeCheckpointAndActivities(
        activityOwner, activityLesson, 'old draft', old.attemptId, [old]);
    await store.remove(activityOwner, activityLesson);
    final fresh = activityDraft();
    await store.writeCheckpointAndActivities(
        activityOwner, activityLesson, 'new draft', fresh.attemptId, [fresh]);
    expect(fresh.attemptId, isNot(old.attemptId));
    expect(await store.pendingActivities(activityOwner), hasLength(2));
    await store.acknowledgeActivity(
        activityOwner, activityLesson, old.activityId);
    expect(await store.read(activityOwner, activityLesson), 'new draft');
    expect(await store.readActivityAttemptId(activityOwner, activityLesson),
        fresh.attemptId);
  });

  test(
      'account separation and malformed v3 retain data without sending or deleting',
      () async {
    final request = activityDraft();
    await store.writeCheckpointAndActivities(
        activityOwner, activityLesson, 'a draft', request.attemptId, [request]);
    await store.write(activityOtherOwner, activityLesson, 'b draft');
    expect(await store.pendingActivities(activityOtherOwner), isEmpty);
    expect(await store.read(activityOtherOwner, activityLesson), 'b draft');
    final key =
        PreferencesLessonCheckpointStore.key(activityOwner, activityLesson);
    const broken = '{"version":3,"protocolVersion":99}';
    await prefs.setString(key, broken);
    await expectLater(store.read(activityOwner, activityLesson),
        throwsA(isA<LessonCheckpointStorageException>()));
    await expectLater(store.pendingActivities(activityOwner),
        throwsA(isA<LessonCheckpointStorageException>()));
    expect(prefs.getString(key), broken);
    expect(await store.read(activityOtherOwner, activityLesson), 'b draft');
  });

  test('frozen request and lists cannot change after enqueue construction', () {
    final tokens = ['水', 'です'];
    final request = activityDraft(
        kind: 'SENTENCE_REORDER',
        answer: {'questionOrder': 2, 'submittedOrder': tokens});
    final original = canonicalActivity(request);
    tokens[0] = '私';
    final returned = request.toJson();
    (returned['answer'] as Map<String, dynamic>)['questionOrder'] = 999;
    expect(canonicalActivity(request), original);
    expect(() => request.answer['questionOrder'] = 3, throwsUnsupportedError);
    expect(() => (request.answer['submittedOrder'] as List)[0] = '私',
        throwsUnsupportedError);
  });

  for (final invalid in <String, Map<String, dynamic>>{
    'zero question order': {
      'kind': 'RECOGNITION',
      'answer': {'questionOrder': 0, 'selectedAnswer': 'b'},
    },
    'non-integer question order': {
      'kind': 'RECOGNITION',
      'answer': {'questionOrder': '1', 'selectedAnswer': 'b'},
    },
    'empty selected answer': {
      'kind': 'RECOGNITION',
      'answer': {'questionOrder': 1, 'selectedAnswer': ''},
    },
    'oversized selected answer': {
      'kind': 'RECOGNITION',
      'answer': {'questionOrder': 1, 'selectedAnswer': '水' * 4097},
    },
    'negative reorder order': {
      'kind': 'SENTENCE_REORDER',
      'answer': {
        'questionOrder': -1,
        'submittedOrder': ['水']
      },
    },
    'too many reorder tokens': {
      'kind': 'SENTENCE_REORDER',
      'answer': {
        'questionOrder': 1,
        'submittedOrder': List.filled(257, '水'),
      },
    },
    'oversized reorder token': {
      'kind': 'SENTENCE_REORDER',
      'answer': {
        'questionOrder': 1,
        'submittedOrder': ['水' * 4097],
      },
    },
    'non-string reorder token': {
      'kind': 'SENTENCE_REORDER',
      'answer': {
        'questionOrder': 1,
        'submittedOrder': [7],
      },
    },
    'foreign matching shape': {
      'kind': 'MATCHING',
      'answer': {
        'leftVocabularyId': activityWater,
        'rightVocabularyId': activityCoffee,
        'isCorrect': true,
      },
    },
  }.entries) {
    test('persisted ${invalid.key} stays stored and cannot enter recovery',
        () async {
      final request = activityDraft();
      await store.writeCheckpointAndActivities(activityOwner, activityLesson,
          'original checkpoint', request.attemptId, [request]);
      final key =
          PreferencesLessonCheckpointStore.key(activityOwner, activityLesson);
      final journal = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      final entry =
          (journal['activities'] as List).single as Map<String, dynamic>;
      entry['request'] = {...request.toJson(), ...invalid.value};
      final malformed = jsonEncode(journal);
      await prefs.setString(key, malformed);
      await expectLater(store.pendingActivities(activityOwner),
          throwsA(isA<LessonCheckpointStorageException>()));
      expect(prefs.getString(key), malformed);
      expect(prefs.getString('auth-fixture'), 'kept');
      expect(prefs.getBool('show_kana'), isTrue);
    });
  }
}
