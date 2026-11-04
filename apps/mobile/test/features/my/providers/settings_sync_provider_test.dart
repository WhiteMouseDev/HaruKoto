import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/features/home/data/home_repository.dart';
import 'package:harukoto_mobile/features/home/data/models/category_goals_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/my/data/my_repository.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:harukoto_mobile/features/my/providers/settings_sync_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsSyncService', () {
    test('updates daily goal optimistically and persists on success', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _FakeMyRepository();
      final container = ProviderContainer(
        overrides: [
          currentAccountIdProvider.overrideWithValue('account-a'),
          currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          myRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(settingsSyncServiceProvider).updateDailyGoal(20);

      final preferences = container.read(userPreferencesProvider);
      expect(preferences.dailyGoal, 20);
      expect(repository.lastPayload, {'dailyGoal': 20});
    });

    test('blocks only the same category during a pending goal save', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final pending = Completer<int>();
      final repository = _FakeHomeRepository(pending.future);
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue('account-a'),
        currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        homeRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final settings = container.read(settingsSyncServiceProvider);

      final first =
          settings.updateCategoryDailyGoal(DailyGoalCategory.grammar, 20);
      final firstFailure = expectLater(first, throwsStateError);
      await expectLater(
        settings.updateCategoryDailyGoal(DailyGoalCategory.grammar, 30),
        throwsStateError,
      );
      await settings.updateCategoryDailyGoal(DailyGoalCategory.sentence, 15);
      expect(repository.requests, [
        (DailyGoalCategory.grammar, 20),
        (DailyGoalCategory.sentence, 15),
      ]);

      pending.completeError(StateError('simulated request failure'));
      await firstFailure;
      await settings.updateCategoryDailyGoal(DailyGoalCategory.grammar, 30);
      expect(repository.requests.last, (DailyGoalCategory.grammar, 30));
    });

    test('rolls back call settings when remote update fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _FakeMyRepository(shouldThrow: true);
      final container = ProviderContainer(
        overrides: [
          currentAccountIdProvider.overrideWithValue('account-a'),
          currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          myRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final initial = container.read(userPreferencesProvider).callSettings;
      const updated = CallSettings(
        silenceDurationMs: 1800,
        aiResponseSpeed: 1.25,
        subtitleEnabled: false,
        autoAnalysis: false,
      );

      await expectLater(
        container.read(settingsSyncServiceProvider).updateCallSettings(updated),
        throwsA(isA<StateError>()),
      );

      final current = container.read(userPreferencesProvider).callSettings;
      expect(current.silenceDurationMs, initial.silenceDurationMs);
      expect(current.aiResponseSpeed, initial.aiResponseSpeed);
      expect(current.subtitleEnabled, initial.subtitleEnabled);
      expect(current.autoAnalysis, initial.autoAnalysis);
    });

    test('rolls back daily goal when the update fails', () async {
      SharedPreferences.setMockInitialValues({'user_daily_goal': 20});
      final prefs = await SharedPreferences.getInstance();
      final repository = _FakeMyRepository(shouldThrow: true);
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue('account-a'),
        currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        myRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final initial = container.read(userPreferencesProvider).dailyGoal;
      await expectLater(
        container.read(settingsSyncServiceProvider).updateDailyGoal(30),
        throwsStateError,
      );
      expect(container.read(userPreferencesProvider).dailyGoal, initial);
      expect(repository.lastPayload, {'dailyGoal': 30});
    });
  });
}

class _FakeHomeRepository extends HomeRepository {
  _FakeHomeRepository(this.pending) : super(Dio());

  final Future<int> pending;
  final requests = <(DailyGoalCategory, int)>[];

  @override
  Future<int> updateCategoryDailyGoal(DailyGoalCategory category, int goal) {
    requests.add((category, goal));
    return requests.length == 1 ? pending : Future.value(goal);
  }
}

class _FakeMyRepository extends MyRepository {
  _FakeMyRepository({this.shouldThrow = false}) : super(Dio());

  final bool shouldThrow;
  Map<String, dynamic>? lastPayload;

  @override
  Future<void> updateProfile(Map<String, dynamic> data) async {
    lastPayload = data;
    if (shouldThrow) {
      throw StateError('update failed');
    }
  }
}
