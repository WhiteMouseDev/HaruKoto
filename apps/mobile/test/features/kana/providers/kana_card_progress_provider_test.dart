import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/home/providers/study_activity_refresh_provider.dart';
import 'package:harukoto_mobile/features/kana/data/kana_card_progress_store.dart';
import 'package:harukoto_mobile/features/kana/data/kana_repository.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_card_progress.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_card_progress_provider.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _kana1 = '33333333-3333-4333-8333-333333333333';
const _kana2 = '44444444-4444-4444-8444-444444444444';

void main() {
  test('persist frozen request before POST and ACK before moving card',
      () async {
    final f = _Fixture();
    addTearDown(f.close);
    await f.ready();
    f.repo.gate = Completer<void>();
    final saving = f.controller.saveAndAdvance();
    await _flush();
    final pending = KanaCardJournal.decode(f.store.raw!);
    expect(pending.cursor.index, 0);
    expect(pending.receipt, isNull);
    expect(pending.pending!.activityId, f.repo.requests.single.activityId);
    expect(f.state.journal!.cursor.index, 0);
    expect(f.state.busy, isTrue);
    await f.controller.saveAndAdvance();
    await f.controller.skipPractice();
    expect(f.repo.requests, hasLength(1));
    f.repo.gate!.complete();
    await saving;
    expect(f.state.journal!.cursor.index, 1);
    expect(
        f.store.saved.map((raw) => KanaCardJournal.decode(raw).receipt != null),
        [false, true, false]);
    expect(KanaCardJournal.decode(f.store.saved.last).lastReceipt!.activityId,
        pending.pending!.activityId);
    expect(f.repo.effects, 1);
    expect(f.refresh.calls, 1);
  });

  test(
      'commit then response loss repeats same ID/body once after explicit retry',
      () async {
    final f = _Fixture()..repo.loseResponse = true;
    addTearDown(f.close);
    await f.ready();
    await f.controller.saveAndAdvance();
    final id = f.repo.requests.single.activityId;
    expect(f.state.error, isNotNull);
    expect(f.state.journal!.cursor.index, 0);
    expect(f.repo.effects, 1);
    await f.controller.retry();
    expect(f.repo.requests.map((request) => request.toJson()), [
      {'activityId': id, 'expectedUserId': _owner, 'kanaId': _kana1},
      {'activityId': id, 'expectedUserId': _owner, 'kanaId': _kana1},
    ]);
    expect(f.repo.effects, 1);
    expect(f.state.journal!.cursor.index, 1);
    expect(f.repo.legacyWrites, 0);
  });

  test(
      'cold controller restores pending card and same ID without automatic POST',
      () async {
    final store = _Store();
    final repo = _Repository()..loseResponse = true;
    final first = _Fixture(store: store, repo: repo);
    await first.ready();
    await first.controller.saveAndAdvance();
    final raw = store.raw;
    final id = repo.requests.single.activityId;
    first.close();
    final fresh = _Fixture(store: store, repo: repo);
    addTearDown(fresh.close);
    await fresh.ready();
    expect(store.raw, raw);
    expect(fresh.state.journal!.cursor.index, 0);
    expect(fresh.state.journal!.pending!.activityId, id);
    expect(repo.requests, hasLength(1));
    await fresh.controller.retry();
    expect(repo.requests.map((value) => value.activityId), [id, id]);
    expect(repo.effects, 1);
    expect(fresh.state.journal!.cursor.index, 1);
  });

  test(
      'preparation write failure sends no POST and retains in-memory ID for retry',
      () async {
    final f = _Fixture()..store.failWrite = 1;
    addTearDown(f.close);
    await f.ready();
    await f.controller.saveAndAdvance();
    expect(f.repo.requests, isEmpty);
    expect(f.state.error, isNotNull);
    expect(f.store.raw, isNull);
    expect(f.ids, 1);
    await f.controller.retry();
    expect(f.ids, 1);
    expect(f.repo.requests.single.activityId, _id(1));
    expect(f.state.journal!.cursor.index, 1);
  });

  test('ACK persistence failure retries local write without another POST',
      () async {
    final f = _Fixture()..store.failWrite = 2;
    addTearDown(f.close);
    await f.ready();
    await f.controller.saveAndAdvance();
    expect(f.repo.requests, hasLength(1));
    expect(KanaCardJournal.decode(f.store.raw!).receipt, isNull);
    expect(f.state.journal!.cursor.index, 0);
    await f.controller.retry();
    expect(f.repo.requests, hasLength(1));
    expect(f.repo.effects, 1);
    expect(f.state.journal!.cursor.index, 1);
  });

  test(
      'cold restart after lost local ACK repeats same server receipt, not effect',
      () async {
    final store = _Store()..failWrite = 2;
    final repo = _Repository();
    final first = _Fixture(store: store, repo: repo);
    await first.ready();
    await first.controller.saveAndAdvance();
    final id = repo.requests.single.activityId;
    first.close();
    final fresh = _Fixture(store: store, repo: repo);
    addTearDown(fresh.close);
    await fresh.ready();
    await fresh.controller.retry();
    expect(repo.requests.map((value) => value.activityId), [id, id]);
    expect(repo.effects, 1);
    expect(fresh.state.journal!.cursor.index, 1);
  });

  test(
      'cursor persistence failure recovers durable ACK locally on cold restart',
      () async {
    final store = _Store()..failWrite = 3;
    final repo = _Repository();
    final first = _Fixture(store: store, repo: repo);
    await first.ready();
    await first.controller.saveAndAdvance();
    expect(KanaCardJournal.decode(store.raw!).receipt, isNotNull);
    expect(first.state.journal!.cursor.index, 0);
    first.close();
    final fresh = _Fixture(store: store, repo: repo);
    addTearDown(fresh.close);
    await fresh.ready();
    expect(fresh.state.journal!.cursor.index, 1);
    expect(repo.requests, hasLength(1));
    expect(repo.effects, 1);
  });

  for (final boundary in [1, 2, 3]) {
    test(
        'write $boundary committed before error is reconciled without duplication',
        () async {
      final f = _Fixture()..store.commitThenThrow = boundary;
      addTearDown(f.close);
      await f.ready();
      await f.controller.saveAndAdvance();
      expect(f.state.error, isNotNull);
      await f.controller.retry();
      expect(f.state.journal!.cursor.index, 1);
      expect(f.repo.effects, 1);
      expect(f.ids, 1);
    });
  }

  test('intro and practice of same kana are intentional distinct activities',
      () async {
    final content = _content(single: true);
    final f = _Fixture(content: content);
    addTearDown(f.close);
    await f.ready();
    await f.controller.saveAndAdvance();
    expect(f.state.journal!.cursor.phase, KanaCardPhase.practice);
    await f.controller.saveAndAdvance();
    expect(f.repo.requests.map((value) => value.kanaId), [_kana1, _kana1]);
    expect(
        f.repo.requests.map((value) => value.activityId).toSet(), hasLength(2));
    expect(f.repo.effects, 2);
    expect(f.state.journal!.cursor.phase, KanaCardPhase.quiz);
  });

  test('skip persists practice position but creates no server activity',
      () async {
    final f = _Fixture(content: _content(single: true));
    addTearDown(f.close);
    await f.ready();
    await f.controller.saveAndAdvance();
    final requests = f.repo.requests.length;
    await f.controller.skipPractice();
    expect(f.repo.requests, hasLength(requests));
    expect(f.state.journal!.cursor.phase, KanaCardPhase.quiz);
  });

  test('quiz-ready tombstone restores without starting or completing any quiz',
      () async {
    final content = _content(single: true);
    final store = _Store();
    final repo = _Repository();
    final first = _Fixture(content: content, store: store, repo: repo);
    await first.ready();
    await first.controller.saveAndAdvance();
    await first.controller.skipPractice();
    first.close();
    final fresh =
        _Fixture(content: content, store: store, repo: repo, idOffset: 10);
    addTearDown(fresh.close);
    await fresh.ready();
    expect(fresh.state.journal!.cursor.phase, KanaCardPhase.quiz);
    expect(repo.requests, hasLength(1));
    await fresh.controller.restartCards();
    expect(fresh.state.journal!.cursor,
        const KanaCardCursor(KanaCardPhase.intro, 0));
    await fresh.controller.saveAndAdvance();
    expect(repo.requests, hasLength(2));
    expect(
        repo.requests.map((value) => value.activityId).toSet(), hasLength(2));
  });

  test('content change preserves old pending raw without replay or reset',
      () async {
    final store = _Store();
    final repo = _Repository()..loseResponse = true;
    final first = _Fixture(store: store, repo: repo);
    await first.ready();
    await first.controller.saveAndAdvance();
    first.close();
    final raw = store.raw;
    final changed = KanaCardContent(
        owner: _owner,
        stageId: 'stage',
        kanaType: 'HIRAGANA',
        stageNumber: 1,
        characters: [(id: _kana2, text: 'い'), (id: _kana1, text: 'あ')]);
    final fresh = _Fixture(content: changed, store: store, repo: repo);
    addTearDown(fresh.close);
    await fresh.ready();
    expect(fresh.state.blocked, isTrue);
    await fresh.controller.retry();
    await fresh.controller.restartCards();
    await fresh.controller.saveAndAdvance();
    expect(store.raw, raw);
    expect(repo.requests, hasLength(1));
  });

  test('corrupt raw and storage read error are not replaced or sent', () async {
    final f = _Fixture()..store.raw = '{broken';
    addTearDown(f.close);
    await f.ready();
    expect(f.state.blocked, isTrue);
    expect(f.store.raw, '{broken');
    await f.controller.retry();
    expect(f.repo.requests, isEmpty);
    expect(f.store.saved, isEmpty);
  });

  test('read failure can retry before any network action', () async {
    final f = _Fixture()..store.failRead = true;
    addTearDown(f.close);
    await f.ready();
    expect(f.state.error, isNotNull);
    expect(f.repo.requests, isEmpty);
    f.store.failRead = false;
    await f.controller.retry();
    expect(f.state.canAct, isTrue);
    expect(f.repo.requests, isEmpty);
  });

  test('account change before durable write ACK never sends a request',
      () async {
    final f = _Fixture();
    addTearDown(f.close);
    await f.ready();
    f.store.gate = Completer<void>();
    final saving = f.controller.saveAndAdvance();
    await _flush();
    f.owner = _other;
    f.store.gate!.complete();
    await saving;
    expect(f.repo.requests, isEmpty);
    expect(KanaCardJournal.decode(f.store.raw!).content.owner, _owner);
  });

  test(
      'account change and disposal ignore old response but retain prepared action',
      () async {
    final f = _Fixture();
    await f.ready();
    f.repo.gate = Completer<void>();
    final saving = f.controller.saveAndAdvance();
    await _flush();
    final raw = f.store.raw;
    f.owner = _other;
    f.close();
    f.repo.gate!.complete();
    await saving;
    expect(f.store.raw, raw);
    expect(f.refresh.calls, 0);
    expect(f.repo.effects, 1);
  });

  test('two controllers cannot overwrite pending action for the same card',
      () async {
    final store = _Store();
    final repo = _Repository()..gate = Completer<void>();
    final first = _Fixture(store: store, repo: repo);
    final second = _Fixture(store: store, repo: repo, idOffset: 10);
    addTearDown(first.close);
    addTearDown(second.close);
    await first.ready();
    await second.ready();
    final saving = first.controller.saveAndAdvance();
    await _flush();
    await second.controller.saveAndAdvance();
    expect(repo.requests, hasLength(1));
    expect(second.state.error, isNotNull);
    await second.controller.retry();
    expect(second.state.blocked, isTrue);
    repo.gate!.complete();
    await saving;
    expect(repo.effects, 1);
  });

  for (final error in [
    const ApiException(message: 'not deployed', statusCode: 404),
    const FormatException('mismatched receipt'),
  ]) {
    test('new endpoint failure $error never falls back to legacy progress',
        () async {
      final f = _Fixture()..repo.failure = error;
      addTearDown(f.close);
      await f.ready();
      await f.controller.saveAndAdvance();
      expect(f.state.error, isNotNull);
      expect(f.state.journal!.cursor.index, 0);
      expect(f.repo.legacyWrites, 0);
      await f.controller.retry();
      expect(f.repo.requests.map((value) => value.activityId).toSet(),
          hasLength(1));
      expect(f.repo.legacyWrites, 0);
    });
  }
}

