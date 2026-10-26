import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';

import '../fixtures/lesson_resume_fixture.dart';

void main() {
  Future<ResumeHarness> reopen(ResumeHarness old,
      {ResumeStudyRepository? repository}) async {
    await old.controller.flush();
    old.dispose();
    final fresh = ResumeHarness(
        store: old.store, repository: repository ?? old.repository);
    addTearDown(fresh.dispose);
    await fresh.initialize();
    return fresh;
  }

  test('new entry restores no records and performs no learning writes',
      () async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.initialize();
    expect(h.state.step, LessonStep.contextPreview);
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
    expect(h.store.values, isEmpty);
  });

  test('vocab item and grammar item resume in new containers', () async {
    final h = ResumeHarness();
    await h.initialize();
    h.controller.goToVocabLearning();
    h.controller.setVocabIndex(2);
    final vocab = await reopen(h);
    expect(vocab.state.step, LessonStep.vocabLearning);
    expect(vocab.state.vocabIndex, 2);
    vocab.controller.goToGrammarLearning();
    vocab.controller.setGrammarIndex(1);
    await vocab.controller.flush();
    final grammar = ResumeHarness(store: vocab.store);
    addTearDown(grammar.dispose);
    await grammar.initialize();
    expect(grammar.state.step, LessonStep.grammarLearning);
    expect(grammar.state.grammarIndex, 1);
    expect(grammar.state.vocabIndex, 2);
    expect(grammar.repository.submitCalls, 0);
  });

  test('guided reading resumes without starting practice', () async {
    final h = ResumeHarness();
    await h.initialize();
    h.controller.goToVocabLearning();
    h.controller.goToGrammarLearning();
    h.controller.goToGuidedReading();
    final fresh = await reopen(h);
    expect(fresh.state.step, LessonStep.guidedReading);
    expect(fresh.repository.startCalls, 0);
  });

  test(
      'answer, current selection, question index and exact option order restore',
      () async {
    final h = ResumeHarness();
    await h.recognition();
    h.controller.answerRecognition(h.repository.detail,
        {'order': 2, 'selectedAnswer': 'b', 'responseMs': 12});
    h.controller.selectRecognition('c');
    final layout = h.state.layout.toJson();
    final fresh = await reopen(h);
    expect(fresh.state.recognitionIndex, 1);
    expect(fresh.state.answers[2]?['selectedAnswer'], 'b');
    expect(fresh.state.recognitionSelection, 'c');
    expect(fresh.state.layout.toJson(), layout);
    expect(fresh.repository.startCalls, 1);
    expect(fresh.repository.submitCalls, 0);
  });

  test('matching layout, matched pairs and unfinished selection restore',
      () async {
    final h = ResumeHarness();
    await h.matching();
    h.controller.updateMatching(matched: {0}, left: 1);
    final layout = h.state.layout.toJson();
    final fresh = await reopen(h);
    expect(fresh.state.step, LessonStep.matching);
    expect(fresh.state.matchingMatched, {0});
    expect(fresh.state.matchingLeft, 1);
    expect(fresh.state.layout.toJson(), layout);
    expect(fresh.state.answers.keys, containsAll([2, 7]));
    expect(fresh.repository.submitCalls, 0);
  });

  test('reorder draft preserves repeated tokens and exact remaining bank',
      () async {
    final h = ResumeHarness();
    await h.reorder();
    final bank = List<String>.from(h.state.layout.reorderBanks[11]!)
      ..remove('は')
      ..remove('は');
    h.controller.updateReorder(selected: ['は', 'は'], available: bank);
    final fresh = await reopen(h);
    expect(fresh.state.step, LessonStep.sentenceReorder);
    expect(fresh.state.reorderSelected, ['は', 'は']);
    expect(fresh.state.reorderAvailable, bank);
    expect(fresh.repository.submitCalls, 0);
  });

  test('second reorder question and prior answer resume', () async {
    final h = ResumeHarness();
    await h.reorder();
    await h.controller
        .answerReorder(detail: h.repository.detail, jlptLevel: 'N5', answer: {
      'order': 11,
      'submittedOrder': ['は', 'は', 'です'],
      'responseMs': 5
    });
    final fresh = await reopen(h);
    expect(fresh.state.reorderIndex, 1);
    expect(fresh.state.answers[11]?['submittedOrder'], ['は', 'は', 'です']);
    expect(fresh.state.reorderAvailable, isNull);
    expect(fresh.repository.submitCalls, 0);
  });

  test('returning through guided reading preserves existing practice answers',
      () async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.recognition();
    h.controller.answerRecognition(h.repository.detail,
        {'order': 2, 'selectedAnswer': 'a', 'responseMs': 0});
    h.controller.goBack();
    await h.controller.startPractice(h.repository.detail);
    expect(h.state.recognitionIndex, 1);
    expect(h.state.answers.keys, [2]);
    expect(h.repository.startCalls, 1);
  });

  test('double start is single flight and returned start stamp is durable',
      () async {
    final repo = ResumeStudyRepository(detail: resumeDetail(progress: null))
      ..startGate = Completer();
    final h = ResumeHarness(repository: repo);
    await h.initialize();
    final a = h.controller.startPractice(repo.detail);
    final b = h.controller.startPractice(repo.detail);
    expect(repo.startCalls, 1);
    repo.startGate!.complete(inProgress);
    await Future.wait([a, b]);
    final fresh = await reopen(h,
        repository: ResumeStudyRepository(detail: resumeDetail()));
    expect(fresh.state.step, LessonStep.recognition);
    expect(fresh.state.submissionPending, isFalse);
  });

  test('late reorder callback after phase back cannot submit', () async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.reorder();
    h.controller.goBack();
    await h.controller
        .answerReorder(detail: h.repository.detail, jlptLevel: 'N5', answer: {
      'order': 11,
      'submittedOrder': ['は', 'は', 'です'],
      'responseMs': 0
    });
    expect(h.state.step, LessonStep.matching);
    expect(h.state.answers.containsKey(11), isFalse);
    expect(h.repository.submitCalls, 0);
  });

  test('authoritative account change blocks POST before auth stream catches up',
      () async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.recognition();
    await h.controller.flush();
    final before = Map<String, String>.from(h.store.values);
    h.account = 'account-b';
    expect(h.container.read(currentAccountIdProvider), 'account-a');
    h.controller.selectRecognition('a');
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    expect(h.store.values, before);
    expect(h.repository.submitCalls, 0);
  });

  test('another account cannot load the prior account draft', () async {
    final h = ResumeHarness();
    await h.recognition();
    h.controller.selectRecognition('b');
    await h.controller.flush();
    h.dispose();
    final other = ResumeHarness(store: h.store, account: 'account-b');
    addTearDown(other.dispose);
    await other.initialize();
    expect(other.state.step, LessonStep.contextPreview);
    expect(other.state.recognitionSelection, isNull);
  });

  test('old start response cannot overwrite a newly signed in account',
      () async {
    final repo = ResumeStudyRepository()..startGate = Completer();
    final h = ResumeHarness(repository: repo);
    addTearDown(h.dispose);
    await h.initialize();
    final start = h.controller.startPractice(repo.detail);
    h.account = 'account-b';
    h.container.invalidate(currentAccountIdProvider);
    await h.container.pump();
    await h.controller.initialize(repo.detail);
    repo.startGate!.complete(inProgress);
    await start;
    expect(h.state.step, LessonStep.contextPreview);
    expect(h.store.values.keys.where((key) => key.startsWith('account-b')),
        isEmpty);
  });

  test('changed nonpending content starts at intro with an honest notice',
      () async {
    final h = ResumeHarness();
    await h.recognition();
    final fresh = await reopen(h,
        repository:
            ResumeStudyRepository(detail: resumeDetail(title: 'Updated')));
    expect(fresh.state.step, LessonStep.contextPreview);
    expect(fresh.state.submissionPending, isFalse);
    expect(fresh.state.notice, contains('내용'));
    expect(fresh.repository.submitCalls, 0);
  });

  test('invalid indices are not used by widgets', () async {
    final h = ResumeHarness();
    await h.recognition();
    await h.controller.flush();
    final key = h.store.key('account-a', resumeLessonId);
    final data = jsonDecode(h.store.values[key]!) as Map<String, dynamic>;
    data['recognitionIndex'] = 999;
    h.store.values[key] = jsonEncode(data);
    h.dispose();
    final fresh = ResumeHarness(store: h.store);
    addTearDown(fresh.dispose);
    await fresh.initialize();
    expect(fresh.state.recognitionIndex, 0);
    expect(fresh.state.step, LessonStep.contextPreview);
    expect(fresh.state.notice, isNotNull);
  });

  test('unreadable data cannot become a resendable attempt', () async {
    final store = MemoryCheckpointStore()
      ..values['account-a/$resumeLessonId'] = '{broken';
    final h = ResumeHarness(store: store);
    addTearDown(h.dispose);
    await h.initialize();
    expect(h.state.submissionPending, isTrue);
    await h.controller.startPractice(h.repository.detail);
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
  });

  test(
      'newer server completion blocks a stale draft without fabricated results',
      () async {
    final h = ResumeHarness();
    await h.recognition();
    final fresh = await reopen(h,
        repository: ResumeStudyRepository(
            detail: resumeDetail(progress: completedProgress)));
    expect(fresh.state.serverRecorded, isTrue);
    expect(fresh.state.result, isNull);
    expect(fresh.state.serverProgress, completedProgress);
    expect(fresh.repository.submitCalls, 0);
  });

  test('failed pending marker save prevents POST and save can be retried',
      () async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.recognition();
    h.store.failWrite = true;
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    expect(h.repository.submitCalls, 0);
    expect(h.state.storageError, isTrue);
    expect(h.state.submissionPending, isFalse);
    h.store.failWrite = false;
    expect(await h.controller.flush(), isTrue);
    expect(h.state.storageError, isFalse);
  });

  test('success deletes after queued writes and cannot submit twice', () async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.recognition();
    h.controller.selectRecognition('b');
    h.controller.selectRecognition('a');
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    expect(h.state.step, LessonStep.result);
    expect(h.store.values, isEmpty);
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    expect(h.repository.submitCalls, 1);
  });

  test('failed deletion leaves a completion tombstone that never resubmits',
      () async {
    final h = ResumeHarness();
    await h.recognition();
    h.store.failRemove = true;
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    expect(h.state.storageError, isTrue);
    final raw = h.store.values[h.store.key('account-a', resumeLessonId)]!;
    expect((jsonDecode(raw) as Map<String, dynamic>)['acknowledged'], isTrue);
    h.dispose();
    final fresh = ResumeHarness(store: h.store);
    addTearDown(fresh.dispose);
    await fresh.initialize();
    expect(fresh.state.serverRecorded, isTrue);
    expect(fresh.state.result, isNull);
    expect(fresh.repository.submitCalls, 0);
  });

  test(
      'unknown POST remains pending after restart and unchanged GET cannot authorize retry',
      () async {
    final h = ResumeHarness();
    await h.recognition();
    h.repository.submitError = TimeoutException('lost response');
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    final fresh = await reopen(h);
    expect(fresh.state.submissionPending, isTrue);
    await fresh.controller.checkSubmission();
    await fresh.controller
        .submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    await fresh.controller.reset();
    expect(fresh.state.submissionPending, isTrue);
    expect(fresh.repository.submitCalls, 1);
    expect(fresh.state.notice, contains('확정할 수 없어요'));
  });

  test(
      'completed redo is unresolved until attempt stamp advances and new server score is shown',
      () async {
    final repo =
        ResumeStudyRepository(detail: resumeDetail(progress: completedProgress))
          ..submitError = TimeoutException('lost response');
    final h = ResumeHarness(repository: repo);
    addTearDown(h.dispose);
    await h.recognition();
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    await h.controller.checkSubmission();
    expect(h.state.submissionPending, isTrue);
    expect(h.state.serverRecorded, isFalse);
    repo.detail = resumeDetail(
        progress: const LessonProgressModel(
            status: 'COMPLETED',
            attempts: 2,
            scoreCorrect: 4,
            scoreTotal: 4,
            startedAt: '2026-10-21T01:00:00Z',
            completedAt: '2026-10-21T03:00:00Z'));
    await h.controller.checkSubmission();
    expect(h.state.serverRecorded, isTrue);
    expect(h.state.serverProgress?.scoreCorrect, 4);
    expect(h.state.result, isNull);
    expect(repo.submitCalls, 1);
  });
  test(
      'closing during start and reopening keeps reading after an idempotent start-only transition',
      () async {
    final repo = ResumeStudyRepository(detail: resumeDetail(progress: null))
      ..startGate = Completer();
    final h = ResumeHarness(repository: repo);
    await h.initialize();
    h.controller.goToVocabLearning();
    h.controller.goToGrammarLearning();
    h.controller.goToGuidedReading();
    await h.controller.flush();
    final starting = h.controller.startPractice(repo.detail);
    final lease = h.controller.actions;
    lease.beginClosing();
    await lease.flush();
    h.dispose();
    repo.startGate!.complete(inProgress);
    await starting;
    final fresh = ResumeHarness(
        store: h.store,
        repository: ResumeStudyRepository(detail: resumeDetail()));
    addTearDown(fresh.dispose);
    await fresh.initialize();
    expect(fresh.state.step, LessonStep.guidedReading);
    expect(fresh.state.serverRecorded, isFalse);
    expect(fresh.state.submissionPending, isFalse);
    expect(fresh.repository.submitCalls, 0);
  });
  test('pending answers survive a content change byte for byte through close',
      () async {
    final h = ResumeHarness();
    await h.recognition();
    h.repository.submitError = TimeoutException('unknown');
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    await h.controller.flush();
    final raw = h.store.values.values.single;
    h.dispose();
    final fresh = ResumeHarness(
        store: h.store,
        repository:
            ResumeStudyRepository(detail: resumeDetail(title: 'Changed')));
    addTearDown(fresh.dispose);
    await fresh.initialize();
    expect(fresh.state.submissionPending, isTrue);
    await fresh.controller.flush();
    expect(fresh.store.values.values.single, raw);
    expect(fresh.repository.submitCalls, 0);
  });

  test('initial storage read failure has no start, submit or local overwrite',
      () async {
    final store = MemoryCheckpointStore()..failRead = true;
    final h = ResumeHarness(store: store);
    addTearDown(h.dispose);
    await expectLater(h.initialize(), throwsA(isA<Exception>()));
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
    expect(store.values, isEmpty);
    store.failRead = false;
    await h.initialize();
    expect(h.state.step, LessonStep.contextPreview);
  });

  test('late completed POST response cannot overwrite a new account', () async {
    final repo = ResumeStudyRepository()
      ..submitGate = Completer<LessonSubmitResultModel>();
    final h = ResumeHarness(repository: repo);
    addTearDown(h.dispose);
    await h.recognition();
    final submitting =
        h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    for (var i = 0; i < 10 && repo.submitCalls == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(repo.submitCalls, 1);
    h.account = 'account-b';
    h.container.invalidate(currentAccountIdProvider);
    await h.container.pump();
    await h.initialize();
    repo.submitGate!.complete(const LessonSubmitResultModel(
        scoreCorrect: 4, scoreTotal: 4, results: [], status: 'COMPLETED'));
    await submitting;
    expect(h.state.step, LessonStep.contextPreview);
    expect(h.state.result, isNull);
    expect(h.store.values.keys.where((key) => key.startsWith('account-b')),
        isEmpty);
    expect(h.store.values['account-a/$resumeLessonId'],
        contains('"submissionPending":true'));
  });

  test(
      'resumed final answer submits all and only confirmed original-order answers',
      () async {
    final h = ResumeHarness();
    await h.reorder();
    await h.controller
        .answerReorder(detail: h.repository.detail, jlptLevel: 'N5', answer: {
      'order': 11,
      'submittedOrder': ['は', 'は', 'です'],
      'responseMs': 0
    });
    final fresh = await reopen(h);
    await fresh.controller.answerReorder(
        detail: fresh.repository.detail,
        jlptLevel: 'N5',
        answer: {
          'order': 19,
          'submittedOrder': ['私', 'です'],
          'responseMs': 0
        });
    expect(fresh.repository.submittedAnswers!.map((answer) => answer['order']),
        [2, 7, 11, 19]);
    expect(fresh.repository.submitCalls, 1);
    expect(fresh.state.step, LessonStep.result);
    expect(fresh.store.values, isEmpty);
  });
  test(
      'legacy in-progress record without a local checkpoint explains intro without inventing answers',
      () async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.initialize();
    expect(h.state.step, LessonStep.contextPreview);
    expect(h.state.answers, isEmpty);
    expect(h.state.notice, contains('이 기기에 저장된 진행이 없어'));
    expect(h.state.notice, contains('기존 학습 기록은 그대로'));
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
    expect(h.store.values, isEmpty);
  });
}
