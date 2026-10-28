import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/saved_lesson_entry.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/saved_lesson_entry_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

import '../fixtures/lesson_resume_fixture.dart';
import '../fixtures/saved_lesson_entry_fixture.dart';

void main() {
  test('later NOT_STARTED lesson draft is discoverable without a detail GET',
      () async {
    final h = _Harness();
    h.store.values['account-a/later'] = rawCheckpoint('later');
    final snapshot = Map<String, String>.from(h.store.values);
    final data = await h.entries();
    expect(data.entries.map((entry) => entry.lesson.id), ['later']);
    expect(data.entries.single.hint.label, '단어 학습 저장 위치');
    expect(data.entries.single.lesson.status, 'NOT_STARTED');
    expect(h.repository.detailReads, 0);
    expect(h.repository.writes, 0);
    expect(h.store.values, snapshot);
  });

  test('multiple drafts follow curriculum order, not key or insertion order',
      () async {
    final h = _Harness();
    h.store.values['account-a/later'] = rawCheckpoint('later');
    h.store.values['account-a/first'] = rawCheckpoint('first');
    final data = await h.entries();
    expect(data.entries.map((entry) => entry.lesson.id), ['first', 'later']);
  });

  test('known study timestamps rank newest first without changing raw drafts',
      () async {
    final h = _Harness();
    h.store.values['account-a/first'] = _withStudyTime('first', 1000);
    h.store.values['account-a/later'] = _withStudyTime('later', 2000);
    final before = Map<String, String>.from(h.store.values);
    final data = await h.entries();
    expect(data.entries.map((entry) => entry.lesson.id), ['later', 'first']);
    expect(h.store.values, before);
    expect(h.repository.detailReads, 0);
    expect(h.repository.writes, 0);
  });

  for (final times in [
    (first: 1000, later: 1000, order: ['first', 'later']),
    (first: null, later: 2000, order: ['later', 'first']),
    (first: 2000, later: null, order: ['first', 'later']),
    (first: 'invalid', later: 1000, order: ['later', 'first']),
    (first: 253402300800000, later: 1000, order: ['later', 'first']),
  ]) {
    test('recent order has deterministic legacy and tie fallback $times',
        () async {
      final h = _Harness();
      h.store.values['account-a/first'] = _withStudyTime('first', times.first);
      h.store.values['account-a/later'] = _withStudyTime('later', times.later);
      final raw = Map<String, String>.from(h.store.values);
      expect((await h.entries()).entries.map((e) => e.lesson.id), times.order);
      expect(h.store.values, raw);
      expect(h.repository.writes, 0);
    });
  }

  test('known pending submission retains recency and safe record-check hint',
      () async {
    final h = _Harness();
    h.store.values['account-a/first'] = _withStudyTime('first', 1000);
    final json = jsonDecode(rawCheckpoint('later', pending: true))
        as Map<String, dynamic>;
    json['lastStudiedAtMs'] = 2000;
    h.store.values['account-a/later'] = jsonEncode(json);
    final before = Map<String, String>.from(h.store.values);
    final entries = (await h.entries()).entries;
    expect(entries.map((e) => e.lesson.id), ['later', 'first']);
    expect(entries.first.hint.submissionPending, isTrue);
    expect(entries.first.hint.actionLabel, '기록 확인');
    expect(h.store.values, before);
  });

  test('unreadable record is accessible without trusting its ranking metadata',
      () async {
    final h = _Harness();
    h.store.values['account-a/first'] = _withStudyTime('first', 1000);
    h.store.values['account-a/later'] = jsonEncode({
      'lessonId': 'later',
      'version': 99,
      'lastStudiedAtMs': 999999999999,
    });
    final entries = (await h.entries()).entries;
    expect(entries.map((e) => e.lesson.id), ['first', 'later']);
    expect(entries.last.hint.needsRecordCheck, isTrue);
    expect(entries.last.hint.lastStudiedAt, isNull);
  });

  test('sign out reads no checkpoint and another account cannot see a draft',
      () async {
    final h = _Harness();
    h.store.values['account-a/later'] = rawCheckpoint('later');
    expect((await h.entries()).entries.length, 1);
    h.account = 'account-b';
    h.container.invalidate(currentAccountIdProvider);
    expect((await h.entries()).entries, isEmpty);
    expect(h.store.operations.last, 'read:account-b/later');
    h.account = null;
    h.container.invalidate(currentAccountIdProvider);
    final reads = h.store.operations.length;
    expect((await h.entries()).entries, isEmpty);
    expect(h.store.operations.length, reads);
  });

  test('authoritative account change during an awaited read hides old entries',
      () async {
    final h = _Harness();
    h.store.values['account-a/later'] = rawCheckpoint('later');
    h.store.readGate = Completer<void>();
    final future = h.entries();
    await Future<void>.delayed(Duration.zero);
    h.account = 'account-b'; // Auth stream has not delivered this switch yet.
    h.store.readGate!.complete();
    expect((await future).entries, isEmpty);
    expect(h.repository.writes, 0);
  });

  test(
      'only current-level known lesson IDs are read, unknown keys are untouched',
      () async {
    final h = _Harness(level: 'N4');
    h.store.values['account-a/foreign'] = rawCheckpoint('foreign');
    h.store.values['account-a/later'] = rawCheckpoint('later');
    final n4 = await h.container.read(savedLessonEntriesProvider('N4').future);
    expect(n4.entries, isEmpty);
    expect(h.store.operations, ['read:account-a/n4-lesson']);
    final n5 = await h.container.read(savedLessonEntriesProvider('N5').future);
    expect(n5.entries.map((entry) => entry.lesson.id), ['later']);
    expect(h.store.operations, isNot(contains('read:account-a/foreign')));
    expect(h.store.values.containsKey('account-a/foreign'), isTrue);
  });

  test(
      'partial local read failure preserves other entries and retries only failure',
      () async {
    final h = _Harness();
    h.store.values['account-a/first'] = rawCheckpoint('first');
    h.store.values['account-a/later'] = rawCheckpoint('later');
    h.store.failedIds.add('later');
    final failed = await h.entries();
    expect(failed.entries.map((entry) => entry.lesson.id), ['first']);
    expect(failed.failedLessonIds, ['later']);
    final firstReads =
        h.store.operations.where((op) => op.endsWith('/first')).length;
    h.store.failedIds.clear();
    h.container.invalidate(
        savedLessonLookupProvider((accountId: 'account-a', lessonId: 'later')));
    final retried = await h.entries();
    expect(retried.entries.map((entry) => entry.lesson.id), ['first', 'later']);
    expect(retried.failedLessonIds, isEmpty);
    expect(h.store.operations.where((op) => op.endsWith('/first')).length,
        firstReads);
    expect(h.repository.detailReads, 0);
    expect(h.repository.writes, 0);
  });

  test('only successful controller persistence refreshes its local entry',
      () async {
    final h = _Harness();
    expect((await h.entries()).entries, isEmpty);
    final detail = detailFor('later');
    final controller =
        h.container.read(lessonSessionProvider('later').notifier);
    await controller.initialize(detail);
    final firstReads =
        h.store.operations.where((op) => op.endsWith('/first')).length;
    h.store.failWrite = true;
    controller.goToVocabLearning();
    expect(await controller.flush(), isFalse);
    expect((await h.entries()).entries, isEmpty);
    h.store.failWrite = false;
    expect(await controller.flush(), isTrue);
    final saved = await h.entries();
    expect(saved.entries.map((entry) => entry.lesson.id), ['later']);
    expect(h.store.operations.where((op) => op.endsWith('/first')).length,
        firstReads);
  });

  test(
      'acknowledged tombstone hides a completed local entry even if removal failed',
      () async {
    final h = _Harness();
    h.store.values['account-a/later'] = rawCheckpoint('later');
    expect((await h.entries()).entries.length, 1);
    final controller =
        h.container.read(lessonSessionProvider('later').notifier);
    await controller.initialize(detailFor('later'));
    h.store.failRemove = true;
    await controller.submitAnswers(lessonId: 'later', jlptLevel: 'N5');
    expect((await h.entries()).entries, isEmpty);
    expect(h.store.values.containsKey('account-a/later'), isTrue);
    expect(h.repository.writes, 1);
  });

  test('server-recorded checkpoint clearing removes its entry immediately',
      () async {
    final h = _Harness();
    h.store.values['account-a/later'] = rawCheckpoint('later');
    expect((await h.entries()).entries.length, 1);
    final detail = detailFor('later');
    final changed = LessonDetailModel(
        id: detail.id,
        lessonNo: detail.lessonNo,
        chapterLessonNo: detail.chapterLessonNo,
        title: detail.title,
        topic: detail.topic,
        estimatedMinutes: detail.estimatedMinutes,
        content: detail.content,
        vocabItems: detail.vocabItems,
        grammarItems: detail.grammarItems,
        progress: completedProgress);
    await h.container
        .read(lessonSessionProvider('later').notifier)
        .initialize(changed);
    expect((await h.entries()).entries, isEmpty);
    expect(h.store.values.containsKey('account-a/later'), isFalse);
    expect(h.repository.writes, 0);
  });

  test(
      'relearning a completed lesson remains discoverable and duplicate IDs read once',
      () async {
    final repository = _Repository()
      ..chaptersOverride = [
        const ChapterModel(
            id: 'done',
            jlptLevel: 'N5',
            partNo: 1,
            chapterNo: 1,
            title: 'done',
            completedLessons: 1,
            totalLessons: 1,
            lessons: [
              LessonSummaryModel(
                  id: 'later',
                  lessonNo: 1,
                  chapterLessonNo: 1,
                  title: '완료 레슨 다시 학습',
                  topic: '',
                  estimatedMinutes: 10,
                  status: 'COMPLETED',
                  scoreCorrect: 4,
                  scoreTotal: 4),
              LessonSummaryModel(
                  id: 'later',
                  lessonNo: 1,
                  chapterLessonNo: 1,
                  title: '중복 ID',
                  topic: '',
                  estimatedMinutes: 10,
                  status: 'NOT_STARTED',
                  scoreCorrect: 0,
                  scoreTotal: 0),
            ])
      ];
    final h = _Harness(repository: repository);
    h.store.values['account-a/later'] = rawCheckpoint('later');
    h.store.values['account-a/deleted-from-curriculum'] =
        rawCheckpoint('deleted-from-curriculum');
    final raw = Map<String, String>.from(h.store.values);
    final data = await h.entries();
    expect(data.entries.length, 1);
    expect(data.entries.single.lesson.status, 'COMPLETED');
    expect(data.entries.single.lesson.title, '완료 레슨 다시 학습');
    expect(h.store.operations, ['read:account-a/later']);
    expect(h.store.values, raw);
    expect(repository.detailReads, 0);
    expect(repository.writes, 0);
  });

  test(
      'pending, unknown and damaged payloads are record-check links and stay intact',
      () async {
    final h = _Harness();
    h.store.values['account-a/first'] = rawCheckpoint('first', pending: true);
    h.store.values['account-a/later'] = '{unreadable';
    final before = Map<String, String>.from(h.store.values);
    final data = await h.entries();
    expect(
        data.entries.map((entry) => entry.hint.needsRecordCheck), [true, true]);
    expect(data.entries.first.hint.label, '제출 기록 확인');
    expect(data.entries.last.hint.label, '저장 기록 확인');
    expect(h.store.values, before);
    expect(h.repository.detailReads, 0);
    expect(h.repository.writes, 0);
  });

  test('preview never claims a restored percentage or uses payload titles', () {
    expect(SavedLessonHint.inspect('{}', 'first')!.needsRecordCheck, isTrue);
    expect(SavedLessonHint.inspect('{"lessonId":5}', 'first')!.needsRecordCheck,
        isTrue);
    final raw = rawCheckpoint('first');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    json['version'] = 2;
    expect(SavedLessonHint.inspect(jsonEncode(json), 'first')!.needsRecordCheck,
        isTrue);
    json['version'] = 1;
    json['acknowledged'] = true;
    json['submissionPending'] = true;
    expect(
        SavedLessonHint.inspect(jsonEncode(json), 'first')!.submissionPending,
        isTrue);
    json['lessonId'] = 'foreign';
    expect(SavedLessonHint.inspect(jsonEncode(json), 'first'), isNull);
    expect(
        SavedLessonHint.inspect(
            rawCheckpoint('first', step: LessonStep.contextPreview), 'first'),
        isNull);
    expect(
        SavedLessonHint.inspect(
            rawCheckpoint('first', acknowledged: true), 'first'),
        isNull);
    expect(
        SavedLessonHint.inspect('x' * (512 * 1024 + 1), 'first')!
            .needsRecordCheck,
        isTrue);
  });
}

