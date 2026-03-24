import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/device_settings.dart';
import '../settings/device_settings_repository.dart';
import 'shared_preferences_provider.dart';

final deviceSettingsRepositoryProvider = Provider<DeviceSettingsRepository>(
  (ref) {
    return DeviceSettingsRepository(
      sharedPreferences: ref.watch(sharedPreferencesProvider),
    );
  },
);

class DeviceSettingsNotifier extends Notifier<DeviceSettings> {
  DeviceSettingsRepository get _repository =>
      ref.read(deviceSettingsRepositoryProvider);

  @override
  DeviceSettings build() {
    return _repository.load();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = state.copyWith(
      themePreference: AppThemePreference.fromThemeMode(themeMode),
    );
    await _repository.persistThemeMode(themeMode);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    await _repository.persistSoundEnabled(enabled);
  }

  Future<void> setHapticEnabled(bool enabled) async {
    state = state.copyWith(hapticEnabled: enabled);
    await _repository.persistHapticEnabled(enabled);
  }

  Future<void> setReminderEnabled(bool enabled) async {
    state = state.copyWith(reminderEnabled: enabled);
    await _repository.persistReminderEnabled(enabled);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    state = state.copyWith(
      reminderHour: hour,
      reminderMinute: minute,
    );
    await _repository.persistReminderTime(hour, minute);
  }

  Future<void> setStreakDefenseEnabled(bool enabled) async {
    state = state.copyWith(streakDefenseEnabled: enabled);
    await _repository.persistStreakDefenseEnabled(enabled);
  }
}

final deviceSettingsProvider =
    NotifierProvider<DeviceSettingsNotifier, DeviceSettings>(
  DeviceSettingsNotifier.new,
);
