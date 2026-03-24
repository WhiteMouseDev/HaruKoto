import 'package:flutter/material.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode {
    switch (this) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  static AppThemePreference fromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return AppThemePreference.system;
      case ThemeMode.light:
        return AppThemePreference.light;
      case ThemeMode.dark:
        return AppThemePreference.dark;
    }
  }

  static AppThemePreference fromStorage(String? raw) {
    switch (raw) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  String toStorage() {
    switch (this) {
      case AppThemePreference.system:
        return 'system';
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
    }
  }
}

class DeviceSettings {
  const DeviceSettings({
    this.themePreference = AppThemePreference.system,
    this.soundEnabled = true,
    this.hapticEnabled = true,
    this.reminderEnabled = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.streakDefenseEnabled = true,
  });

  final AppThemePreference themePreference;
  final bool soundEnabled;
  final bool hapticEnabled;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool streakDefenseEnabled;

  ThemeMode get themeMode => themePreference.themeMode;

  String get reminderTimeLabel {
    final period = reminderHour < 12 ? '오전' : '오후';
    final displayHour = reminderHour == 0
        ? 12
        : reminderHour > 12
            ? reminderHour - 12
            : reminderHour;
    return '$period $displayHour:${reminderMinute.toString().padLeft(2, '0')}';
  }

  DeviceSettings copyWith({
    AppThemePreference? themePreference,
    bool? soundEnabled,
    bool? hapticEnabled,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? streakDefenseEnabled,
  }) {
    return DeviceSettings(
      themePreference: themePreference ?? this.themePreference,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      streakDefenseEnabled: streakDefenseEnabled ?? this.streakDefenseEnabled,
    );
  }
}
