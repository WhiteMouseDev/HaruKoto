import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/core/settings/user_preferences.dart';
import 'package:harukoto_mobile/core/settings/user_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserPreferencesRepository', () {
    test('loads defaults when cache is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = UserPreferencesRepository(sharedPreferences: prefs);

      final preferences = repository.load();

      expect(preferences.showFurigana, isTrue);
      expect(preferences.showKana, isFalse);
      expect(preferences.dailyGoal, 10);
      expect(preferences.jlptLevel, 'N5');
      expect(preferences.callSettings.silenceDurationMs, 1200);
      expect(preferences.callSettings.aiResponseSpeed, 1.0);
      expect(preferences.callSettings.subtitleEnabled, isTrue);
      expect(preferences.callSettings.autoAnalysis, isTrue);
    });

    test('persists all user preference fields', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = UserPreferencesRepository(sharedPreferences: prefs);

      await repository.persist(
        const UserPreferences(
          showFurigana: false,
          showKana: true,
          dailyGoal: 20,
          jlptLevel: 'N3',
          callSettings: CallSettings(
            silenceDurationMs: 1800,
            aiResponseSpeed: 1.25,
            subtitleEnabled: false,
            autoAnalysis: false,
          ),
        ),
      );

      final saved = repository.load();
      expect(saved.showFurigana, isFalse);
      expect(saved.showKana, isTrue);
      expect(saved.dailyGoal, 20);
      expect(saved.jlptLevel, 'N3');
      expect(saved.callSettings.silenceDurationMs, 1800);
      expect(saved.callSettings.aiResponseSpeed, 1.25);
      expect(saved.callSettings.subtitleEnabled, isFalse);
      expect(saved.callSettings.autoAnalysis, isFalse);
    });

    test('falls back to default call settings for invalid cached JSON',
        () async {
      SharedPreferences.setMockInitialValues({
        'user_call_settings': 'not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = UserPreferencesRepository(sharedPreferences: prefs);

      final preferences = repository.load();

      expect(preferences.callSettings.silenceDurationMs, 1200);
      expect(preferences.callSettings.aiResponseSpeed, 1.0);
      expect(preferences.callSettings.subtitleEnabled, isTrue);
      expect(preferences.callSettings.autoAnalysis, isTrue);
    });
  });
}