String _id(int number) =>
    'aaaaaaaa-aaaa-4aaa-8aaa-${number.toString().padLeft(12, '0')}';
KanaCardContent _content({bool single = false}) => KanaCardContent(
        owner: _owner,
        stageId: 'stage',
        kanaType: 'HIRAGANA',
        stageNumber: 1,
        characters: [
          (id: _kana1, text: 'あ'),
          if (!single) (id: _kana2, text: 'い')
        ]);
Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Fixture {
  _Fixture(
      {KanaCardContent? content,
      _Store? store,
      _Repository? repo,
      this.idOffset = 0})
      : content = content ?? _content(),
        store = store ?? _Store(),
        repo = repo ?? _Repository() {
    container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => owner),
      currentAccountReaderProvider.overrideWithValue(() => owner),
      kanaCardProgressStoreProvider.overrideWithValue(this.store),
      kanaRepositoryProvider.overrideWithValue(this.repo),
      studyActivityRefreshProvider.overrideWithValue(refresh),
      kanaCardActivityIdProvider.overrideWithValue(() => _id(idOffset + ++ids)),
    ]);
    subscription =
        container.listen(kanaCardProgressProvider(this.content), (_, __) {});
  }
  final KanaCardContent content;
  final _Store store;
  final _Repository repo;
  final int idOffset;
  final refresh = _Refresh();
  String owner = _owner;
  int ids = 0;
  late final ProviderContainer container;
  late final ProviderSubscription<KanaCardProgressState> subscription;
  bool closed = false;
  KanaCardProgressController get controller =>
      container.read(kanaCardProgressProvider(content).notifier);
  KanaCardProgressState get state =>
      container.read(kanaCardProgressProvider(content));
  Future<void> ready() async => _flush();
  void close() {
    if (closed) return;
    closed = true;
    subscription.close();
    container.dispose();
  }
}

