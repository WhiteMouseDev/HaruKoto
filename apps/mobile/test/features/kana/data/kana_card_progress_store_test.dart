import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/kana/data/kana_card_progress_store.dart';
import 'package:harukoto_mobile/features/kana/data/kana_repository.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_card_progress.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_card_progress_provider.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _kana = '33333333-3333-4333-8333-333333333333';
const _id = '55555555-5555-4555-8555-555555555555';
const _otherId = '66666666-6666-4666-8666-666666666666';
const _channel = MethodChannel('plugins.flutter.io/shared_preferences');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _PlatformStorage disk;
  late SharedPreferences preferences;
  late PreferencesKanaCardProgressStore store;
  final content = _content();
  final key = PreferencesKanaCardProgressStore.key(_owner, content.stageId);
  final old = _journal(content).encode();
  final pending = _journal(content).prepare(_id).encode();

  setUp(() async {
    SharedPreferences.resetStatic();
    disk = _PlatformStorage({
      'flutter.$key': old,
      'flutter.fixture-auth-session': 'existing-session-sentinel',
      'flutter.user_daily_goal_v2:$_owner': 20,
      'flutter.lesson_checkpoint:$_owner': 'existing-position-sentinel',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, disk.handle);
    preferences = await SharedPreferences.getInstance();
    store = PreferencesKanaCardProgressStore(preferences);
    disk.peekCache = () => preferences.getString(key);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    SharedPreferences.resetStatic();
  });

  test('read reloads native storage instead of stale SDK cache', () async {
    disk.values['flutter.$key'] = pending;
    expect(preferences.getString(key), old);
    expect(await store.read(content), pending);
    expect(preferences.getString(key), pending);
    expect(disk.writes, isEmpty);
  });

  for (final failure in [
    _WriteFailure.returnFalse,
    _WriteFailure.throwBeforeCommit
  ]) {
    test('$failure rejects optimistic cache and recovers durable value',
        () async {
      final before = Map.of(disk.values);
      disk.failure = failure;
      await expectLater(
          store.compareAndSet(content, expected: old, value: pending),
          throwsA(isA<KanaCardStorageException>()));
      expect(disk.cacheSeenAtWrite, pending,
          reason: 'Uses actual SharedPreferences optimistic cache behavior.');
      expect(disk.values, before);
      expect(preferences.getString(key), old);
      expect(await store.read(content), old);
      disk.failure = _WriteFailure.none;
      await store.compareAndSet(content, expected: old, value: pending);
      expect(await store.read(content), pending);
      expect(disk.removals, 0);
      expect(disk.clears, 0);
      _expectUnrelatedPreserved(disk.values);
    });
  }

  test('native commit followed by thrown result is recovered, not overwritten',
      () async {
    disk.failure = _WriteFailure.commitThenThrow;
    await expectLater(
        store.compareAndSet(content, expected: old, value: pending),
        throwsA(isA<KanaCardStorageException>()));
    expect(await store.read(content), pending);
    expect(preferences.getString(key), pending);
    disk.failure = _WriteFailure.none;
    final competing = _journal(content).prepare(_otherId).encode();
    await expectLater(
        store.compareAndSet(content, expected: old, value: competing),
        throwsA(isA<KanaCardStorageException>()));
    expect(disk.writes, hasLength(1));
    expect(await store.read(content), pending);
  });

  test('failed reload never returns an unconfirmed optimistic cache value',
      () async {
    disk.failure = _WriteFailure.returnFalse;
    disk.failReadsAfterWrite = true;
    await expectLater(
        store.compareAndSet(content, expected: old, value: pending),
        throwsA(isA<PlatformException>()));
    expect(preferences.getString(key), pending);
    expect(disk.values['flutter.$key'], old);
    await expectLater(store.read(content), throwsA(isA<PlatformException>()));
    disk.failReads = false;
    disk.failReadsAfterWrite = false;
    expect(await store.read(content), old);
  });

  test(
      'real controller cannot POST when durable read fails despite cached pending',
      () async {
    disk.failure = _WriteFailure.returnFalse;
    disk.failReadsAfterWrite = true;
    await expectLater(
        store.compareAndSet(content, expected: old, value: pending),
        throwsA(isA<PlatformException>()));
    final repo = _NoPostRepository();
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue(_owner),
      currentAccountReaderProvider.overrideWithValue(() => _owner),
      kanaCardProgressStoreProvider.overrideWithValue(store),
      kanaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    final provider = kanaCardProgressProvider(content);
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    await _flush();
    expect(container.read(provider).journal, isNull);
    expect(container.read(provider).error, isNotNull);
    final controller = container.read(provider.notifier);
    await controller.saveAndAdvance();
    await controller.retry();
    expect(repo.posts, 0);
    expect(disk.values['flutter.$key'], old);
    disk.failReads = false;
    disk.failReadsAfterWrite = false;
    await controller.retry();
    expect(container.read(provider).journal!.cursor,
        const KanaCardCursor(KanaCardPhase.intro, 0));
    expect(container.read(provider).journal!.pending, isNull);
    expect(repo.posts, 0,
        reason: 'Recovery reads do not automatically create a new activity.');
  });

  test(
      'two store instances serialize competing CAS and preserve first prepared ID',
      () async {
    final otherStore = PreferencesKanaCardProgressStore(preferences);
    disk.setGate = Completer<void>();
    final first = store.compareAndSet(content, expected: old, value: pending);
    await disk.firstWrite.future;
    final competing = _journal(content).prepare(_otherId).encode();
    final second =
        otherStore.compareAndSet(content, expected: old, value: competing);
    final rejected =
        expectLater(second, throwsA(isA<KanaCardStorageException>()));
    await _flush();
    expect(disk.writes, hasLength(1));
    disk.setGate!.complete();
    await first;
    await rejected;
    expect(disk.writes, hasLength(1));
    expect(await otherStore.read(content), pending);
    expect(KanaCardJournal.decode(pending).pending!.activityId, _id);
  });

  test('reads from second instance wait for the first durable write result',
      () async {
    final otherStore = PreferencesKanaCardProgressStore(preferences);
    disk.setGate = Completer<void>();
    final first = store.compareAndSet(content, expected: old, value: pending);
    await disk.firstWrite.future;
    var readFinished = false;
    final read = otherStore.read(content).then((value) {
      readFinished = true;
      return value;
    });
    await _flush();
    expect(readFinished, isFalse);
    disk.setGate!.complete();
    await first;
    expect(await read, pending);
  });

  test('ACK and next cursor replace one key without deleting pending ID',
      () async {
    final prepared = _journal(content).prepare(_id);
    final acked = prepared.acknowledge(KanaCardReceipt(
        activityId: _id, processedAt: DateTime.utc(2026, 11, 4)));
    final next = acked.advance();
    await store.compareAndSet(content, expected: old, value: prepared.encode());
    await store.compareAndSet(content,
        expected: prepared.encode(), value: acked.encode());
    await store.compareAndSet(content,
        expected: acked.encode(), value: next.encode());
    expect(disk.writes.map((write) => write['key']).toSet(), {'flutter.$key'});
    final snapshots = disk.writes
        .map((write) => KanaCardJournal.decode(write['value']! as String))
        .toList();
    expect(snapshots[0].pending!.activityId, _id);
    expect(snapshots[1].receipt!.activityId, _id);
    expect(snapshots[1].cursor, snapshots[0].cursor);
    expect(snapshots[2].lastReceipt!.activityId, _id);
    expect(snapshots[2].cursor.phase, KanaCardPhase.practice);
    expect(disk.removals, 0);
    expect(disk.clears, 0);
    _expectUnrelatedPreserved(disk.values);
  });

  for (final mismatch in ['owner', 'text', 'stage']) {
    test('CAS rejects $mismatch mismatch and retains original raw data',
        () async {
      final changed = _content(
          owner: mismatch == 'owner' ? _other : _owner,
          stage: mismatch == 'stage' ? 'another-stage' : 'stage-one',
          text: mismatch == 'text' ? 'ア' : 'あ');
      final before = Map.of(disk.values);
      await expectLater(
          store.compareAndSet(content,
              expected: old, value: _journal(changed).encode()),
          throwsA(isA<KanaCardStorageException>()));
      expect(disk.values, before);
      expect(disk.writes, isEmpty);
    });
  }

  test('malformed stored journal is readable raw and never silently replaced',
      () async {
    const broken = '{broken-preserve-me';
    disk.values['flutter.$key'] = broken;
    expect(await store.read(content), broken);
    await expectLater(
        store.compareAndSet(content, expected: old, value: pending),
        throwsA(isA<KanaCardStorageException>()));
    expect(disk.values['flutter.$key'], broken);
    expect(disk.writes, isEmpty);
  });

  test(
      'matching corrupt expected bytes cannot authorize replacing the only saved ID',
      () async {
    const broken = '{broken-preserve-me';
    disk.values['flutter.$key'] = broken;
    await expectLater(
        store.compareAndSet(content, expected: broken, value: pending),
        throwsA(
            anyOf(isA<FormatException>(), isA<KanaCardStorageException>())));
    expect(disk.values['flutter.$key'], broken);
    expect(disk.writes, isEmpty);
  });

  test(
      'matching old bytes cannot replace a changed content snapshot at the same key',
      () async {
    final changed = _content(text: 'ア');
    final replacement = _journal(changed).prepare(_id).encode();
    await expectLater(
        store.compareAndSet(changed, expected: old, value: replacement),
        throwsA(isA<KanaCardStorageException>()));
    expect(disk.values['flutter.$key'], old);
    expect(disk.writes, isEmpty);
  });

  test('invalid new journal is rejected before any native write', () async {
    await expectLater(store.compareAndSet(content, expected: old, value: '{}'),
        throwsFormatException);
    expect(disk.writes, isEmpty);
    expect(await store.read(content), old);
  });

  test('owner namespaces stay separate and never alter auth, goal, lesson keys',
      () async {
    final other = _content(owner: _other);
    expect(await store.read(other), isNull);
    await store.compareAndSet(other,
        expected: null, value: _journal(other).encode());
    expect(await store.read(content), old);
    expect(await store.read(other), _journal(other).encode());
    expect(disk.values.keys.where((k) => k.contains('kana_card_progress')),
        hasLength(2));
    _expectUnrelatedPreserved(disk.values);
  });
}

