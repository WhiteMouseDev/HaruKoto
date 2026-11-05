import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/kana/data/kana_writing_progress_store.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_writing_progress.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_writing_progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scope = KanaWritingScope(owner: 'account-a', hiragana: false);
const _channel = MethodChannel('plugins.flutter.io/shared_preferences');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Disk disk;
  late SharedPreferences preferences;
  late PreferencesKanaWritingProgressStore store;
  late ProviderContainer container;
  String? active;
  final key = PreferencesKanaWritingProgressStore.key(_scope);
  final provider = kanaWritingProgressProvider(_scope);
  final old = KanaWritingProgress(
      scope: _scope, session: _session(step: KanaWritingStep.compare));

  setUp(() async {
    SharedPreferences.resetStatic();
    disk = _Disk({
      'flutter.$key': old.encode(),
      'flutter.katakana_pilot_review.v1.account-a.shi': true,
      'flutter.katakana_pilot_review.day.v1.account-a.shi': 20261105,
      'flutter.hiragana_pilot_review.v1.account-a.u': true,
      'flutter.auth-sentinel': 'existing-login',
      'flutter.lesson-sentinel': 'existing-position',
      'flutter.daily-goal-sentinel': 20,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, disk.handle);
    preferences = await SharedPreferences.getInstance();
    store = PreferencesKanaWritingProgressStore(preferences);
    active = _scope.owner;
    container = ProviderContainer(overrides: [
      currentAccountReaderProvider.overrideWithValue(() => active),
      currentAccountIdProvider
          .overrideWith((ref) => ref.watch(currentAccountReaderProvider)()),
      kanaWritingProgressStoreProvider.overrideWithValue(store),
    ]);
    container.listen(provider, (_, __) {});
    await _flush();
  });
  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    SharedPreferences.resetStatic();
  });

  test(
      'restore after fresh provider container keeps glyph stage and finished ink',
      () async {
    final saved =
        _session(index: 2, step: KanaWritingStep.recall, strokes: const [
      [Offset(.1, .2), Offset(.7, .8)]
    ]);
    await container.read(provider.notifier).saveSession(saved);
    expect(container.read(provider).progress!.session!.letter,
        KatakanaPilotLetter.u);
    container.invalidate(provider);
    await _flush();
    final restored = container.read(provider).progress!.session!;
    expect(restored.letter, KatakanaPilotLetter.u);
    expect(restored.step, KanaWritingStep.recall);
    expect(restored.strokes, saved.strokes);
    _expectOtherKeys(disk.values);
  });

  for (final failure in [_Failure.falseResult, _Failure.throwBeforeCommit]) {
    test('$failure keeps visible old checkpoint and retries exact intended one',
        () async {
      final before = Map.of(disk.values);
      disk.failure = failure;
      final next = _session(index: 2, step: KanaWritingStep.recall);
      await container.read(provider.notifier).saveSession(next);
      expect(container.read(provider).error, isNotNull);
      expect(container.read(provider).canAct, isFalse);
      expect(container.read(provider).progress!.session!.step,
          KanaWritingStep.compare);
      expect(preferences.getString(key), old.encode(),
          reason: 'Optimistic SDK cache is discarded after failed ACK.');
      expect(disk.values, before);
      await container
          .read(provider.notifier)
          .saveSession(_session(index: 4, step: KanaWritingStep.word));
      expect(disk.writes, 1, reason: 'Pending failure cannot be overwritten.');
      disk.failure = _Failure.none;
      await container.read(provider.notifier).retry();
      final progress = container.read(provider).progress!;
      expect(progress.session!.letter, KatakanaPilotLetter.u);
      expect(progress.session!.step, KanaWritingStep.recall);
      expect(container.read(provider).canAct, isTrue);
      _expectOtherKeys(disk.values);
    });
  }

  test(
      'committed write with lost ACK is recovered without another native write',
      () async {
    disk.failure = _Failure.commitThenThrow;
    await container
        .read(provider.notifier)
        .saveSession(_session(index: 1, step: KanaWritingStep.word));
    expect(container.read(provider).error, isNotNull);
    expect(disk.writes, 1);
    disk.failure = _Failure.none;
    await container.read(provider.notifier).retry();
    expect(container.read(provider).progress!.session!.index, 1);
    expect(container.read(provider).canAct, isTrue);
    expect(disk.writes, 1);
  });

  test('corrupt and future documents remain stored and block replacement',
      () async {
    for (final raw in ['{broken', '{"version":2}']) {
      disk.values['flutter.$key'] = raw;
      container.invalidate(provider);
      await _flush();
      expect(container.read(provider).blocked, isTrue);
      expect(container.read(provider).progress, isNull);
      await container
          .read(provider.notifier)
          .saveSession(_session(step: KanaWritingStep.compare));
      await container.read(provider.notifier).retry();
      expect(disk.values['flutter.$key'], raw);
      expect(disk.writes, 0);
    }
    _expectOtherKeys(disk.values);
  });

  test('failed durable read never overwrites cached checkpoint', () async {
    disk.failReads = true;
    container.invalidate(provider);
    await _flush();
    expect(container.read(provider).progress, isNull);
    await container
        .read(provider.notifier)
        .saveSession(_session(step: KanaWritingStep.word));
    expect(disk.values['flutter.$key'], old.encode());
    expect(disk.writes, 0);
    disk.failReads = false;
    await container.read(provider.notifier).retry();
    expect(container.read(provider).canAct, isTrue);
  });

  test(
      'account and script keys isolate progress and do not backfill review flags',
      () async {
    const hiragana = KanaWritingScope(owner: 'account-a', hiragana: true);
    const other = KanaWritingScope(owner: 'account-b', hiragana: false);
    final hiraProvider = kanaWritingProgressProvider(hiragana);
    container.listen(hiraProvider, (_, __) {});
    await _flush();
    expect(container.read(hiraProvider).progress!.session, isNull);
    expect(container.read(hiraProvider).progress!.completedBasicCount, 0);
    expect(container.read(provider).progress!.completedBasicCount, 0);
    await container.read(hiraProvider.notifier).saveSession(KanaWritingSession(
        letters: KanaPracticeRow.kaRow.letters(hiragana: true),
        index: 1,
        step: KanaWritingStep.recall,
        mode: KanaWritingMode.row));
    active = other.owner;
    container.invalidate(currentAccountIdProvider);
    final otherProvider = kanaWritingProgressProvider(other);
    container.listen(otherProvider, (_, __) {});
    await _flush();
    expect(container.read(otherProvider).progress!.session, isNull);
    await container
        .read(otherProvider.notifier)
        .saveSession(_session(index: 3, step: KanaWritingStep.word));
    expect(
        KanaWritingProgress.decode(
                disk.values['flutter.$key']! as String, _scope)
            .session!
            .index,
        0);
    expect(disk.values.keys.where((k) => k.contains('kana_writing_progress')),
        hasLength(3));
    _expectOtherKeys(disk.values);
  });

  test('session switch while read is queued prevents old-account write',
      () async {
    disk.readGate = Completer<void>();
    final blocker = store.read(_scope);
    await _flush();
    final write = container
        .read(provider.notifier)
        .saveSession(_session(index: 2, step: KanaWritingStep.recall));
    await _flush();
    active = 'account-b';
    container.invalidate(currentAccountIdProvider);
    await _flush();
    disk.readGate!.complete();
    await blocker;
    await write;
    await _flush();
    expect(disk.writes, 0);
    expect(disk.values['flutter.$key'], old.encode());
  });

  test('concurrent controller cannot overwrite newer durable checkpoint',
      () async {
    final newer = KanaWritingProgress(
        scope: _scope,
        session: _session(index: 4, step: KanaWritingStep.recall));
    disk.values['flutter.$key'] = newer.encode();
    await container
        .read(provider.notifier)
        .saveSession(_session(index: 2, step: KanaWritingStep.recall));
    expect(container.read(provider).error, isNotNull);
    await container.read(provider.notifier).retry();
    expect(container.read(provider).blocked, isTrue);
    expect(disk.writes, 0);
    expect(disk.values['flutter.$key'], newer.encode());
  });

  test('row completion requires last correct answer and is deduplicated',
      () async {
    final controller = container.read(provider.notifier);
    await controller.finishSession(completedRow: KanaPracticeRow.firstRow);
    expect(container.read(provider).progress!.completedBasicCount, 0);
    final last = KanaPracticeRow.firstRow.letters(hiragana: false).last;
    final selected = last.word.runes.toList().indexOf(last.glyph.runes.single);
    await controller.saveSession(_session(
        index: 4, step: KanaWritingStep.word, selectedIndex: selected));
    await controller.finishSession(completedRow: KanaPracticeRow.firstRow);
    expect(container.read(provider).progress!.session, isNull);
    expect(container.read(provider).progress!.completedBasicCount, 5);
    expect(container.read(provider).progress!.recommendedRow,
        KanaPracticeRow.kaRow);
    final writes = disk.writes;
    await controller.finishSession(completedRow: KanaPracticeRow.firstRow);
    expect(container.read(provider).progress!.completedBasicCount, 5);
    expect(disk.writes, writes);
    _expectOtherKeys(disk.values);
  });
}

