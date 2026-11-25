import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/app_settings_section.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/my_settings_toggle_tile.dart';
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
    final versionRow = tester.getRect(find.widgetWithText(ListTile, '앱 버전'));
    final themeRow = tester.getRect(find.widgetWithText(ListTile, '테마 선택'));
    expect(versionRow.top - card.top, 9);
    expect(versionRow.height, 56);
    expect(themeRow.top, versionRow.bottom);
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
}

void _mockVersionChannel(Future<Object?> Function(MethodCall call) handler) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, handler);
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
}

Future<void> _pumpSettings(WidgetTester tester,
    {bool largeText = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentAccountIdProvider.overrideWithValue('app-settings-fixture'),
      currentAccountReaderProvider
          .overrideWithValue(() => 'app-settings-fixture'),
      sharedPreferencesProvider.overrideWithValue(prefs),
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