enum _WriteFailure { none, returnFalse, throwBeforeCommit, commitThenThrow }

class _PlatformStorage {
  _PlatformStorage(this.values);
  final Map<String, Object> values;
  final writes = <Map<String, Object>>[];
  final firstWrite = Completer<void>();
  Completer<void>? setGate;
  _WriteFailure failure = _WriteFailure.none;
  bool failReads = false;
  bool failReadsAfterWrite = false;
  int removals = 0;
  int clears = 0;
  String? Function()? peekCache;
  String? cacheSeenAtWrite;
  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getAll':
        if (failReads) throw PlatformException(code: 'synthetic-read-failed');
        return Map<String, Object>.of(values);
      case 'setString':
        final args = Map<String, Object>.from(call.arguments as Map);
        writes.add(args);
        cacheSeenAtWrite = peekCache?.call();
        if (!firstWrite.isCompleted) firstWrite.complete();
        if (setGate != null) await setGate!.future;
        if (failReadsAfterWrite) failReads = true;
        if (failure == _WriteFailure.returnFalse) return false;
        if (failure == _WriteFailure.throwBeforeCommit) {
          throw PlatformException(code: 'synthetic-write-failed');
        }
        values[args['key']! as String] = args['value']!;
        if (failure == _WriteFailure.commitThenThrow) {
          throw PlatformException(code: 'synthetic-ack-lost');
        }
        return true;
      case 'remove':
        removals++;
        throw StateError('Journal must not delete unrelated storage');
      case 'clear':
        clears++;
        throw StateError('Journal must never clear storage');
      default:
        throw StateError('Unexpected preferences method: ${call.method}');
    }
  }
}