KanaWritingSession _session(
        {int index = 0,
        required KanaWritingStep step,
        int? selectedIndex,
        List<List<Offset>> strokes = const []}) =>
    KanaWritingSession(
        letters: KanaPracticeRow.firstRow.letters(hiragana: false),
        index: index,
        step: step,
        mode: KanaWritingMode.row,
        selectedIndex: selectedIndex,
        strokes: strokes);

enum _Failure { none, falseResult, throwBeforeCommit, commitThenThrow }

class _Disk {
  _Disk(this.values);
  final Map<String, Object> values;
  int writes = 0;
  bool failReads = false;
  Completer<void>? readGate;
  _Failure failure = _Failure.none;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getAll':
        if (readGate != null) await readGate!.future;
        if (failReads) throw PlatformException(code: 'fixture-read-failed');
        return Map.of(values);
      case 'setString':
        writes++;
        if (failure == _Failure.falseResult) return false;
        if (failure == _Failure.throwBeforeCommit) {
          throw PlatformException(code: 'fixture-write-failed');
        }
        final args = Map<String, Object>.from(call.arguments as Map);
        values[args['key']! as String] = args['value']!;
        if (failure == _Failure.commitThenThrow) {
          throw PlatformException(code: 'fixture-ack-lost');
        }
        return true;
      case 'clear':
      case 'remove':
        throw StateError('Writing progress must not delete existing records');
      default:
        throw StateError('Unexpected preferences call ${call.method}');
    }
  }
}

void _expectOtherKeys(Map<String, Object> values) {
  expect(values['flutter.katakana_pilot_review.v1.account-a.shi'], true);
  expect(
      values['flutter.katakana_pilot_review.day.v1.account-a.shi'], 20261105);
  expect(values['flutter.hiragana_pilot_review.v1.account-a.u'], true);
  expect(values['flutter.auth-sentinel'], 'existing-login');
  expect(values['flutter.lesson-sentinel'], 'existing-position');
  expect(values['flutter.daily-goal-sentinel'], 20);
}

Future<void> _flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
