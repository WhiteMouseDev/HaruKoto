import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/my/data/models/profile_detail_model.dart';
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

  UserPreferences load() {
    return UserPreferences(
      showFurigana: _sharedPreferences.getBool(_keyShowFurigana) ?? true,
      showKana: _sharedPreferences.getBool(_keyShowKana) ?? false,
      dailyGoal: _sharedPreferences.getInt(_keyDailyGoal) ?? 10,
      jlptLevel: _sharedPreferences.getString(_keyJlptLevel) ?? 'N5',
      callSettings: _loadCallSettings(),
    );
  }

  Future<void> persist(UserPreferences preferences) async {
    await _sharedPreferences.setBool(
      _keyShowFurigana,
      preferences.showFurigana,
    );
    await _sharedPreferences.setBool(
      _keyShowKana,
      preferences.showKana,
    );
    await _sharedPreferences.setInt(
      _keyDailyGoal,
      preferences.dailyGoal,
    );
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
