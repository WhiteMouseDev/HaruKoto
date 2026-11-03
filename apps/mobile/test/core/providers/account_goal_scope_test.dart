import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/features/home/data/home_repository.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/my/data/my_repository.dart';
import 'package:harukoto_mobile/features/my/data/models/profile_detail_model.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:harukoto_mobile/features/my/providers/settings_sync_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final detail in [false, true]) {
    test('${detail ? 'My' : 'Home'} discards A late profile after B login',
        () async {
      final harness = await _Harness.create();
      addTearDown(harness.container.dispose);
      final old = Completer<int>();
      harness.fetchGoal =
          () => harness.owner == 'a' ? old.future : Future.value(30);
      if (detail) {
        harness.container.listen(profileDetailProvider, (_, __) {});
      } else {
        harness.container.listen(profileProvider, (_, __) {});
      }
      await Future<void>.delayed(Duration.zero);
      harness.switchTo('b');
      if (detail) {
        await harness.container.read(profileDetailProvider.future);
      } else {
        await harness.container.read(profileProvider.future);
      }
      old.complete(20);
      await Future<void>.delayed(Duration.zero);
      expect(harness.container.read(userPreferencesProvider).dailyGoal, 30);
      expect(harness.prefs.getInt('user_daily_goal_v2:b'), 30);
      expect(harness.prefs.getInt('user_daily_goal_v2:a'), isNull);
    });
  }

  test('a missing profile goal never confirms a fallback target', () async {
    final harness = await _Harness.create({'user_daily_goal': 20});
    addTearDown(harness.container.dispose);
    harness.profile = (_) => UserProfileModel.fromJson({
          'profile': {'id': 'a'}
        });
    await harness.container.read(profileProvider.future);
    expect(harness.container.read(userPreferencesProvider).dailyGoalConfirmed,
        isFalse);
    expect(harness.prefs.getInt('user_daily_goal_v2:a'), isNull);
    expect(harness.prefs.getInt('user_daily_goal'), 20);
  });

  test('profile carrying a different owner cannot confirm the goal', () async {
    final harness = await _Harness.create();
    addTearDown(harness.container.dispose);
    harness.profile = (_) => UserProfileModel.fromJson({
          'profile': {'id': 'b', 'dailyGoal': 30}
        });
    await expectLater(
        harness.container.read(profileProvider.future), throwsA(anything));
    expect(harness.container.read(userPreferencesProvider).dailyGoalConfirmed,
        isFalse);
    expect(harness.prefs.getInt('user_daily_goal_v2:a'), isNull);
  });

  test('old profile cannot overwrite goal saved while its request was pending',
      () async {
    final harness = await _Harness.create({'user_daily_goal_v2:a': 20});
    addTearDown(harness.container.dispose);
    final oldProfile = Completer<int>();
    var calls = 0;
    harness.fetchGoal =
        () => calls++ == 0 ? oldProfile.future : Future.value(30);
    harness.container.listen(profileProvider, (_, __) {});
    final update = Completer<void>();
    harness.update = () => update.future;
    final save =
        harness.container.read(settingsSyncServiceProvider).updateDailyGoal(30);
    await Future<void>.delayed(Duration.zero);
    expect(harness.container.read(userPreferencesProvider).dailyGoalConfirmed,
        isFalse);
    expect(harness.prefs.getInt('user_daily_goal_v2:a'), 20);
    oldProfile.complete(20);
    await Future<void>.delayed(Duration.zero);
    expect(harness.container.read(userPreferencesProvider).dailyGoal, 30);
    update.complete();
    await save;
    await harness.container.read(profileProvider.future);
    expect(harness.container.read(userPreferencesProvider).dailyGoal, 30);
    expect(harness.container.read(userPreferencesProvider).dailyGoalConfirmed,
        isTrue);
    expect(harness.prefs.getInt('user_daily_goal_v2:a'), 30);
  });

  test('failed goal save restores confirmed goal and does not change its cache',
      () async {
    final harness = await _Harness.create({'user_daily_goal_v2:a': 20});
    addTearDown(harness.container.dispose);
    harness.update = () => Future.error(StateError('Save unavailable'));
    await expectLater(
        harness.container.read(settingsSyncServiceProvider).updateDailyGoal(30),
        throwsStateError);
    expect(harness.container.read(userPreferencesProvider).dailyGoal, 20);
    expect(harness.container.read(userPreferencesProvider).dailyGoalConfirmed,
        isTrue);
    expect(harness.prefs.getInt('user_daily_goal_v2:a'), 20);
  });

  test('goal save response from A never changes B current state or cache',
      () async {
    final harness = await _Harness.create(
        {'user_daily_goal_v2:a': 20, 'user_daily_goal_v2:b': 40});
    addTearDown(harness.container.dispose);
    final update = Completer<void>();
    harness.update = () => update.future;
    final save =
        harness.container.read(settingsSyncServiceProvider).updateDailyGoal(30);
    await Future<void>.delayed(Duration.zero);
    harness.switchTo('b');
    expect(harness.container.read(userPreferencesProvider).dailyGoal, 40);
    update.complete();
    await save;
    expect(harness.container.read(userPreferencesProvider).dailyGoal, 40);
    expect(harness.prefs.getInt('user_daily_goal_v2:b'), 40);
    expect(harness.prefs.getInt('user_daily_goal_v2:a'), 20);
  });

  test('another setting rollback cannot restore an older goal snapshot',
      () async {
    final harness = await _Harness.create({'user_daily_goal_v2:a': 20});
    addTearDown(harness.container.dispose);
    final oldSave = Completer<void>();
    var calls = 0;
    harness.update = () => calls++ == 0 ? oldSave.future : Future.value();
    final service = harness.container.read(settingsSyncServiceProvider);
    final oldSetting = service.updateShowKana(true);
    final rejected = expectLater(oldSetting, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await service.updateDailyGoal(30);
    oldSave.completeError(StateError('Other setting failed'));
    await rejected;
    expect(harness.container.read(userPreferencesProvider).dailyGoal, 30);
    expect(harness.container.read(userPreferencesProvider).dailyGoalConfirmed,
        isTrue);
    expect(harness.prefs.getInt('user_daily_goal_v2:a'), 30);
  });

  test('a second pending goal update cannot clobber the first update',
      () async {
    final harness = await _Harness.create({'user_daily_goal_v2:a': 20});
    addTearDown(harness.container.dispose);
    final update = Completer<void>();
    harness.update = () => update.future;
    final service = harness.container.read(settingsSyncServiceProvider);
    final first = service.updateDailyGoal(30);
    await Future<void>.delayed(Duration.zero);
    await expectLater(service.updateDailyGoal(40), throwsStateError);
    update.complete();
    await first;
    expect(harness.container.read(userPreferencesProvider).dailyGoal, 30);
    expect(harness.prefs.getInt('user_daily_goal_v2:a'), 30);
  });
}

