import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/user_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserPreferencesRepository', () {
    test('loads default showFurigana when cache is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = UserPreferencesRepository(sharedPreferences: prefs);

      final preferences = repository.load();

      expect(preferences.showFurigana, isTrue);
      expect(repository.hasCachedShowFurigana(), isFalse);
    });

    test('persists showFurigana changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = UserPreferencesRepository(sharedPreferences: prefs);

      await repository.persistShowFurigana(false);

      expect(repository.load().showFurigana, isFalse);
      expect(repository.hasCachedShowFurigana(), isTrue);
    });

    test('seeds from server only when no local cache exists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = UserPreferencesRepository(sharedPreferences: prefs);

      final seeded = await repository.seedFromServer(showFurigana: false);
      expect(seeded.showFurigana, isFalse);

      await repository.persistShowFurigana(true);
      final preserved = await repository.seedFromServer(showFurigana: false);
      expect(preserved.showFurigana, isTrue);
    });
  });
}
