import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/features/my/data/my_repository.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:harukoto_mobile/features/my/providers/settings_sync_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/smart_preview_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _vocabN5 = (category: 'VOCABULARY', jlptLevel: 'N5');
const _vocabN4 = (category: 'VOCABULARY', jlptLevel: 'N4');
const _grammar = (category: 'GRAMMAR', jlptLevel: 'N5');

void main() {
  test('KST midnight reloads vocabulary without changing grammar previews',
      () async {
    var now = DateTime.utc(2026, 10, 30, 14, 59);
    final repository = _StudyRepository(() async => _preview());
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('account-a'),
      currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
      studyClockProvider.overrideWithValue(() => now),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    container.listen(smartPreviewProvider(_vocabN5), (_, __) {});
    container.listen(smartPreviewProvider(_grammar), (_, __) {});
    await container.read(smartPreviewProvider(_vocabN5).future);
    await container.read(smartPreviewProvider(_grammar).future);
    container.read(studyDateProvider.notifier).refresh();
    await container.read(smartPreviewProvider(_vocabN5).future);
    expect(repository.calls, {'VOCABULARY:N5': 1, 'GRAMMAR:N5': 1});

    now = DateTime.utc(2026, 10, 30, 15);
    container.read(studyDateProvider.notifier).refresh();
    await container.read(smartPreviewProvider(_vocabN5).future);
    await container.read(smartPreviewProvider(_grammar).future);
    expect(repository.calls, {'VOCABULARY:N5': 2, 'GRAMMAR:N5': 1});
  });

  for (final fails in [false, true]) {
    test(
        'goal save ${fails ? 'rollback preserves' : 'confirmation refreshes'} active vocabulary previews once',
        () async {
      SharedPreferences.setMockInitialValues({'user_daily_goal': 20});
      final prefs = await SharedPreferences.getInstance();
      var serverGoal = 20;
      final gate = Completer<void>();
      final settings = _MyRepository(() async {
        await gate.future;
        if (fails) throw StateError('synthetic goal update failed');
        serverGoal = 30;
      });
      final repository =
          _StudyRepository(() async => _preview(goal: serverGoal));
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue('account-a'),
        currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
        studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 30)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        studyRepositoryProvider.overrideWithValue(repository),
        myRepositoryProvider.overrideWithValue(settings),
      ]);
      addTearDown(container.dispose);
      for (final key in [_vocabN5, _vocabN4, _grammar]) {
        container.listen(smartPreviewProvider(key), (_, __) {});
        await container.read(smartPreviewProvider(key).future);
      }
      final initial = container.read(smartPreviewProvider(_vocabN5)).value!;
      final update =
          container.read(settingsSyncServiceProvider).updateDailyGoal(30);
      final expectation =
          fails ? expectLater(update, throwsStateError) : update;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(userPreferencesProvider).dailyGoal, 30);
      expect(repository.calls,
          {'VOCABULARY:N5': 1, 'VOCABULARY:N4': 1, 'GRAMMAR:N5': 1});
      expect(
          container.read(smartPreviewProvider(_vocabN5)).value, same(initial));
      gate.complete();
      await expectation;
      final refreshed =
          await container.read(smartPreviewProvider(_vocabN5).future);
      await container.read(smartPreviewProvider(_vocabN4).future);
      await container.read(smartPreviewProvider(_grammar).future);
      expect(
          container.read(userPreferencesProvider).dailyGoal, fails ? 20 : 30);
      expect(repository.calls, {
        'VOCABULARY:N5': fails ? 1 : 2,
        'VOCABULARY:N4': fails ? 1 : 2,
        'GRAMMAR:N5': 1
      });
      expect(refreshed.dailyGoal, fails ? 20 : 30);
      expect(refreshed.todayCompleted, 8);
      expect(refreshed.sessionDistribution.total, fails ? 12 : 22);
      expect(refreshed.sessionDistribution.newCount, fails ? 12 : 22);
    });
  }

  test('a late response is rejected when the account reader changes first',
      () async {
    var account = 'account-a';
    final pending = Completer<SmartPreviewModel>();
    final repository = _StudyRepository(() => pending.future);
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('account-a'),
      currentAccountReaderProvider.overrideWithValue(() => account),
      studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 30)),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final result = container.read(smartPreviewProvider(_vocabN5).future);
    final rejected = expectLater(result, throwsStateError);
    account = 'account-b';
    pending.complete(_preview());
    await rejected;
    expect(container.read(smartPreviewProvider(_vocabN5)).hasError, isTrue);
    expect(container.read(smartPreviewProvider(_vocabN5)).hasValue, isFalse);
  });

  test('an old account cannot replace the refreshed account preview', () async {
    var account = 'account-a';
    final oldResponse = Completer<SmartPreviewModel>();
    final repository = _StudyRepository(() => account == 'account-a'
        ? oldResponse.future
        : Future.value(_preview(completed: 2)));
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => account),
      currentAccountReaderProvider.overrideWithValue(() => account),
      studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 30)),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    container.listen(smartPreviewProvider(_vocabN5), (_, __) {});
    account = 'account-b';
    container.invalidate(currentAccountIdProvider);
    expect(
        (await container.read(smartPreviewProvider(_vocabN5).future))
            .todayCompleted,
        2);
    oldResponse.complete(_preview(completed: 19));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(smartPreviewProvider(_vocabN5)).value!.todayCompleted,
        2);
    expect(repository.calls, {'VOCABULARY:N5': 2});
  });
}

class _StudyRepository extends Fake implements StudyRepository {
  _StudyRepository(this.response);
  final Future<SmartPreviewModel> Function() response;
  final calls = <String, int>{};
  @override
  Future<SmartPreviewModel> fetchSmartPreview(
      {String category = 'VOCABULARY', String jlptLevel = 'N5'}) {
    calls.update('$category:$jlptLevel', (value) => value + 1,
        ifAbsent: () => 1);
    return response();
  }
}

class _MyRepository extends MyRepository {
  _MyRepository(this.save) : super(Dio());
  final Future<void> Function() save;
  @override
  Future<void> updateProfile(Map<String, dynamic> data) => save();
}

SmartPreviewModel _preview({int goal = 20, int completed = 8}) =>
    SmartPreviewModel.fromJson({
      'poolSize': {'newReady': 100, 'reviewDue': 0, 'retryDue': 0},
      'sessionDistribution': {
        'new': goal - completed,
        'review': 0,
        'retry': 0,
        'total': goal - completed
      },
      'dailyGoal': goal,
      'todayCompleted': completed,
      'overallProgress': {
        'total': 100,
        'studied': 0,
        'mastered': 0,
        'percentage': 0
      },
    });
