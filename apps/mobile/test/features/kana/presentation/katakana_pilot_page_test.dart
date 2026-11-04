import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/kana/presentation/kana_type_page.dart';
import 'package:harukoto_mobile/features/kana/presentation/katakana_pilot_page.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const markKey = 'katakana_pilot_review.v1.account-a.shi';
  final canvas = find.byKey(const ValueKey('katakana-recall-canvas'));

  Future<void> tapText(WidgetTester tester, String label) async {
    final target = find.text(label);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 160);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tapText(tester, 'シ・ツ・ソ・ン');
    await tapText(tester, '가리고 쓰기');
  }

  void expectCanCompare(WidgetTester tester, bool enabled) {
    final button = find.widgetWithText(FilledButton, '예시와 비교');
    expect(tester.widget<FilledButton>(button).onPressed != null, enabled);
  }

  testWidgets('compare, recall, check ink and find a kana in a word',
      (tester) async {
    final prefs = await _preferences();
    await _pumpPilot(tester, prefs);
    await tapText(tester, 'シ・ツ・ソ・ン');

    expect(find.text('1/4 글자 · 1/3 단계'), findsOneWidget);
    expect(find.text('シ · し'), findsOneWidget);
    expect(find.text('ツ · つ'), findsOneWidget);
    await tapText(tester, '획순 재생');
    await tapText(tester, '가리고 쓰기');

    expect(find.text('シ'), findsNothing);
    expect(find.text('し'), findsOneWidget);
    expectCanCompare(tester, false);
    await tester.tap(canvas);
    await tester.pump();
    expectCanCompare(tester, false);

    final first = await tester.startGesture(tester.getCenter(canvas));
    await first.moveBy(const Offset(50, -40));
    await first.cancel();
    await tester.pump();
    expectCanCompare(tester, false);

    final outside = await tester.startGesture(tester.getCenter(canvas));
    await outside.moveBy(const Offset(40, -35));
    await outside.moveTo(tester.getTopLeft(canvas) - const Offset(10, 10));
    await outside.up();
    await tester.pump();
    expectCanCompare(tester, false);

    await tester.drag(canvas, const Offset(0, -65));
    await tester.pump();
    expectCanCompare(tester, true);
    await tapText(tester, '한 획 지우기');
    expectCanCompare(tester, false);

    await tester.drag(canvas, const Offset(55, -60));
    await tester.drag(canvas, const Offset(20, -30));
    await tester.pump();
    await tapText(tester, '모두 지우기');
    expectCanCompare(tester, false);

    await tester.drag(canvas, const Offset(65, -50));
    await tester.pump();
    await tapText(tester, '예시와 비교');
    expect(find.text('분홍색 예시와 내 글씨를 비교해 보세요.'), findsOneWidget);
    expect(find.text('한 획 지우기'), findsNothing);
    await tapText(tester, '단어에서 찾기');

    await tester.tap(find.byKey(const ValueKey('katakana-word-character-0')));
    await tester.pump();
    expect(find.textContaining('다시 찾아보세요.'), findsOneWidget);
    expect(find.text('다음 글자'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('katakana-word-character-1')));
    await tester.pumpAndSettle();
    expect(find.text('맞았어요! ミシン (みしん) · 재봉틀'), findsOneWidget);
    await tapText(tester, '헷갈렸어요');
    expect(find.text('다음 복습에 저장했어요.'), findsOneWidget);
    expect(prefs.getBool(markKey), true);
    expect(prefs.getInt('existing-learning-value'), 3);

    final next = find.widgetWithText(FilledButton, '다음 글자');
    await tester.ensureVisible(next);
    final onNext = tester.widget<FilledButton>(next).onPressed!;
    onNext();
    onNext(); // A second tap before rebuilding must not skip a letter.
    await tester.pumpAndSettle();
    expect(find.text('2/4 글자 · 1/3 단계'), findsOneWidget);
    expect(find.text('ツ · つ'), findsOneWidget);
  });

  testWidgets('selected pair finishes after two letters and keeps both marks',
      (tester) async {
    final prefs = await _preferences({markKey: true});
    await _pumpPilot(tester, prefs);
    await tapText(tester, 'ク・タ');

    expect(find.text('1/2 글자 · 1/3 단계'), findsOneWidget);
    expect(find.text('ク · く'), findsOneWidget);
    expect(find.text('タ · た'), findsOneWidget);
    expect(find.text('シ · し'), findsNothing);
    await tapText(tester, '가리고 쓰기');
    expect(find.text('く'), findsOneWidget);
    await tester.drag(canvas, const Offset(35, -50));
    await tester.pump();
    await tapText(tester, '예시와 비교');
    await tapText(tester, '단어에서 찾기');
    await tapText(tester, 'ク');
    await tapText(tester, '헷갈렸어요');
    await tapText(tester, '다음 글자');

    expect(find.text('2/2 글자 · 1/3 단계'), findsOneWidget);
    await tapText(tester, '가리고 쓰기');
    expect(find.text('た'), findsOneWidget);
    await tapText(tester, '쓰기 건너뛰기');
    await tapText(tester, 'タ');
    await tapText(tester, '연습 마치기');

    expect(find.text('묶음 골라 연습'), findsOneWidget);
    expect(find.text('シ · ク'), findsOneWidget);
    await tapText(tester, '헷갈린 글자 복습');
    expect(find.text('1/2 글자 · 1/3 단계'), findsOneWidget);
    await tapText(tester, '가리고 쓰기');
    expect(find.text('し'), findsOneWidget);
    await tapText(tester, '쓰기 건너뛰기');
    await tapText(tester, 'シ');
    await tapText(tester, '다음 글자');
    await tapText(tester, '가리고 쓰기');
    expect(find.text('く'), findsOneWidget);
  });

  testWidgets('three comparison diagrams and cues fit with large text',
      (tester) async {
    final prefs = await _preferences();
    await _pumpPilot(tester, prefs, width: 320, textScale: 2);
    await tapText(tester, 'フ・ワ・ウ');

    expect(find.text('1/3 글자 · 1/3 단계'), findsOneWidget);
    for (final label in ['フ · ふ', 'ワ · わ', 'ウ · う']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final glyph in ['フ', 'ワ', 'ウ']) {
      final cue = find.textContaining('$glyph  ');
      expect(cue, findsOneWidget);
      expect(tester.getSize(cue).width, greaterThan(250));
    }
    await tapText(tester, '가리고 쓰기');
    expect(find.text('ふ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stored uncertainty offers only the marked letter on re-entry',
      (tester) async {
    final prefs = await _preferences({markKey: true});
    await _pumpPilot(tester, prefs, owner: 'account-b');
    expect(find.text('헷갈린 글자 복습'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await _pumpPilot(tester, prefs);
    await tapText(tester, '헷갈린 글자 복습');
    expect(find.text('1/1 글자 · 1/3 단계'), findsOneWidget);
    await tapText(tester, '가리고 쓰기');
    expect(find.text('し'), findsOneWidget);
    await tapText(tester, '쓰기 건너뛰기');
    await tester.tap(find.byKey(const ValueKey('katakana-word-character-1')));
    await tester.pumpAndSettle();
    await tapText(tester, '헷갈림 표시 지우기');
    await tapText(tester, '연습 마치기');
    expect(find.text('헷갈린 글자 복습'), findsNothing);
    expect(prefs.getBool(markKey), isNot(true));
  });

  testWidgets('stale account cannot mark from a still-rendered word screen',
      (tester) async {
    final prefs = await _preferences();
    var sessionOwner = 'account-a';
    await _pumpPilot(tester, prefs, sessionReader: () => sessionOwner);
    await start(tester);
    await tapText(tester, '쓰기 건너뛰기');
    await tester.tap(find.byKey(const ValueKey('katakana-word-character-1')));
    await tester.pumpAndSettle();

    sessionOwner = 'account-b';
    await tapText(tester, '헷갈렸어요');
    expect(prefs.getKeys(), {'existing-learning-value'});
    expect(find.text('다음 복습에 저장했어요.'), findsNothing);
  });

  testWidgets('katakana has the local entry even when stage fetch fails',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kanaStagesProvider('KATAKANA')
              .overrideWith((ref) async => throw StateError('offline')),
        ],
        child: const MaterialApp(home: KanaTypePage(type: 'katakana')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('닮은 가타카나 집중 연습'), findsOneWidget);
  });
}

Future<SharedPreferences> _preferences([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues({
    'existing-learning-value': 3,
    ...initial,
  });
  return SharedPreferences.getInstance();
}

Future<void> _pumpPilot(
  WidgetTester tester,
  SharedPreferences prefs, {
  String owner = 'account-a',
  String Function()? sessionReader,
  double width = 412,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentAccountIdProvider.overrideWithValue(owner),
        currentAccountReaderProvider.overrideWithValue(
          sessionReader ?? () => owner,
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const KatakanaPilotPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
