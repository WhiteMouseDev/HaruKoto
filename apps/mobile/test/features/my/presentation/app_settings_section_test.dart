import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/device_settings_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/theme_provider.dart';
import 'package:harukoto_mobile/core/settings/device_settings_repository.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/app_settings_section.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/my_settings_toggle_tile.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/reminder_time_dialog.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/theme_picker_sheet.dart';
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

  testWidgets('theme cards stage a choice until Apply and restore it on reopen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    await _pumpSettings(
      tester,
      initialSettings: {'device_theme_mode': 'light'},
    );
    final prefs = await SharedPreferences.getInstance();

    final entry = find.widgetWithText(ListTile, '테마 선택');
    final sheet = find.byType(ThemePickerSheet);
    final light = find.widgetWithText(OutlinedButton, '라이트');
    final dark = find.widgetWithText(OutlinedButton, '다크');
    final system = find.widgetWithText(OutlinedButton, '시스템');
    Brightness currentBrightness() =>
        Theme.of(tester.element(find.byType(AppSettingsSection))).brightness;

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet), const Size(375, 273));
    expect(tester.getSize(light).width, closeTo(109, 0.01));
    expect(tester.getSize(light).height, 90);
    expect(tester.getTopLeft(dark).dx - tester.getTopRight(light).dx, 4);
    expect(tester.getSemantics(light), isSemantics(isSelected: true));

    await tester.tap(dark);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(dark), isSemantics(isSelected: true));
    expect(currentBrightness(), Brightness.light);
    expect(prefs.getString('device_theme_mode'), 'light');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(prefs.getString('device_theme_mode'), 'light');

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(light), isSemantics(isSelected: true));
    await tester.tap(dark);
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(prefs.getString('device_theme_mode'), 'dark');
    expect(currentBrightness(), Brightness.dark);

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(dark), isSemantics(isSelected: true));
    await tester.tap(system);
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(prefs.getString('device_theme_mode'), 'system');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(currentBrightness(), Brightness.dark);
    semantics.dispose();
  });

  testWidgets('theme applies at 320pt and 200% text scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpSettings(tester, largeText: true);

    await tester.tap(find.widgetWithText(ListTile, '테마 선택'));
    await tester.pumpAndSettle();
    final system = find.widgetWithText(OutlinedButton, '시스템');
    expect(system.hitTestable(), findsOneWidget);
    expect(tester.getSize(system).height, greaterThan(90));
    await tester.tap(system);
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('device_theme_mode'), 'system');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a theme save failure leaves the last committed theme active',
      (tester) async {
    await _pumpSettings(
      tester,
      initialSettings: {'device_theme_mode': 'light'},
      rejectThemeSave: true,
    );

    await tester.tap(find.widgetWithText(ListTile, '테마 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '다크'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('device_theme_mode'), 'light');
    expect(find.text('라이트'), findsOneWidget);
    expect(
      find.text('테마 설정을 저장하지 못했어요. 다시 시도해주세요.'),
      findsOneWidget,
    );
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
  bool rejectThemeSave = false,
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
      if (rejectThemeSave)
        deviceSettingsRepositoryProvider.overrideWithValue(
          _RejectThemeSave(sharedPreferences: prefs),
        )
      else if (scheduler != null)
        deviceSettingsRepositoryProvider.overrideWithValue(
          DeviceSettingsRepository(
            sharedPreferences: prefs,
            notificationScheduler: scheduler,
          ),
        ),
    ],
    child: Consumer(
      builder: (context, ref, child) => MaterialApp(
        themeMode: ref.watch(themeProvider),
        darkTheme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: AppSettingsSection()),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

class _RejectThemeSave extends DeviceSettingsRepository {
  _RejectThemeSave({required super.sharedPreferences});

  @override
  Future<void> persistThemeMode(ThemeMode themeMode) async {
    throw StateError('Setting was not saved');
  }
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
