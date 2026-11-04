import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';
import 'package:harukoto_mobile/features/kana/providers/katakana_pilot_review_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accountA = 'first.account';
const _accountB = 'second/account';
const _channel = MethodChannel('plugins.flutter.io/shared_preferences');
const _existing = {
  'flutter.fixture-auth': 'existing-session',
  'flutter.user_daily_goal_v2:$_accountA': 20,
  'flutter.kana_card_progress.v1.$_accountA.sample': 'existing-kana-record',
  'flutter.lesson_checkpoint:$_accountA': 'existing-lesson',
};

final _ownerProvider = NotifierProvider<_Owner, String?>(_Owner.new);

class _Owner extends Notifier<String?> {
  @override
  String? build() => _accountA;

  void change(String? owner) => state = owner;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Storage disk;
  late SharedPreferences preferences;
  late String? activeOwner;

  ProviderContainer container() =>
      ProviderContainer.test(retry: (_, __) => null, overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        currentAccountIdProvider
            .overrideWith((ref) => ref.watch(_ownerProvider)),
        currentAccountReaderProvider.overrideWithValue(() => activeOwner),
      ]);

  setUp(() async {
    activeOwner = _accountA;
    SharedPreferences.resetStatic();
    disk = _Storage();
    messenger.setMockMethodCallHandler(_channel, disk.handle);
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    SharedPreferences.resetStatic();
  });

  test('cold provider restores saved letters and only removes one mark',
      () async {
    final first = container();
    expect(await first.read(katakanaPilotReviewProvider.future), isEmpty);
    final firstReview = first.read(katakanaPilotReviewProvider.notifier);
    await Future.wait([
      firstReview.setMarked(KatakanaPilotLetter.shi, true),
      firstReview.setMarked(KatakanaPilotLetter.n, true),
    ]);
    first.dispose();

    SharedPreferences.resetStatic();
    preferences = await SharedPreferences.getInstance();
    final second = container();
    expect(await second.read(katakanaPilotReviewProvider.future),
        {KatakanaPilotLetter.shi, KatakanaPilotLetter.n});
    await second
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.shi, false);
    expect(await second.read(katakanaPilotReviewProvider.future),
        {KatakanaPilotLetter.n});
    expect(disk.values.keys.where((key) => !key.contains('katakana_pilot')),
        unorderedEquals(_existing.keys));
    for (final entry in _existing.entries) {
      expect(disk.values[entry.key], entry.value);
    }
  });

  test('account switches and logout show only the current local review',
      () async {
    final c = container();
    await c.read(katakanaPilotReviewProvider.future);
    await c
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.tsu, true);

    activeOwner = _accountB;
    c.read(_ownerProvider.notifier).change(activeOwner);
    expect(await c.read(katakanaPilotReviewProvider.future), isEmpty);
    await c
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.so, true);
    expect(await c.read(katakanaPilotReviewProvider.future),
        {KatakanaPilotLetter.so});
    activeOwner = null;
    c.read(_ownerProvider.notifier).change(activeOwner);
    expect(await c.read(katakanaPilotReviewProvider.future), isEmpty);
    await expectLater(
      c
          .read(katakanaPilotReviewProvider.notifier)
          .setMarked(KatakanaPilotLetter.n, true),
      throwsA(isA<ApiException>()),
    );

    activeOwner = _accountA;
    c.read(_ownerProvider.notifier).change(activeOwner);
    expect(await c.read(katakanaPilotReviewProvider.future),
        {KatakanaPilotLetter.tsu});
  });

  test('failed native write does not mark until retry succeeds', () async {
    final c = container();
    await c.read(katakanaPilotReviewProvider.future);
    final review = c.read(katakanaPilotReviewProvider.notifier);
    disk.rejectWrite = true;
    await expectLater(
      review.setMarked(KatakanaPilotLetter.shi, true),
      throwsA(isA<ApiException>()),
    );
    expect(await c.read(katakanaPilotReviewProvider.future), isEmpty);

    // Rebuilding must consult persisted values, not the optimistic SDK cache.
    c.invalidate(katakanaPilotReviewProvider);
    expect(await c.read(katakanaPilotReviewProvider.future), isEmpty);
    disk.rejectWrite = false;
    await c
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.shi, true);
    expect(await c.read(katakanaPilotReviewProvider.future),
        {KatakanaPilotLetter.shi});
  });

  test('load error blocks a new mark until persisted state is recovered',
      () async {
    final c = container();
    await c.read(katakanaPilotReviewProvider.future);
    await c
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.shi, true);
    disk.rejectRead = true;
    c.invalidate(katakanaPilotReviewProvider);
    await expectLater(c.read(katakanaPilotReviewProvider.future),
        throwsA(isA<ApiException>()));
    await expectLater(
      c
          .read(katakanaPilotReviewProvider.notifier)
          .setMarked(KatakanaPilotLetter.n, true),
      throwsA(isA<ApiException>()),
    );
    expect(disk.writes, hasLength(1));
    disk.rejectRead = false;
    c.invalidate(katakanaPilotReviewProvider);
    expect(await c.read(katakanaPilotReviewProvider.future),
        {KatakanaPilotLetter.shi});
  });

  test('delayed native write stays in old account and queued stale tap fails',
      () async {
    final c = container();
    await c.read(katakanaPilotReviewProvider.future);
    final review = c.read(katakanaPilotReviewProvider.notifier);
    final gate = disk.gate = Completer<void>();
    final first = expectLater(
      review.setMarked(KatakanaPilotLetter.n, true),
      throwsA(isA<ApiException>()),
    );
    await disk.started.future;
    final queued = expectLater(
      review.setMarked(KatakanaPilotLetter.so, true),
      throwsA(isA<ApiException>()),
    );
    activeOwner = _accountB;
    c.read(_ownerProvider.notifier).change(activeOwner);
    final newOwner = c.read(katakanaPilotReviewProvider.future);
    gate.complete();
    await Future.wait([first, queued]);
    expect(await newOwner, isEmpty);
    expect(disk.writes, hasLength(1));

    activeOwner = _accountA;
    c.read(_ownerProvider.notifier).change(activeOwner);
    expect(await c.read(katakanaPilotReviewProvider.future),
        {KatakanaPilotLetter.n});
  });
}

class _Storage {
  final values = <String, Object>{..._existing};
  final writes = <String>[];
  final started = Completer<void>();
  Completer<void>? gate;
  bool rejectRead = false;
  bool rejectWrite = false;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getAll':
        if (rejectRead) throw PlatformException(code: 'synthetic-read-failed');
        return Map.of(values);
      case 'setBool':
        final arguments = Map<String, Object>.from(call.arguments as Map);
        final key = arguments['key']! as String;
        writes.add(key);
        if (!started.isCompleted) started.complete();
        await gate?.future;
        if (rejectWrite) return false;
        values[key] = arguments['value']!;
        return true;
      default:
        throw StateError('Unexpected preferences method: ${call.method}');
    }
  }
}
