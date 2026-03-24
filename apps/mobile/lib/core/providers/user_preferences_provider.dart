import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/call_settings.dart';
import '../settings/user_preferences.dart';
import '../settings/user_preferences_repository.dart';
import 'shared_preferences_provider.dart';

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>(
  (ref) {
    return UserPreferencesRepository(
      sharedPreferences: ref.watch(sharedPreferencesProvider),
    );
  },
);

class UserPreferencesNotifier extends Notifier<UserPreferences> {
  UserPreferencesRepository get _repository =>
      ref.read(userPreferencesRepositoryProvider);

  @override
  UserPreferences build() {
    return _repository.load();
  }

  Future<void> replace(UserPreferences preferences) async {
    state = preferences;
    await _repository.persist(preferences);
  }

  Future<void> syncFromServer({
    bool? showFurigana,
    bool? showKana,
    int? dailyGoal,
    String? jlptLevel,
    CallSettings? callSettings,
  }) {
    return replace(
      state.copyWith(
        showFurigana: showFurigana,
        showKana: showKana,
        dailyGoal: dailyGoal,
        jlptLevel: jlptLevel,
        callSettings: callSettings,
      ),
    );
  }

  Future<void> setShowFurigana(bool value) {
    return replace(state.copyWith(showFurigana: value));
  }

  Future<void> setShowKana(bool value) {
    return replace(state.copyWith(showKana: value));
  }

  Future<void> setDailyGoal(int value) {
    return replace(state.copyWith(dailyGoal: value));
  }

  Future<void> setJlptLevel(String value) {
    return replace(state.copyWith(jlptLevel: value));
  }

  Future<void> setCallSettings(CallSettings value) {
    return replace(state.copyWith(callSettings: value));
  }
}

final userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, UserPreferences>(
  UserPreferencesNotifier.new,
);
