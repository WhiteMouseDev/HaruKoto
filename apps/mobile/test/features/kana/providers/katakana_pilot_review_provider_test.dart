import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';
import 'package:harukoto_mobile/features/kana/providers/katakana_pilot_review_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accountA = 'first.account';
const _accountB = 'second/account';
const _mark = 'flutter.katakana_pilot_review.v1.$_accountA';
const _day = 'flutter.katakana_pilot_review.day.v1.$_accountA';
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
  late DateTime now;

  ProviderContainer container() =>
      ProviderContainer.test(retry: (_, __) => null, overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        studyClockProvider.overrideWithValue(() => now),
        currentAccountIdProvider
            .overrideWith((ref) => ref.watch(_ownerProvider)),
        currentAccountReaderProvider.overrideWithValue(() => activeOwner),
      ]);

  setUp(() async {
    activeOwner = _accountA;
    now = DateTime(2026, 11, 4, 23, 59);
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
    expect(
        (await first.read(katakanaPilotReviewProvider.future)).marked, isEmpty);
    final firstReview = first.read(katakanaPilotReviewProvider.notifier);
    await Future.wait([
      firstReview.setMarked(KatakanaPilotLetter.shi, true),
      firstReview.setMarked(KatakanaPilotLetter.n, true),
    ]);
    first.dispose();

    SharedPreferences.resetStatic();
    preferences = await SharedPreferences.getInstance();
    final second = container();
    expect((await second.read(katakanaPilotReviewProvider.future)).marked,
        {KatakanaPilotLetter.shi, KatakanaPilotLetter.n});
    await second
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.shi, false);
    expect((await second.read(katakanaPilotReviewProvider.future)).marked,
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
    expect((await c.read(katakanaPilotReviewProvider.future)).marked, isEmpty);
    await c
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.so, true);
    expect((await c.read(katakanaPilotReviewProvider.future)).marked,
        {KatakanaPilotLetter.so});
    activeOwner = null;
    c.read(_ownerProvider.notifier).change(activeOwner);
    expect((await c.read(katakanaPilotReviewProvider.future)).marked, isEmpty);
    await expectLater(
      c
          .read(katakanaPilotReviewProvider.notifier)
          .setMarked(KatakanaPilotLetter.n, true),
      throwsA(isA<ApiException>()),
    );

    activeOwner = _accountA;
    c.read(_ownerProvider.notifier).change(activeOwner);
    expect((await c.read(katakanaPilotReviewProvider.future)).marked,
        {KatakanaPilotLetter.tsu});
  });

  test('marks from the four-letter pilot coexist with a new group mark',
      () async {
    disk.values.addAll({
      'flutter.katakana_pilot_review.v1.$_accountA.shi': true,
      'flutter.katakana_pilot_review.v1.$_accountA.n': true,
    });

    final first = container();
    expect((await first.read(katakanaPilotReviewProvider.future)).marked,
        {KatakanaPilotLetter.shi, KatakanaPilotLetter.n});
    await first
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.wa, true);
    expect(disk.writes, ['$_day.wa', '$_mark.wa']);
    first.dispose();

    SharedPreferences.resetStatic();
    preferences = await SharedPreferences.getInstance();
    final reopened = container();
    expect((await reopened.read(katakanaPilotReviewProvider.future)).marked, {
      KatakanaPilotLetter.shi,
      KatakanaPilotLetter.n,
      KatakanaPilotLetter.wa,
    });
  });

  test('new marks wait for tomorrow and only unfinished glyphs resume',
      () async {
    disk.values['$_mark.shi'] = true;
    final first = container();
    final review = first.read(katakanaPilotReviewProvider.notifier);
    expect((await first.read(katakanaPilotReviewProvider.future)).dueOn(now),
        {KatakanaPilotLetter.shi});
    await review.setMarked(KatakanaPilotLetter.n, true);
    await review.setMarked(KatakanaPilotLetter.fu, true);
    await review.setMarked(KatakanaPilotLetter.shi, true);
    expect((await first.read(katakanaPilotReviewProvider.future)).dueOn(now),
        {KatakanaPilotLetter.shi});
    expect(disk.values['$_day.shi'], isNull);

    now = DateTime(2026, 11, 5);
    expect((await first.read(katakanaPilotReviewProvider.future)).dueOn(now), {
      KatakanaPilotLetter.shi,
      KatakanaPilotLetter.n,
      KatakanaPilotLetter.fu
    });
    await Future.wait([
      review.completeDailyReview(KatakanaPilotLetter.shi, now),
      review.completeDailyReview(KatakanaPilotLetter.shi, now),
      review.completeDailyReview(KatakanaPilotLetter.n, now),
    ]);
    expect(disk.writes.where((key) => key == '$_day.shi'), hasLength(1));
    expect(disk.values['$_mark.shi'], true);
    expect(disk.values['$_day.shi'], 20261105);
    expect(disk.values['$_mark.n'], true);
    first.dispose();

    SharedPreferences.resetStatic();
    preferences = await SharedPreferences.getInstance();
    final second = container();
    final restored = await second.read(katakanaPilotReviewProvider.future);
    expect(restored.marked, {
      KatakanaPilotLetter.shi,
      KatakanaPilotLetter.n,
      KatakanaPilotLetter.fu
    });
    expect(restored.dueOn(now), {KatakanaPilotLetter.fu});
    expect(restored.dueOn(DateTime(2026, 11, 6)), restored.marked);
  });

  test('unmark discards eligibility and a new mark waits until tomorrow',
      () async {
    disk.values['$_mark.shi'] = true;
    final c = container();
    await c.read(katakanaPilotReviewProvider.future);
    final review = c.read(katakanaPilotReviewProvider.notifier);
    await review.setMarked(KatakanaPilotLetter.shi, false);
    await review.completeDailyReview(KatakanaPilotLetter.shi, now);
    expect(disk.values['$_mark.shi'], false);
    expect(disk.values['$_day.shi'], isNull);
    expect(
        (await c.read(katakanaPilotReviewProvider.future)).dueOn(now), isEmpty);
    await review.setMarked(KatakanaPilotLetter.shi, true);
    final current = await c.read(katakanaPilotReviewProvider.future);
    expect(current.marked, {KatakanaPilotLetter.shi});
    expect(current.dueOn(now), isEmpty);
    expect(current.dueOn(DateTime(2026, 11, 5)), {KatakanaPilotLetter.shi});
  });

  test('failed legacy flag write cannot make orphan day metadata a mark',
      () async {
    final c = container();
    await c.read(katakanaPilotReviewProvider.future);
    disk.rejectedKey = '$_mark.shi';
    await expectLater(
      c
          .read(katakanaPilotReviewProvider.notifier)
          .setMarked(KatakanaPilotLetter.shi, true),
      throwsA(isA<ApiException>()),
    );
    expect(disk.values['$_day.shi'], 20261104);
    expect(disk.values['$_mark.shi'], isNull);
    now = DateTime(2026, 11, 5);
    c.invalidate(katakanaPilotReviewProvider);
    final restored = await c.read(katakanaPilotReviewProvider.future);
    expect(restored.marked, isEmpty);
    expect(restored.dueOn(now), isEmpty);

    disk.rejectedKey = null;
    await c
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.shi, true);
    expect(disk.values['$_day.shi'], 20261105);
    expect(
        (await c.read(katakanaPilotReviewProvider.future)).dueOn(now), isEmpty);
  });

  test('failed daily completion remains due until retry succeeds', () async {
    disk.values['$_mark.shi'] = true;
    final c = container();
    await c.read(katakanaPilotReviewProvider.future);
    disk.rejectedKey = '$_day.shi';
    await expectLater(
      c
          .read(katakanaPilotReviewProvider.notifier)
          .completeDailyReview(KatakanaPilotLetter.shi, now),
      throwsA(isA<ApiException>()),
    );
    c.invalidate(katakanaPilotReviewProvider);
    final restored = await c.read(katakanaPilotReviewProvider.future);
    expect(restored.dueOn(now), {KatakanaPilotLetter.shi});

    disk.rejectedKey = null;
    await c
        .read(katakanaPilotReviewProvider.notifier)
        .completeDailyReview(KatakanaPilotLetter.shi, now);
    final reviewed = await c.read(katakanaPilotReviewProvider.future);
    expect(reviewed.dueOn(now), isEmpty);
    expect(reviewed.marked, {KatakanaPilotLetter.shi});
  });

  testWidgets('device day ticks at local midnight and refreshes on resume',
      (tester) async {
    now = DateTime(2026, 12, 31, 23, 59, 59).toUtc();
    final c = container();
    final subscription = c.listen(katakanaPilotLocalDayProvider, (_, __) {});
    try {
      expect(c.read(katakanaPilotLocalDayProvider), DateTime(2026, 12, 31));
      now = DateTime(2027, 1, 1).toUtc();
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(katakanaPilotLocalDayProvider), DateTime(2027, 1, 1));
      now = DateTime(2027, 1, 4, 8).toUtc();
      c.read(katakanaPilotLocalDayProvider.notifier).refresh();
      expect(c.read(katakanaPilotLocalDayProvider), DateTime(2027, 1, 4));
    } finally {
      subscription.close();
      c.dispose();
    }
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
    expect((await c.read(katakanaPilotReviewProvider.future)).marked, isEmpty);

    // Rebuilding must consult persisted values, not the optimistic SDK cache.
    c.invalidate(katakanaPilotReviewProvider);
    expect((await c.read(katakanaPilotReviewProvider.future)).marked, isEmpty);
    disk.rejectWrite = false;
    await c
        .read(katakanaPilotReviewProvider.notifier)
        .setMarked(KatakanaPilotLetter.shi, true);
    expect((await c.read(katakanaPilotReviewProvider.future)).marked,
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
    expect(disk.writes, hasLength(2));
    disk.rejectRead = false;
    c.invalidate(katakanaPilotReviewProvider);
    expect((await c.read(katakanaPilotReviewProvider.future)).marked,
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
    expect((await newOwner).marked, isEmpty);
    expect(disk.writes, hasLength(2));

    activeOwner = _accountA;
    c.read(_ownerProvider.notifier).change(activeOwner);
    expect((await c.read(katakanaPilotReviewProvider.future)).marked,
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
  String? rejectedKey;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getAll':
        if (rejectRead) throw PlatformException(code: 'synthetic-read-failed');
        return Map.of(values);
      case 'setBool':
      case 'setInt':
        final arguments = Map<String, Object>.from(call.arguments as Map);
        final key = arguments['key']! as String;
        writes.add(key);
        if (!started.isCompleted) started.complete();
        await gate?.future;
        if (rejectWrite || key == rejectedKey) return false;
        values[key] = arguments['value']!;
        return true;
      default:
        throw StateError('Unexpected preferences method: ${call.method}');
    }
  }
}