class _Refresh extends Fake implements StudyActivityRefresh {
  int calls = 0;
  @override
  void refresh() {
    calls++;
  }
}

class _Store implements KanaCardProgressStore {
  String? raw;
  int writes = 0;
  int failWrite = -1;
  int commitThenThrow = -1;
  bool failRead = false;
  Completer<void>? gate;
  final saved = <String>[];
  @override
  Future<String?> read(KanaCardContent content) async {
    if (failRead) throw const KanaCardStorageException();
    return raw;
  }

  @override
  Future<void> compareAndSet(KanaCardContent content,
      {required String? expected, required String value}) async {
    final number = ++writes;
    await gate?.future;
    if (raw != expected || number == failWrite) {
      throw const KanaCardStorageException();
    }
    raw = value;
    saved.add(value);
    if (number == commitThenThrow) throw const KanaCardStorageException();
  }
}

class _Repository extends Fake implements KanaRepository {
  bool loseResponse = false;
  Object? failure;
  Completer<void>? gate;
  int effects = 0;
  int legacyWrites = 0;
  final requests = <KanaCardActivity>[];
  final receipts = <String, KanaCardReceipt>{};
  @override
  Future<KanaCardReceipt> submitCardProgress(KanaCardActivity request,
      {CancelToken? cancelToken}) async {
    requests.add(request);
    await gate?.future;
    if (failure != null) throw failure!;
    final receipt = receipts.putIfAbsent(request.activityId, () {
      effects++;
      return KanaCardReceipt(
          activityId: request.activityId,
          processedAt: DateTime.utc(2026, 11, 4));
    });
    if (loseResponse) {
      loseResponse = false;
      throw const ApiException(
          message: 'lost response', errorCode: 'NETWORK_TIMEOUT');
    }
    return receipt;
  }

  @override
  Future<void> updateProgress(
      {required String kanaId, required bool learned}) async {
    legacyWrites++;
  }
}
