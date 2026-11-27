import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/device_settings_provider.dart';
import 'package:harukoto_mobile/core/settings/device_settings.dart';
import 'package:harukoto_mobile/core/settings/device_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final firstFails in [false, true]) {
    test('theme writes remain ordered when the first write fails: $firstFails',
        () async {
      SharedPreferences.setMockInitialValues({'device_theme_mode': 'light'});
      final prefs = await SharedPreferences.getInstance();
      final repository = _StagedThemeRepository(sharedPreferences: prefs);
      final container = ProviderContainer(
        overrides: [
          deviceSettingsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(deviceSettingsProvider.notifier);
      final firstRequest = notifier.setThemeMode(ThemeMode.dark);
      final firstResult = firstFails
          ? expectLater(firstRequest, throwsStateError)
          : firstRequest;
      // If the first write succeeds, the second choice matches the stale state
      // seen during the write but must restore it after dark was committed.
      final latestMode = firstFails ? ThemeMode.system : ThemeMode.light;
      final latestRequest = notifier.setThemeMode(latestMode);

      await repository.firstWriteStarted.future;
      expect(repository.writes, [ThemeMode.dark]);
      expect(container.read(deviceSettingsProvider).themeMode, ThemeMode.light);
      expect(prefs.getString('device_theme_mode'), 'light');
      if (firstFails) {
        repository.firstWrite
            .completeError(StateError('Setting was not saved'));
      } else {
        repository.firstWrite.complete();
      }
      await firstResult;
      await latestRequest;

      expect(repository.writes, [ThemeMode.dark, latestMode]);
      expect(container.read(deviceSettingsProvider).themeMode, latestMode);
      expect(prefs.getString('device_theme_mode'), latestMode.name);
    });
  }

  group('DeviceSettingsRepository', () {
    test(
      'defaults to light theme when no theme preference is stored',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = DeviceSettingsRepository(
          sharedPreferences: prefs,
          notificationScheduler: _FakeNotificationScheduler(),
          soundDriver: _FakeToggleSettingDriver(),
          hapticDriver: _FakeToggleSettingDriver(),
        );

        final settings = repository.load();

        expect(settings.themeMode, ThemeMode.light);
        expect(const DeviceSettings().themeMode, ThemeMode.light);
      },
    );

    test('loads persisted settings synchronously', () async {
      SharedPreferences.setMockInitialValues({
        'device_theme_mode': 'dark',
        'sound_enabled': false,
        'haptic_enabled': false,
        'notification_reminder_enabled': false,
        'notification_reminder_hour': 7,
        'notification_reminder_minute': 30,
        'notification_streak_defense_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = DeviceSettingsRepository(
        sharedPreferences: prefs,
        notificationScheduler: _FakeNotificationScheduler(),
        soundDriver: _FakeToggleSettingDriver(),
        hapticDriver: _FakeToggleSettingDriver(),
      );

      final settings = repository.load();

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.soundEnabled, isFalse);
      expect(settings.hapticEnabled, isFalse);
      expect(settings.reminderEnabled, isFalse);
      expect(settings.reminderHour, equals(7));
      expect(settings.reminderMinute, equals(30));
      expect(settings.streakDefenseEnabled, isFalse);
    });

    test('preserves explicit system theme preference', () async {
      SharedPreferences.setMockInitialValues({'device_theme_mode': 'system'});
      final prefs = await SharedPreferences.getInstance();
      final repository = DeviceSettingsRepository(
        sharedPreferences: prefs,
        notificationScheduler: _FakeNotificationScheduler(),
        soundDriver: _FakeToggleSettingDriver(),
        hapticDriver: _FakeToggleSettingDriver(),
      );

      final settings = repository.load();

      expect(settings.themeMode, ThemeMode.system);
    });

    test('persists theme and runtime toggles', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final soundDriver = _FakeToggleSettingDriver();
      final hapticDriver = _FakeToggleSettingDriver();
      final repository = DeviceSettingsRepository(
        sharedPreferences: prefs,
        notificationScheduler: _FakeNotificationScheduler(),
        soundDriver: soundDriver,
        hapticDriver: hapticDriver,
      );

      await repository.persistThemeMode(ThemeMode.light);
      await repository.persistSoundEnabled(false);
      await repository.persistHapticEnabled(false);

      expect(prefs.getString('device_theme_mode'), equals('light'));
      expect(soundDriver.lastEnabled, isFalse);
      expect(hapticDriver.lastEnabled, isFalse);
    });

    test('applies reminder and streak scheduling from device settings',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final scheduler = _FakeNotificationScheduler();
      final repository = DeviceSettingsRepository(
        sharedPreferences: prefs,
        notificationScheduler: scheduler,
        soundDriver: _FakeToggleSettingDriver(),
        hapticDriver: _FakeToggleSettingDriver(),
      );

      await repository.applyNotificationSettings(
        const DeviceSettings(
          reminderEnabled: true,
          reminderHour: 8,
          reminderMinute: 15,
          streakDefenseEnabled: false,
        ),
      );

      expect(scheduler.lastReminderHour, equals(8));
      expect(scheduler.lastReminderMinute, equals(15));
      expect(scheduler.streakCancelled, isTrue);
    });
  });
}

class _StagedThemeRepository extends DeviceSettingsRepository {
  _StagedThemeRepository({required super.sharedPreferences})
      : super(
          notificationScheduler: _FakeNotificationScheduler(),
          soundDriver: _FakeToggleSettingDriver(),
          hapticDriver: _FakeToggleSettingDriver(),
        );

  final firstWriteStarted = Completer<void>();
  final firstWrite = Completer<void>();
  final writes = <ThemeMode>[];

  @override
  Future<void> persistThemeMode(ThemeMode themeMode) async {
    writes.add(themeMode);
    if (writes.length == 1) {
      firstWriteStarted.complete();
      await firstWrite.future;
    }
    await super.persistThemeMode(themeMode);
  }
}

class _FakeNotificationScheduler implements NotificationScheduler {
  int? lastReminderHour;
  int? lastReminderMinute;
  bool reminderCancelled = false;
  bool streakScheduled = false;
  bool streakCancelled = false;

  @override
  Future<void> cancelDailyReminder() async {
    reminderCancelled = true;
  }

  @override
  Future<void> cancelStreakDefense() async {
    streakCancelled = true;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    lastReminderHour = hour;
    lastReminderMinute = minute;
  }

  @override
  Future<void> scheduleStreakDefense() async {
    streakScheduled = true;
  }
}

class _FakeToggleSettingDriver implements ToggleSettingDriver {
  bool? lastEnabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    lastEnabled = enabled;
  }
}
