import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/user_preferences.dart';
import 'package:harukoto_mobile/core/settings/user_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy unowned goal is preserved but never claimed by an account',
      () async {
    SharedPreferences.setMockInitialValues({'user_daily_goal': 20});
    final prefs = await SharedPreferences.getInstance();
    final repository = UserPreferencesRepository(sharedPreferences: prefs);
    expect(repository.load(accountId: 'a').dailyGoalConfirmed, isFalse);
    expect(repository.load(accountId: 'a').dailyGoal, 10);
    expect(repository.load(accountId: 'b').dailyGoalConfirmed, isFalse);
    expect(prefs.getInt('user_daily_goal'), 20);
  });

  test('only a confirmed goal is cached and survives restart for its owner',
      () async {
    SharedPreferences.setMockInitialValues({'user_daily_goal': 20});
    final prefs = await SharedPreferences.getInstance();
    final repository = UserPreferencesRepository(sharedPreferences: prefs);
    await repository.persist(const UserPreferences(dailyGoal: 30),
        accountId: 'a');
    expect(repository.load(accountId: 'a').dailyGoalConfirmed, isFalse);
    await repository.persist(
        const UserPreferences(dailyGoal: 30, dailyGoalConfirmed: true),
        accountId: 'a');
    final restored = UserPreferencesRepository(sharedPreferences: prefs)
        .load(accountId: 'a');
    expect(restored.dailyGoal, 30);
    expect(restored.dailyGoalConfirmed, isTrue);
    expect(repository.load(accountId: 'b').dailyGoalConfirmed, isFalse);
    expect(prefs.getInt('user_daily_goal'), 20);
  });

  test('invalid scoped cache cannot produce a known percentage', () async {
    SharedPreferences.setMockInitialValues({'user_daily_goal_v2:a': 0});
    final prefs = await SharedPreferences.getInstance();
    final restored = UserPreferencesRepository(sharedPreferences: prefs)
        .load(accountId: 'a');
    expect(restored.dailyGoalConfirmed, isFalse);
    expect(restored.dailyGoal, 10);
  });
}
