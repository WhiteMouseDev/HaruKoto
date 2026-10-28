import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_checkpoint.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_practice_layout.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';

import '../fixtures/lesson_resume_fixture.dart';

void main() {
  final t1 = DateTime.utc(2026, 10, 28, 1);
  final t2 = DateTime.utc(2026, 10, 28, 2);
  final t3 = DateTime.utc(2026, 10, 28, 3);

  String stored(ResumeHarness h) =>
      h.store.values[h.store.key(h.account, resumeLessonId)]!;
  Object? time(ResumeHarness h) =>
      (jsonDecode(stored(h)) as Map<String, dynamic>)['lastStudiedAtMs'];

  test('legacy answers and exact layout restore without inventing study time',
      () async {
    final h = ResumeHarness(clock: () => t3);
    addTearDown(h.dispose);
    final detail = h.repository.detail;
    final raw = LessonCheckpoint(
        progressStamp: lessonProgressStamp(detail.progress),
        state: LessonSessionState(
            step: LessonStep.recognition,
            recognitionIndex: 1,
            practiceStarted: true,
            seed: 7,
            layout: LessonPracticeLayout.create(detail, 7),
            answers: const {
              2: {'order': 2, 'selectedAnswer': 'b', 'responseMs': 12}
            })).encode(detail);
    h.store.values[h.store.key(h.account, resumeLessonId)] = raw;
    await h.initialize();
    expect(h.state.recognitionIndex, 1);
    expect(h.state.answers[2]?['selectedAnswer'], 'b');
    expect(h.state.layout.toJson(),
        LessonCheckpoint.decode(raw, detail).state.layout.toJson());
    expect(await h.controller.flush(), isTrue);
    expect(jsonDecode(stored(h)), jsonDecode(raw));
    expect(time(h), isNull);
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
  });

  for (final invalid in [null, 0, -1, 1.5, 'not a date', 253402300800000]) {
    test('invalid optional study metadata $invalid never resets valid answers',
        () async {
      final h = ResumeHarness(clock: () => t3);
      addTearDown(h.dispose);
      final detail = h.repository.detail;
      final checkpoint = LessonCheckpoint(
          progressStamp: lessonProgressStamp(detail.progress),
          state: LessonSessionState(
              step: LessonStep.recognition,
              recognitionIndex: 1,
              practiceStarted: true,
              seed: 7,
              layout: LessonPracticeLayout.create(detail, 7),
              answers: const {
                2: {'order': 2, 'selectedAnswer': 'a', 'responseMs': 5}
              }));
      final json =
          jsonDecode(checkpoint.encode(detail)) as Map<String, dynamic>;
      json['lastStudiedAtMs'] = invalid;
      h.store.values[h.store.key(h.account, resumeLessonId)] = jsonEncode(json);
      await h.initialize();
      expect(h.state.recognitionIndex, 1);
      expect(h.state.answers[2]?['selectedAnswer'], 'a');
      expect(h.state.notice, '이 기기에 저장된 위치에서 이어서 학습해요.');
      expect(await h.controller.flush(), isTrue);
      expect(time(h), isNull);
      expect(h.repository.submitCalls, 0);
    });
  }

  test('real card activity stamps time while reads flush and no-op do not',
      () async {
    var now = t1;
    final h = ResumeHarness(clock: () => now);
    await h.initialize();
    await h.controller.flush();
    expect(time(h), isNull);
    h.controller.goToVocabLearning();
    await h.controller.flush();
    expect(time(h), t1.millisecondsSinceEpoch);
    now = t2;
    h.controller.setVocabIndex(0);
    await h.controller.flush();
    expect(time(h), t1.millisecondsSinceEpoch);
    h.controller.setVocabIndex(1);
    await h.controller.flush();
    expect(time(h), t2.millisecondsSinceEpoch);
    final store = h.store;
    h.dispose();
    now = t3;
    final fresh = ResumeHarness(store: store, clock: () => now);
    addTearDown(fresh.dispose);
    await fresh.initialize();
    expect(fresh.state.vocabIndex, 1);
    await fresh.controller.flush();
    expect(time(fresh), t2.millisecondsSinceEpoch);
  });

  test(
      'failed write then retry keeps original activity time instead of retry time',
      () async {
    var now = t1;
    final h = ResumeHarness(clock: () => now);
    addTearDown(h.dispose);
    await h.initialize();
    h.store.failWrite = true;
    h.controller.goToVocabLearning();
    expect(await h.controller.flush(), isFalse);
    now = t2;
    h.store.failWrite = false;
    expect(await h.controller.flush(), isTrue);
    expect(time(h), t1.millisecondsSinceEpoch);
    expect(h.state.vocabIndex, 0);
  });

  test(
      'start failure does not stamp; accepted start does, repeated start does not',
      () async {
    var now = t1;
    final h = ResumeHarness(clock: () => now);
    addTearDown(h.dispose);
    h.repository.startError = StateError('start unavailable');
    await h.controller.startPractice(h.repository.detail);
    await h.controller.flush();
    expect(time(h), isNull);
    h.repository.startError = null;
    now = t2;
    await h.controller.startPractice(h.repository.detail);
    expect(time(h), t2.millisecondsSinceEpoch);
    now = t3;
    await h.controller.startPractice(h.repository.detail);
    await h.controller.flush();
    expect(time(h), t2.millisecondsSinceEpoch);
  });

  test('same selected option does not reorder the lesson', () async {
    var now = t1;
    final h = ResumeHarness(clock: () => now);
    addTearDown(h.dispose);
    await h.recognition();
    now = t2;
    h.controller.selectRecognition('a');
    await h.controller.flush();
    expect(time(h), t2.millisecondsSinceEpoch);
    now = t3;
    h.controller.selectRecognition('a');
    await h.controller.flush();
    expect(time(h), t2.millisecondsSinceEpoch);
  });

  test('same matching and reorder contents do not reorder the lesson',
      () async {
    var now = t1;
    final h = ResumeHarness(clock: () => now);
    addTearDown(h.dispose);
    await h.matching();
    now = t2;
    h.controller.updateMatching(matched: {0}, left: 1);
    await h.controller.flush();
    now = t3;
    h.controller.updateMatching(matched: {0}, left: 1);
    await h.controller.flush();
    expect(time(h), t2.millisecondsSinceEpoch);
    await h.controller.completeMatching(detail: h.repository.detail);
    final bank = List<String>.from(h.state.layout.reorderBanks[11]!);
    h.controller.updateReorder(selected: const [], available: bank);
    await h.controller.flush();
    final before = time(h);
    now = t3.add(const Duration(hours: 1));
    h.controller.updateReorder(
        selected: <String>[], available: List<String>.from(bank));
    await h.controller.flush();
    expect(time(h), before);
  });

  test('unreadable possible pending payload stays byte-identical', () async {
    final h = ResumeHarness(clock: () => t3);
    addTearDown(h.dispose);
    const raw = ' {"lessonId":"$resumeLessonId", "submissionPending":true, '
        '"lastStudiedAtMs":-1,"version":99} ';
    h.store.values[h.store.key(h.account, resumeLessonId)] = raw;
    await h.initialize();
    expect(h.state.submissionPending, isTrue);
    expect(await h.controller.flush(), isTrue);
    expect(stored(h), raw);
    expect(h.repository.submitCalls, 0);
  });

  test('auxiliary timestamp never enters actual submitted lesson answers',
      () async {
    final h = ResumeHarness(clock: () => t2);
    addTearDown(h.dispose);
    await h.matching();
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    expect(h.repository.submittedAnswers, [
      {'order': 2, 'selectedAnswer': 'a', 'responseMs': 0},
      {'order': 7, 'selectedAnswer': 'd', 'responseMs': 0},
    ]);
    expect(h.repository.submitCalls, 1);
  });

  test(
      'near-size-limit legacy checkpoint saves position and answers over timestamp',
      () async {
    final minimal = resumeDetail(title: '');
    final state = LessonSessionState(
        step: LessonStep.vocabLearning,
        practiceStarted: true,
        seed: 7,
        layout: LessonPracticeLayout.create(minimal, 7),
        answers: const {
          2: {'order': 2, 'selectedAnswer': 'b', 'responseMs': 8}
        });
    final cp = LessonCheckpoint(
        state: state, progressStamp: lessonProgressStamp(minimal.progress));
    final filler = 512 * 1024 - 2 - cp.encode(minimal).length;
    final detail = resumeDetail(title: 'x' * filler);
    final raw = cp.encode(detail);
    expect(raw.length, 512 * 1024 - 2);
    final h = ResumeHarness(
        repository: ResumeStudyRepository(detail: detail), clock: () => t2);
    addTearDown(h.dispose);
    h.store.values[h.store.key(h.account, resumeLessonId)] = raw;
    await h.initialize();
    h.controller.setVocabIndex(1);
    expect(await h.controller.flush(), isTrue);
    final decoded = LessonCheckpoint.decode(stored(h), detail);
    expect(decoded.state.vocabIndex, 1);
    expect(decoded.state.answers, state.answers);
    expect(decoded.lastStudiedAt, isNull);
    expect(h.state.storageError, isFalse);
  });
}