String _withStudyTime(String id, Object? time) {
  final json = jsonDecode(rawCheckpoint(id)) as Map<String, dynamic>;
  json['lastStudiedAtMs'] = time;
  return jsonEncode(json);
}

class _SelectiveStore extends MemoryCheckpointStore {
  final failedIds = <String>{};
  Completer<void>? readGate;
  @override
  Future<String?> read(String accountId, String lessonId) async {
    operations.add('read:$accountId/$lessonId');
    await readGate?.future;
    if (failedIds.contains(lessonId)) {
      throw const LessonCheckpointStorageException();
    }
    return values[key(accountId, lessonId)];
  }
}

class _Harness {
  _Harness({this.level = 'N5', _Repository? repository})
      : repository = repository ?? _Repository() {
    container = ProviderContainer(retry: (_, __) => null, overrides: [
      currentAccountIdProvider.overrideWith((ref) => account),
      currentAccountReaderProvider.overrideWithValue(() => account),
      lessonCheckpointStoreProvider.overrideWithValue(store),
      studyRepositoryProvider.overrideWithValue(this.repository),
    ]);
    final sub = container.listen(savedLessonEntriesProvider(level), (_, __) {});
    addTearDown(() {
      sub.close();
      container.dispose();
    });
  }
  final String level;
  String? account = 'account-a';
  final store = _SelectiveStore();
  final _Repository repository;
  late final ProviderContainer container;
  Future<SavedLessonEntries> entries() =>
      container.read(savedLessonEntriesProvider('N5').future);
}

