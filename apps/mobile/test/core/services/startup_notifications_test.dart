import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/services/startup_notifications.dart';
import 'package:harukoto_mobile/core/settings/device_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('notification initialization failure allows startup hydration to finish',
      () async {
    final notifications = StartupNotifications();
    final scheduler = _Scheduler();
    final sound = _ToggleDriver();
    final haptic = _ToggleDriver();
    final repository = DeviceSettingsRepository(
      sharedPreferences: preferences,
      notificationScheduler: scheduler,
      soundDriver: sound,
      hapticDriver: haptic,
    );

    await notifications.initialize(() async {
      throw PlatformException(
        code: 'error',
        message: 'private-message-value',
        details: {'token': 'private-details-value'},
      );
    });
    await _hydrate(repository, notifications);

    expect(sound.enabled, isTrue);
    expect(haptic.enabled, isTrue);
    expect(scheduler.operations, isEmpty);
    expect(repository.load().reminderEnabled, isTrue);
    expect(repository.load().streakDefenseEnabled, isTrue);
    expect(notifications.failures.single.stage,
        StartupNotificationStage.initialize);
    final diagnostic = notifications.failures.single.toString();
    expect(diagnostic, contains('PlatformException'));
    expect(diagnostic, isNot(contains('private-message-value')));
    expect(diagnostic, isNot(contains('private-details-value')));
    expect(diagnostic, isNot(contains('token')));
  });

  test('TypeToken scheduling exception does not prevent startup continuation',
      () async {
    final notifications = StartupNotifications();
    final scheduler = _Scheduler(failScheduling: true);
    final repository = DeviceSettingsRepository(
      sharedPreferences: preferences,
      notificationScheduler: scheduler,
      soundDriver: _ToggleDriver(),
      hapticDriver: _ToggleDriver(),
    );
    await notifications.initialize(() async {});

    await _hydrate(repository, notifications);

    expect(scheduler.operations, ['reminder']);
    expect(
        notifications.failures.single.stage, StartupNotificationStage.schedule);
    expect(notifications.failures.single.exceptionType, 'PlatformException');
    expect(repository.load().reminderEnabled, isTrue);
    expect(repository.load().streakDefenseEnabled, isTrue);
    expect(preferences.getKeys(), isEmpty);
  });

  test('successful startup applies both saved notification schedules',
      () async {
    await preferences.setInt('notification_reminder_hour', 8);
    await preferences.setInt('notification_reminder_minute', 15);
    final notifications = StartupNotifications();
    final scheduler = _Scheduler();
    final repository = DeviceSettingsRepository(
      sharedPreferences: preferences,
      notificationScheduler: scheduler,
      soundDriver: _ToggleDriver(),
      hapticDriver: _ToggleDriver(),
    );
    await notifications.initialize(() async {});

    await _hydrate(repository, notifications);

    expect(scheduler.operations, ['reminder', 'streak']);
    expect(scheduler.hour, 8);
    expect(scheduler.minute, 15);
    expect(notifications.failures, isEmpty);
  });

  test('ordinary settings changes still propagate scheduling failures',
      () async {
    final repository = DeviceSettingsRepository(
      sharedPreferences: preferences,
      notificationScheduler: _Scheduler(failScheduling: true),
      soundDriver: _ToggleDriver(),
      hapticDriver: _ToggleDriver(),
    );

    await expectLater(repository.persistReminderEnabled(true),
        throwsA(isA<PlatformException>()));
    await expectLater(repository.hydrateRuntime(repository.load()),
        throwsA(isA<PlatformException>()));
  });

  test('startup notification boundary does not catch other device failures',
      () async {
    final notifications = StartupNotifications();
    final repository = DeviceSettingsRepository(
      sharedPreferences: preferences,
      notificationScheduler: _Scheduler(),
      soundDriver: _ToggleDriver(fail: true),
      hapticDriver: _ToggleDriver(),
    );
    await notifications.initialize(() async {});

    await expectLater(
        _hydrate(repository, notifications), throwsA(isA<PlatformException>()));
    expect(notifications.failures, isEmpty);
  });

  test('programming errors are not hidden as optional plugin exceptions',
      () async {
    final notifications = StartupNotifications();

    await expectLater(
      notifications.initialize(() async => throw StateError('invalid state')),
      throwsStateError,
    );
    expect(notifications.failures, isEmpty);
  });
}

Future<void> _hydrate(
  DeviceSettingsRepository repository,
  StartupNotifications notifications,
) {
  return repository.hydrateRuntime(
    repository.load(),
    notificationSettingsApplier: (settings) => notifications.applySettings(
      () => repository.applyNotificationSettings(settings),
    ),
  );
}

class _Scheduler implements NotificationScheduler {
  _Scheduler({this.failScheduling = false});

  final bool failScheduling;
  final List<String> operations = [];
  int? hour;
  int? minute;

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    operations.add('reminder');
    if (failScheduling) {
      throw PlatformException(
        code: 'error',
        message: 'TypeToken must be created with a type argument',
      );
    }
    this.hour = hour;
    this.minute = minute;
  }

  @override
  Future<void> scheduleStreakDefense() async => operations.add('streak');

  @override
  Future<void> cancelDailyReminder() async => operations.add('cancel-reminder');

  @override
  Future<void> cancelStreakDefense() async => operations.add('cancel-streak');
}

class _ToggleDriver implements ToggleSettingDriver {
  _ToggleDriver({this.fail = false});

  final bool fail;
  bool? enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (fail) throw PlatformException(code: 'audio-init');
    this.enabled = enabled;
  }
}