class _Harness {
  late ProviderContainer container;
  late SharedPreferences prefs;
  String owner = 'a';
  Future<int> Function() fetchGoal = () async => 20;
  Future<void> Function() update = () async {};
  UserProfileModel Function(int) profile = (goal) => UserProfileModel(
      nickname: 'Test', dailyGoal: goal, showKana: false, jlptLevel: 'N5');

  static Future<_Harness> create(
      [Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final h = _Harness();
    h.prefs = await SharedPreferences.getInstance();
    h.container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => h.owner),
      currentAccountReaderProvider.overrideWithValue(() => h.owner),
      sharedPreferencesProvider.overrideWithValue(h.prefs),
      homeRepositoryProvider.overrideWithValue(
          _Home(() => h.fetchGoal(), (goal) => h.profile(goal))),
      myRepositoryProvider
          .overrideWithValue(_My(() => h.fetchGoal(), () => h.update())),
    ]);
    return h;
  }

  void switchTo(String next) {
    owner = next;
    container.invalidate(currentAccountIdProvider);
  }
}

class _Home extends HomeRepository {
  _Home(this.goal, this.profile) : super(Dio());
  final Future<int> Function() goal;
  final UserProfileModel Function(int) profile;
  @override
  Future<UserProfileModel> fetchProfile() async => profile(await goal());
}

class _My extends MyRepository {
  _My(this.goal, this.update) : super(Dio());
  final Future<int> Function() goal;
  final Future<void> Function() update;
  @override
  Future<ProfileDetailModel> fetchProfileDetail() async =>
      ProfileDetailModel.fromJson({
        'profile': {'dailyGoal': await goal()}
      });
  @override
  Future<void> updateProfile(Map<String, dynamic> data) => update();
}