class _Repository extends Fake implements StudyRepository {
  int detailReads = 0;
  int writes = 0;
  List<ChapterModel>? chaptersOverride;
  @override
  Future<ChapterListModel> fetchChapters(String jlptLevel) async =>
      ChapterListModel(
          chapters: chaptersOverride ??
              [
                ChapterModel(
                    id: 'chapter-$jlptLevel',
                    jlptLevel: jlptLevel,
                    partNo: 1,
                    chapterNo: 1,
                    title: jlptLevel,
                    completedLessons: 0,
                    totalLessons: jlptLevel == 'N5' ? 2 : 1,
                    lessons: [
                      for (final id in jlptLevel == 'N5'
                          ? ['first', 'later']
                          : ['n4-lesson'])
                        LessonSummaryModel(
                            id: id,
                            lessonNo: 1,
                            chapterLessonNo: 1,
                            title: '저장 레슨 $id',
                            topic: '인사',
                            estimatedMinutes: 10,
                            status: 'NOT_STARTED',
                            scoreCorrect: 0,
                            scoreTotal: 0)
                    ]),
                // A bad cross-level record returned in this response is never read.
                const ChapterModel(
                    id: 'foreign',
                    jlptLevel: 'N1',
                    partNo: 1,
                    chapterNo: 1,
                    title: 'foreign',
                    completedLessons: 0,
                    totalLessons: 1,
                    lessons: [
                      LessonSummaryModel(
                          id: 'foreign',
                          lessonNo: 1,
                          chapterLessonNo: 1,
                          title: 'foreign',
                          topic: '',
                          estimatedMinutes: 10,
                          status: 'NOT_STARTED',
                          scoreCorrect: 0,
                          scoreTotal: 0)
                    ]),
              ]);
  @override
  Future<LessonDetailModel> fetchLessonDetail(String lessonId) async {
    detailReads++;
    throw StateError('List projection must never fetch lesson detail');
  }

  @override
  Future<LessonProgressModel> startLesson(String lessonId) async {
    writes++;
    throw StateError('List projection must never start a lesson');
  }

  @override
  Future<LessonSubmitResultModel> submitLesson(
      String lessonId, List<Map<String, dynamic>> answers) async {
    writes++;
    return const LessonSubmitResultModel(
        scoreCorrect: 0, scoreTotal: 0, results: [], status: 'COMPLETED');
  }
}
