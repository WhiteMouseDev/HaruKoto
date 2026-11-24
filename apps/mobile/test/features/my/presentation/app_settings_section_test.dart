import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/my/presentation/widgets/app_settings_section.dart';
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
