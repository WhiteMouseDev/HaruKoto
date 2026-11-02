import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_checkpoint.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_submission.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';

import '../fixtures/lesson_resume_fixture.dart';

class ReceiptRepository extends ResumeStudyRepository {
  final requests = <Map<String, dynamic>>[];
  int lookupCalls = 0;
  int applied = 0;
  bool loseResponse = false;
  bool failBeforeCommit = false;
  bool detailUnavailable = false;
  void Function()? onCommit;
  Completer<LessonSubmissionReceiptModel>? receiptGate;

  @override
  Future<LessonDetailModel> fetchLessonDetail(String lessonId) {
    if (detailUnavailable) throw StateError('content no longer available');
    return super.fetchLessonDetail(lessonId);
  }

  @override
  Future<LessonSubmissionReceiptModel> submitLessonIdempotent(
      String lessonId, LessonSubmissionDraft submission) async {
    requests.add(submission.toJson());
    if (receiptGate != null) return receiptGate!.future;
    if (failBeforeCommit) throw StateError('temporary failure before commit');
    final receipt = receipts.putIfAbsent(submission.submissionId, () {
      applied++;
      return LessonSubmissionReceiptModel(
          submissionId: submission.submissionId,
          processedAt: DateTime.utc(2026, 11, 2, 1),
          result: const LessonSubmitResultModel(
              scoreCorrect: 2,
              scoreTotal: 2,
              results: [],
              status: 'COMPLETED',
              srsItemsRegistered: 3));
    });
    onCommit?.call();
    if (loseResponse) {
      throw const ApiException(
          message: 'lost response', errorCode: 'NETWORK_TIMEOUT');
    }
    return receipt;
  }

  @override
  Future<LessonSubmissionReceiptModel?> fetchLessonSubmission(
      String lessonId, String submissionId, String expectedUserId) async {
    lookupCalls++;
    return receipts[submissionId];
  }
}

