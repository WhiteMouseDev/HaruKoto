import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/haptic_service.dart';
import '../services/local_notification_service.dart';
import '../services/sound_service.dart';
import 'device_settings.dart';

abstract class NotificationScheduler {
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  });

  Future<void> cancelDailyReminder();

  Future<void> scheduleStreakDefense();

  Future<void> cancelStreakDefense();
}

class LocalNotificationScheduler implements NotificationScheduler {
  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) {
    return LocalNotificationService.scheduleDailyReminder(
      hour: hour,
      minute: minute,
    );
  }

  @override
  Future<void> cancelDailyReminder() {
    return LocalNotificationService.cancelDailyReminder();
  }

  @override
  Future<void> scheduleStreakDefense() {
    return LocalNotificationService.scheduleStreakDefense();
  }

  @override
  Future<void> cancelStreakDefense() {
    return LocalNotificationService.cancelStreakDefense();
  }
}

abstract class ToggleSettingDriver {
  Future<void> setEnabled(bool enabled);
}

class SoundSettingDriver implements ToggleSettingDriver {
  SoundSettingDriver({SoundService? soundService})
      : _soundService = soundService ?? SoundService();

  final SoundService _soundService;

  @override
  Future<void> setEnabled(bool enabled) {
    return _soundService.setEnabled(enabled);
  }
}

class HapticSettingDriver implements ToggleSettingDriver {
  HapticSettingDriver({HapticService? hapticService})
      : _hapticService = hapticService ?? HapticService();

  final HapticService _hapticService;

  @override
  Future<void> setEnabled(bool enabled) {
    return _hapticService.setEnabled(enabled);
  }
}

class DeviceSettingsRepository {
  DeviceSettingsRepository({
    required SharedPreferences sharedPreferences,
    NotificationScheduler? notificationScheduler,
    ToggleSettingDriver? soundDriver,
    ToggleSettingDriver? hapticDriver,
  })  : _sharedPreferences = sharedPreferences,
        _notificationScheduler =
            notificationScheduler ?? LocalNotificationScheduler(),
        _soundDriver = soundDriver ?? SoundSettingDriver(),
        _hapticDriver = hapticDriver ?? HapticSettingDriver();

  static const _keyThemeMode = 'device_theme_mode';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyHapticEnabled = 'haptic_enabled';
  static const _keyReminderEnabled = 'notification_reminder_enabled';
  static const _keyReminderHour = 'notification_reminder_hour';
  static const _keyReminderMinute = 'notification_reminder_minute';
  static const _keyStreakDefenseEnabled = 'notification_streak_defense_enabled';

  final SharedPreferences _sharedPreferences;
  final NotificationScheduler _notificationScheduler;
  final ToggleSettingDriver _soundDriver;
  final ToggleSettingDriver _hapticDriver;

  DeviceSettings load() {
    return DeviceSettings(
      themePreference: AppThemePreference.fromStorage(
        _sharedPreferences.getString(_keyThemeMode),
      ),
      soundEnabled: _sharedPreferences.getBool(_keySoundEnabled) ?? true,
      hapticEnabled: _sharedPreferences.getBool(_keyHapticEnabled) ?? true,
      reminderEnabled: _sharedPreferences.getBool(_keyReminderEnabled) ?? true,
      reminderHour: _sharedPreferences.getInt(_keyReminderHour) ?? 9,
      reminderMinute: _sharedPreferences.getInt(_keyReminderMinute) ?? 0,
      streakDefenseEnabled:
          _sharedPreferences.getBool(_keyStreakDefenseEnabled) ?? true,
    );
  }

  Future<void> persistThemeMode(ThemeMode themeMode) {
    return _sharedPreferences.setString(
      _keyThemeMode,
      AppThemePreference.fromThemeMode(themeMode).toStorage(),
    );
  }

  Future<void> persistSoundEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_keySoundEnabled, enabled);
    await _soundDriver.setEnabled(enabled);
  }

  Future<void> persistHapticEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_keyHapticEnabled, enabled);
    await _hapticDriver.setEnabled(enabled);
  }

  Future<void> persistReminderEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_keyReminderEnabled, enabled);
    await applyNotificationSettings(
      load().copyWith(reminderEnabled: enabled),
    );
  }

  Future<void> persistReminderTime(int hour, int minute) async {
    await _sharedPreferences.setInt(_keyReminderHour, hour);
    await _sharedPreferences.setInt(_keyReminderMinute, minute);
    await applyNotificationSettings(
      load().copyWith(reminderHour: hour, reminderMinute: minute),
    );
  }

  Future<void> persistStreakDefenseEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_keyStreakDefenseEnabled, enabled);
    await applyNotificationSettings(
      load().copyWith(streakDefenseEnabled: enabled),
    );
  }

  Future<void> hydrateRuntime(DeviceSettings settings) async {
    await _soundDriver.setEnabled(settings.soundEnabled);
    await _hapticDriver.setEnabled(settings.hapticEnabled);
    await applyNotificationSettings(settings);
  }

  Future<void> applyNotificationSettings(DeviceSettings settings) async {
    if (settings.reminderEnabled) {
      await _notificationScheduler.scheduleDailyReminder(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      );
    } else {
      await _notificationScheduler.cancelDailyReminder();
    }

    if (settings.streakDefenseEnabled) {
      await _notificationScheduler.scheduleStreakDefense();
    } else {
      await _notificationScheduler.cancelStreakDefense();
    }
  }
}
