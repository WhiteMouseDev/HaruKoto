import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_notification_service.dart';

class NotificationSettings {
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool streakDefenseEnabled;

  const NotificationSettings({
    this.reminderEnabled = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.streakDefenseEnabled = true,
  });

  String get reminderTimeLabel {
    final period = reminderHour < 12 ? '오전' : '오후';
    final displayHour = reminderHour == 0
        ? 12
        : reminderHour > 12
            ? reminderHour - 12
            : reminderHour;
    return '$period $displayHour:${reminderMinute.toString().padLeft(2, '0')}';
  }

  NotificationSettings copyWith({
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? streakDefenseEnabled,
  }) {
    return NotificationSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      streakDefenseEnabled: streakDefenseEnabled ?? this.streakDefenseEnabled,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  static const _keyReminderEnabled = 'notification_reminder_enabled';
  static const _keyReminderHour = 'notification_reminder_hour';
  static const _keyReminderMinute = 'notification_reminder_minute';
  static const _keyStreakDefenseEnabled = 'notification_streak_defense_enabled';

  @override
  NotificationSettings build() {
    _loadFromPrefs();
    return const NotificationSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      reminderEnabled: prefs.getBool(_keyReminderEnabled) ?? true,
      reminderHour: prefs.getInt(_keyReminderHour) ?? 9,
      reminderMinute: prefs.getInt(_keyReminderMinute) ?? 0,
      streakDefenseEnabled: prefs.getBool(_keyStreakDefenseEnabled) ?? true,
    );
    await _applySchedule();
  }

  Future<void> setReminderEnabled(bool enabled) async {
    state = state.copyWith(reminderEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminderEnabled, enabled);
    await _applySchedule();
  }

  Future<void> setReminderTime(int hour, int minute) async {
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, hour);
    await prefs.setInt(_keyReminderMinute, minute);
    await _applySchedule();
  }

  Future<void> setStreakDefenseEnabled(bool enabled) async {
    state = state.copyWith(streakDefenseEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStreakDefenseEnabled, enabled);
    await _applySchedule();
  }

  Future<void> _applySchedule() async {
    if (state.reminderEnabled) {
      await LocalNotificationService.scheduleDailyReminder(
        hour: state.reminderHour,
        minute: state.reminderMinute,
      );
    } else {
      await LocalNotificationService.cancelDailyReminder();
    }

    if (state.streakDefenseEnabled) {
      await LocalNotificationService.scheduleStreakDefense();
    } else {
      await LocalNotificationService.cancelStreakDefense();
    }
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);
