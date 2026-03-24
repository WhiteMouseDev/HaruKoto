import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> setShowFurigana(bool value) async {
    state = state.copyWith(showFurigana: value);
    await _repository.persistShowFurigana(value);
  }

  Future<void> seedFromServer(bool showFurigana) async {
    state = await _repository.seedFromServer(showFurigana: showFurigana);
  }
}

final userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, UserPreferences>(
  UserPreferencesNotifier.new,
);
