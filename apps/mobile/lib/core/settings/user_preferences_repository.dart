import 'package:shared_preferences/shared_preferences.dart';

import 'user_preferences.dart';

class UserPreferencesRepository {
  UserPreferencesRepository({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  static const _keyShowFurigana = 'quiz_show_furigana';

  final SharedPreferences _sharedPreferences;

  UserPreferences load() {
    return UserPreferences(
      showFurigana: _sharedPreferences.getBool(_keyShowFurigana) ?? true,
    );
  }

  bool hasCachedShowFurigana() {
    return _sharedPreferences.containsKey(_keyShowFurigana);
  }

  Future<void> persistShowFurigana(bool value) {
    return _sharedPreferences.setBool(_keyShowFurigana, value);
  }

  Future<UserPreferences> seedFromServer({
    required bool showFurigana,
  }) async {
    if (hasCachedShowFurigana()) {
      return load();
    }

    await persistShowFurigana(showFurigana);
    return UserPreferences(showFurigana: showFurigana);
  }
}
