import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
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

    test('rolls back call settings when remote update fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _FakeMyRepository(shouldThrow: true);
      final container = ProviderContainer(
        overrides: [
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
  });
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
