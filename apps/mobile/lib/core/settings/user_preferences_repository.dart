import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'call_settings.dart';
import 'user_preferences.dart';

class UserPreferencesRepository {
  UserPreferencesRepository({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  static const _keyShowFurigana = 'quiz_show_furigana';
  static const _keyShowKana = 'user_show_kana';
  static const _keyDailyGoal = 'user_daily_goal';
  static const _keyJlptLevel = 'user_jlpt_level';
  static const _keyCallSettings = 'user_call_settings';

  final SharedPreferences _sharedPreferences;

  UserPreferences load({String? accountId}) {
    final scopedGoal = accountId == null
        ? null
        : _sharedPreferences.getInt(_dailyGoalKey(accountId));
    final validScopedGoal =
        scopedGoal != null && scopedGoal >= 5 && scopedGoal <= 50;
    return UserPreferences(
      showFurigana: _sharedPreferences.getBool(_keyShowFurigana) ?? true,
      showKana: _sharedPreferences.getBool(_keyShowKana) ?? false,
      // The old shared key has no owner. Keep it for compatibility but never
      // infer that it belongs to the account which happens to log in next.
      dailyGoal: accountId == null
          ? _sharedPreferences.getInt(_keyDailyGoal) ?? 10
          : validScopedGoal
              ? scopedGoal
              : 10,
      dailyGoalConfirmed: validScopedGoal,
      jlptLevel: _sharedPreferences.getString(_keyJlptLevel) ?? 'N5',
      callSettings: _loadCallSettings(),
    );
  }

  String _dailyGoalKey(String accountId) => 'user_daily_goal_v2:$accountId';

  Future<void> persist(UserPreferences preferences, {String? accountId}) async {
    await _sharedPreferences.setBool(
      _keyShowFurigana,
      preferences.showFurigana,
    );
    await _sharedPreferences.setBool(
      _keyShowKana,
      preferences.showKana,
    );
    if (accountId == null) {
      await _sharedPreferences.setInt(_keyDailyGoal, preferences.dailyGoal);
    } else if (preferences.dailyGoalConfirmed &&
        preferences.dailyGoal >= 5 &&
        preferences.dailyGoal <= 50) {
      await _sharedPreferences.setInt(
          _dailyGoalKey(accountId), preferences.dailyGoal);
    }
    await _sharedPreferences.setString(
      _keyJlptLevel,
      preferences.jlptLevel,
    );
    await _sharedPreferences.setString(
      _keyCallSettings,
      jsonEncode(preferences.callSettings.toJson()),
    );
  }

  CallSettings _loadCallSettings() {
    final raw = _sharedPreferences.getString(_keyCallSettings);
    if (raw == null || raw.isEmpty) {
      return const CallSettings();
    }

    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        return CallSettings.fromJson(data);
      }
      if (data is Map) {
        return CallSettings.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Ignore invalid cached JSON and fall back to defaults.
    }

    return const CallSettings();
  }
}