class _NoPostRepository extends KanaRepository {
  _NoPostRepository() : super(Dio());
  int posts = 0;
  @override
  Future<KanaCardReceipt> submitCardProgress(KanaCardActivity request,
      {CancelToken? cancelToken}) async {
    posts++;
    throw StateError('No POST is allowed before durable state is known');
  }
}

KanaCardContent _content(
        {String owner = _owner,
        String stage = 'stage-one',
        String text = 'あ'}) =>
    KanaCardContent(
        owner: owner,
        stageId: stage,
        kanaType: 'HIRAGANA',
        stageNumber: 1,
        characters: [(id: _kana, text: text)]);
KanaCardJournal _journal(KanaCardContent content) => KanaCardJournal(
    content: content, cursor: const KanaCardCursor(KanaCardPhase.intro, 0));
void _expectUnrelatedPreserved(Map<String, Object> values) {
  expect(values['flutter.fixture-auth-session'], 'existing-session-sentinel');
  expect(values['flutter.user_daily_goal_v2:$_owner'], 20);
  expect(values['flutter.lesson_checkpoint:$_owner'],
      'existing-position-sentinel');
}

Future<void> _flush() async {
  for (var n = 0; n < 8; n++) {
    await Future<void>.delayed(Duration.zero);
  }
}
