import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/device_settings_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/settings/device_settings_repository.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/app_settings_section.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/my_settings_toggle_tile.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/reminder_time_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.harukoto.app/app_version');

void main() {
  testWidgets('shows installed version and build at 320dp and 2x text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calls = <String>[];
    _mockVersionChannel((call) async {
      calls.add(call.method);
      return {'version': '4.17.8', 'buildNumber': '214'};
    });

    await _pumpSettings(tester, largeText: true);

    expect(calls, ['getVersion']);
    expect(find.text('앱 버전'), findsOneWidget);
    expect(find.text('4.17.8 (214)'), findsOneWidget);
    expect(find.text('테마 선택'), findsOneWidget);
    final furigana = find.widgetWithText(MySettingsToggleTile, '읽기(후리가나) 표시');
    final furiganaRow = tester.getRect(furigana);
    final subtitle = tester.getRect(find.text('퀴즈에서 한자 위에 히라가나 표시'));
    expect(furiganaRow.height, greaterThan(56));
    expect(subtitle.bottom, lessThan(furiganaRow.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows version alone when build number is missing',
      (tester) async {
    _mockVersionChannel((call) async => {'version': '4.17.8'});
    await _pumpSettings(tester);

    expect(find.text('4.17.8'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('marks version unavailable when there is no native plugin',
      (tester) async {
    await _pumpSettings(tester);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('테마 선택'), findsOneWidget);
  });

  testWidgets('marks version unavailable on a platform read failure',
      (tester) async {
    _mockVersionChannel((call) async {
      throw PlatformException(code: 'VERSION_UNAVAILABLE');
    });
    await _pumpSettings(tester);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('테마 선택'), findsOneWidget);
  });

  testWidgets('uses the settings row grid and keeps the sound switch tappable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpSettings(tester);

    final card = tester.getRect(find.byType(Card));
    const labels = [
      '앱 버전',
      '테마 선택',
      '읽기(후리가나) 표시',
      '효과음',
      '진동 피드백',
      '학습 리마인더',
      '리마인더 시간',
      '연속학습 알림',
    ];
    for (final (index, label) in labels.indexed) {
      final row = tester.getRect(find.widgetWithText(ListTile, label));
      expect(row.top - card.top, 9 + index * 56, reason: label);
      expect(row.height, 56, reason: label);
    }
    expect(tester.getTopLeft(find.text('앱 버전')).dx - card.left, 49);

    final soundTile = find.widgetWithText(MySettingsToggleTile, '효과음');
    final soundToggle = find.descendant(
      of: soundTile,
      matching: find.byType(Switch),
    );
    final track = tester.getRect(find.descendant(
      of: soundTile,
      matching: find.byType(AnimatedContainer),
    ));
    expect(track.size, const Size(50, 28));
    expect(track.right, card.right - 17);
    expect(track.center.dy, tester.getRect(soundTile).center.dy);
    final enabled = tester.widget<Switch>(soundToggle).value;
    expect(
      tester
          .getSemantics(soundTile)
          .getSemanticsData()
          .flagsCollection
          .isToggled,
      enabled ? Tristate.isTrue : Tristate.isFalse,
    );
    await tester.tap(find.text('효과음'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(soundToggle).value, !enabled);
    await tester.tap(soundToggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(soundToggle).value, enabled);
  });

  testWidgets('reminder wheels cancel and save through the device settings',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scheduler = _RecordingScheduler();
    await _pumpSettings(
      tester,
      scheduler: scheduler,
      initialSettings: {
        'notification_reminder_hour': 0,
        'notification_reminder_minute': 59,
      },
    );

    final row = find.text('리마인더 시간');
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    final dialog = find.byType(ReminderTimeDialog);
    final surface = find.descendant(
      of: dialog,
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.type == MaterialType.card,
      ),
    );
    expect(tester.getSize(surface), const Size(335, 308));
    final noon = find.descendant(of: dialog, matching: find.text('오후'));
    await tester.tap(noon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('오전 12:59'), findsOneWidget);
    expect(scheduler.reminders, isEmpty);

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(noon);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: dialog, matching: find.text('00')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('오후 12:00'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('notification_reminder_hour'), 12);
    expect(prefs.getInt('notification_reminder_minute'), 0);
    expect(scheduler.reminders, [const TimeOfDay(hour: 12, minute: 0)]);
  });
}

void _mockVersionChannel(Future<Object?> Function(MethodCall call) handler) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, handler);
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  bool largeText = false,
  Map<String, Object> initialSettings = const {},
  NotificationScheduler? scheduler,
}) async {
  SharedPreferences.setMockInitialValues(initialSettings);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentAccountIdProvider.overrideWithValue('app-settings-fixture'),
      currentAccountReaderProvider
          .overrideWithValue(() => 'app-settings-fixture'),
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (scheduler != null)
        deviceSettingsRepositoryProvider.overrideWithValue(
          DeviceSettingsRepository(
            sharedPreferences: prefs,
            notificationScheduler: scheduler,
          ),
        ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(child: AppSettingsSection()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

class _RecordingScheduler implements NotificationScheduler {
  final reminders = <TimeOfDay>[];

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    reminders.add(TimeOfDay(hour: hour, minute: minute));
  }

  @override
  Future<void> cancelDailyReminder() async {}

  @override
  Future<void> scheduleStreakDefense() async {}

  @override
  Future<void> cancelStreakDefense() async {}
}