Future<void> submitMatching(ResumeHarness h) async {
  await h.matching();
  await h.controller
      .completeMatching(detail: h.repository.detail, jlptLevel: 'N5');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'commit with lost response then cold restart restores original receipt before content GET',
      () async {
    final repository = ReceiptRepository()
      ..detail = resumeDetail(withReorder: false)
      ..loseResponse = true;
    final h = ResumeHarness(repository: repository);
    await submitMatching(h);
    expect(h.state.submissionPending, isTrue);
    expect(repository.applied, 1);
    final raw = h.store.values[h.store.key(h.account, resumeLessonId)]!;
    final envelope =
        LessonSubmissionEnvelope.inspect(raw, h.account, resumeLessonId)!;
    final frozen = envelope.submission.toJson();
    // The immediately previous reader cannot decode V2 as a fresh draft.
    expect(() => LessonCheckpoint.decode(raw, repository.detail),
        throwsFormatException);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    expect(json['submissionPending'], isTrue);
    expect(json['acknowledged'], isFalse);
    h.dispose();

    repository.detailUnavailable = true;
    final fresh = ResumeHarness(store: h.store, repository: repository);
    addTearDown(fresh.dispose);
    final detail = await fresh.container
        .read(lessonResumeDetailProvider(resumeLessonId).future);
    expect(detail, isNull);
    expect(repository.fetchCalls, 0);
    expect(fresh.state.receiptRecovery, isTrue);
    expect(fresh.state.result?.scoreCorrect, 2);
    expect(fresh.state.receipt?.submissionId, frozen['submissionId']);
    expect(fresh.state.receipt?.processedAt, DateTime.utc(2026, 11, 2, 1));
    expect(repository.requests, [frozen]);
    expect(repository.applied, 1);
    expect(repository.lookupCalls, 1);
  });

  test(
      'GET missing is not new-attempt permission; explicit retry freezes ID/order/responseMs',
      () async {
    final repository = ReceiptRepository()
      ..detail = resumeDetail(withReorder: false)
      ..failBeforeCommit = true;
    final h = ResumeHarness(repository: repository);
    addTearDown(h.dispose);
    await submitMatching(h);
    final original = repository.requests.single;
    await h.controller.checkSubmission();
    expect(h.state.submissionPending, isTrue);
    expect(repository.requests.length, 1);
    // An uncertain receipt cannot be turned into a new attempt by reset or
    // invoking the normal submit action again.
    await h.controller.reset();
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    expect(h.state.submissionPending, isTrue);
    expect(repository.requests, [original]);
    repository.failBeforeCommit = false;
    await h.controller.retrySubmission();
    expect(repository.requests, [original, original]);
    expect(repository.applied, 1);
    expect(h.state.result?.status, 'COMPLETED');
  });

  for (final reset in [false, true]) {
    test(
        'confirmed receipt allows a new UUID for intentional relearning '
        'after ${reset ? 'explicit reset' : 'exit and reopen'}', () async {
      final repository = ReceiptRepository()
        ..detail = resumeDetail(withReorder: false);
      final before = ResumeHarness(repository: repository);
      await submitMatching(before);
      final firstId = repository.requests.single['submissionId'];
      final originalReceipt = repository.receipts[firstId]!;
      expect(before.state.result, isNotNull);
      expect(before.store.values, isEmpty);

      final ResumeHarness next;
      if (reset) {
        await before.controller.reset();
        next = before;
      } else {
        before.dispose();
        next = ResumeHarness(store: before.store, repository: repository);
      }
      addTearDown(next.dispose);
      await submitMatching(next);
      final nextId = repository.requests.last['submissionId'];
      expect(repository.requests, hasLength(2));
      expect(nextId, isNot(firstId));
      expect(repository.applied, 2);
      expect(repository.receipts, hasLength(2));
      expect(repository.receipts[firstId], same(originalReceipt));
      expect(next.state.receipt?.submissionId, nextId);
    });
  }

  test(
      'failed durable write sends zero POSTs and retry keeps the already allocated ID',
      () async {
    final repository = ReceiptRepository()
      ..detail = resumeDetail(withReorder: false);
    final h = ResumeHarness(repository: repository);
    addTearDown(h.dispose);
    await h.matching();
    h.store.failWrite = true;
    await h.controller
        .completeMatching(detail: repository.detail, jlptLevel: 'N5');
    expect(repository.requests, isEmpty);
    expect(h.state.storageError, isTrue);
    expect(h.state.submissionPending, isTrue);
    await h.controller.retrySubmission();
    expect(repository.requests, isEmpty);
    h.store.failWrite = false;
    await h.controller.retrySubmission();
    expect(repository.requests, hasLength(1));
    expect(repository.applied, 1);
  });

  test(
      'failed acknowledgement preserves pending receipt ID for another cold recovery',
      () async {
    final repository = ReceiptRepository()
      ..detail = resumeDetail(withReorder: false);
    final h = ResumeHarness(repository: repository);
    repository.onCommit = () => h.store.failWrite = true;
    await submitMatching(h);
    expect(h.state.result, isNotNull);
    final raw = h.store.values[h.store.key(h.account, resumeLessonId)]!;
    final id = LessonSubmissionEnvelope.inspect(raw, h.account, resumeLessonId)!
        .submission
        .submissionId;
    expect(h.store.operations.where((o) => o.startsWith('remove:')), isEmpty);
    h.dispose();
    h.store.failWrite = false;
    final fresh = ResumeHarness(store: h.store, repository: repository);
    addTearDown(fresh.dispose);
    await fresh.container
        .read(lessonResumeDetailProvider(resumeLessonId).future);
    expect(fresh.state.receipt?.submissionId, id);
    expect(repository.applied, 1);
  });

  test(
      'late response after account switch does not replace another account state',
      () async {
    final repository = ReceiptRepository()
      ..detail = resumeDetail(withReorder: false)
      ..receiptGate = Completer<LessonSubmissionReceiptModel>();
    final h = ResumeHarness(repository: repository);
    addTearDown(h.dispose);
    await h.matching();
    final submitting = h.controller
        .completeMatching(detail: repository.detail, jlptLevel: 'N5');
    await Future<void>.delayed(Duration.zero);
    h.account = 'account-b';
    repository.receiptGate!.complete(LessonSubmissionReceiptModel(
        submissionId: repository.requests.single['submissionId'] as String,
        processedAt: DateTime.utc(2026, 11, 2),
        result: const LessonSubmitResultModel(
            scoreCorrect: 1, scoreTotal: 1, results: [], status: 'COMPLETED')));
    await submitting;
    expect(h.state.result, isNull);
    expect(h.store.values.keys, [h.store.key('account-a', resumeLessonId)]);
  });

  test(
      'malformed V2 preserves opaque pending and does not POST or current-content GET',
      () async {
    final repository = ReceiptRepository()..detailUnavailable = true;
    final h = ResumeHarness(repository: repository);
    addTearDown(h.dispose);
    final raw = jsonEncode({
      'version': 2,
      'lessonId': resumeLessonId,
      'submissionPending': true,
      'acknowledged': false,
      'protocolVersion': 99
    });
    h.store.values[h.store.key(h.account, resumeLessonId)] = raw;
    await h.container.read(lessonResumeDetailProvider(resumeLessonId).future);
    await h.controller.retrySubmission();
    await h.controller.checkSubmission();
    expect(h.store.values[h.store.key(h.account, resumeLessonId)], raw);
    expect(repository.requests, isEmpty);
    expect(repository.lookupCalls, 0);
    expect(repository.fetchCalls, 0);
    expect(h.state.submissionPending, isTrue);
  });

  test(
      'changed frozen body or owner fails closed rather than reusing the ID for other answers',
      () async {
    final repository = ReceiptRepository()
      ..detail = resumeDetail(withReorder: false)
      ..failBeforeCommit = true;
    final h = ResumeHarness(repository: repository);
    await submitMatching(h);
    final key = h.store.key(h.account, resumeLessonId);
    final json = jsonDecode(h.store.values[key]!) as Map<String, dynamic>;
    final request = json['submission'] as Map<String, dynamic>;
    ((request['answers'] as List).first as Map<String, dynamic>)['responseMs'] =
        999;
    final changed = jsonEncode(json);
    h.store.values[key] = changed;
    h.dispose();
    final fresh = ResumeHarness(store: h.store, repository: repository);
    addTearDown(fresh.dispose);
    await fresh.container
        .read(lessonResumeDetailProvider(resumeLessonId).future);
    await fresh.controller.retrySubmission();
    expect(repository.requests, hasLength(1));
    expect(repository.lookupCalls, 0);
    expect(fresh.store.values[key], changed);
    expect(fresh.state.submissionCanRetry, isFalse);
  });

  test(
      'oversized pending envelope sends no network write and preserves raw data',
      () async {
    final h = ResumeHarness(repository: ReceiptRepository());
    addTearDown(h.dispose);
    final raw = jsonEncode({
      'version': 2,
      'protocolVersion': 1,
      'lessonId': resumeLessonId,
      'submissionPending': true,
      'padding': 'x' * (512 * 1024)
    });
    h.store.values[h.store.key(h.account, resumeLessonId)] = raw;
    await h.container.read(lessonResumeDetailProvider(resumeLessonId).future);
    await h.controller.retrySubmission();
    await h.controller.flush();
    expect((h.repository as ReceiptRepository).requests, isEmpty);
    expect(h.store.values.values.single, raw);
    expect(h.state.submissionCanRetry, isFalse);
  });

  test('secure submission body does not alias mutable caller tokens', () {
    final tokens = ['私', 'です'];
    final draft = LessonSubmissionDraft.create(owner: 'owner', answers: [
      {'order': 2, 'submittedOrder': tokens, 'responseMs': 981}
    ]);
    tokens[0] = 'changed';
    tokens.add('changed');
    final first = draft.toJson();
    (first['answers'] as List).clear();
    expect(draft.toJson()['answers'], [
      {
        'order': 2,
        'selectedAnswer': null,
        'submittedOrder': ['私', 'です'],
        'responseMs': 981
      }
    ]);
    expect(
        draft.submissionId,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  });
}
