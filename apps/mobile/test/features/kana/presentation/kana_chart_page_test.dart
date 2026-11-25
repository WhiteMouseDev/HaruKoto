import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/theme/text_theme.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_character_model.dart';
import 'package:harukoto_mobile/features/kana/presentation/kana_chart_page.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/kana_chart_grid.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';
import 'package:harukoto_mobile/shared/widgets/tts_play_button.dart';

void main() {
  testWidgets('pending characters preserve the grid dimensions without cells',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final hiragana = Completer<List<KanaCharacterModel>>();
    await _pumpChart(
      tester,
      load: (type) async =>
          type == 'HIRAGANA' ? await hiragana.future : _characters(type),
    );

    final grid = find.byType(KanaChartGrid);
    final pendingSize = tester.getSize(grid);
    expect(find.bySemanticsLabel('히라가나 표를 불러오는 중'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('문자 상세')), findsNothing);
    expect(find.text('か'), findsNothing);

    hiragana.complete(_characters('HIRAGANA'));
    await tester.pumpAndSettle();
    expect(tester.getSize(grid), pendingSize);
    expect(find.bySemanticsLabel('히라가나 표를 불러오는 중'), findsNothing);
    expect(find.bySemanticsLabel('か, 카, 미학습, 문자 상세'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('both scripts place Korean readings on axes and keep real cells',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpChart(tester, load: (type) async => _characters(type));
      expect(find.text('가나 차트'), findsOneWidget);
      expect(find.bySemanticsLabel('い, 이'), findsOneWidget);
      expect(find.bySemanticsLabel('か, 카'), findsOneWidget);
      expect(find.bySemanticsLabel('カ, 카'), findsNothing);

      final ordinary = find.bySemanticsLabel('か, 카, 미학습, 문자 상세');
      final nasal = find.bySemanticsLabel('ん, 받침 소리, 미학습, 문자 상세');
      expect(tester.getSize(nasal).width,
          greaterThan(5 * tester.getSize(ordinary).width));
      expect(find.text('偽'), findsNothing); // No kana in the YA/I position.

      await tester.tap(find.text('가타카나'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('イ, 이'), findsOneWidget);
      expect(find.bySemanticsLabel('カ, 카'), findsOneWidget);
      expect(find.bySemanticsLabel('か, 카'), findsNothing);
      expect(find.bySemanticsLabel('ン, 받침 소리, 미학습, 문자 상세'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('カ, 카, 미학습, 문자 상세'));
      await tester.pumpAndSettle();
      expect(find.text('문자 상세'), findsOneWidget);
      expect(find.text('대응 히라가나'), findsOneWidget);
      expect(
          tester.widget<TtsPlayButton>(find.byType(TtsPlayButton)).text, 'カ');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('an error in the other script does not hide the active chart',
      (tester) async {
    var katakanaAttempts = 0;
    await _pumpChart(tester, load: (type) async {
      if (type == 'KATAKANA' && ++katakanaAttempts == 1) {
        throw StateError('Offline');
      }
      return _characters(type);
    });
    expect(find.text('가나 차트'), findsOneWidget);
    expect(find.text('か'), findsNWidgets(2));
    expect(find.text('다시 시도'), findsNothing);

    await tester.tap(find.text('가타카나'));
    await tester.pumpAndSettle();
    expect(find.text('가타카나를 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(katakanaAttempts, 2);
    expect(find.text('カ'), findsNWidgets(2));
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('matches the 375dp chart geometry and text styles',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpChart(
      tester,
      load: (type) async => _characters(type),
      topInset: 44,
    );

    final grid = tester.getRect(find.byType(KanaChartGrid));
    expect(grid.left, 20);
    expect(grid.top, 174);
    expect(grid.width, 335);

    final kana = tester.widget<Text>(find.text('あ').last);
    expect(kana.style?.fontFamily, redesignFontFamily);
    expect(kana.style?.fontSize, 15);
    expect(kana.style?.fontWeight, FontWeight.w500);
    expect(kana.style?.height, 1.5);
    expect(kana.style?.letterSpacing, -0.375);

    final axisKana = tester.widget<Text>(find.text('あ').first);
    final axisReading = tester.widget<Text>(find.text('아').first);
    expect(axisKana.style?.fontFamily, redesignJapaneseFontFamily);
    expect(axisKana.style?.fontSize, 13);
    expect(axisKana.style?.fontWeight, FontWeight.w400);
    expect(axisReading.style?.fontFamily, redesignJapaneseFontFamily);
    expect(axisReading.style?.fontSize, 11);
    expect(axisReading.style?.fontWeight, FontWeight.w400);

    for (final title in ['히라가나', '가타카나']) {
      final tab = tester.widget<TextButton>(
        find.widgetWithText(TextButton, title),
      );
      final tabStyle = tab.style?.textStyle?.resolve({});
      expect(tabStyle?.fontSize, 13);
      expect(tabStyle?.fontWeight, FontWeight.w500);
    }
  });

  testWidgets('320px 2x bold dark chart keeps the last column reachable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      await _pumpChart(
        tester,
        load: (type) async => _characters(type),
        brightness: Brightness.dark,
        textScaler: const TextScaler.linear(2),
        boldText: true,
      );
      final waFinal = find.bySemanticsLabel('を, 오, 미학습, 문자 상세');
      await tester.ensureVisible(waFinal);
      await tester.pumpAndSettle();
      expect(waFinal.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _pumpChart(
  WidgetTester tester, {
  required Future<List<KanaCharacterModel>> Function(String type) load,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool boldText = false,
  double topInset = 0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (attempt, error) => null,
      overrides: [
        for (final type in ['HIRAGANA', 'KATAKANA'])
          kanaBasicCharactersProvider(type).overrideWith((ref) => load(type)),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            boldText: boldText,
            padding: EdgeInsets.only(top: topInset),
          ),
          child: child!,
        ),
        home: const KanaChartPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<KanaCharacterModel> _characters(String type) {
  final katakana = type == 'KATAKANA';
  final records = [
    ('a', 'a', katakana ? 'ア' : 'あ', 'a', '아'),
    ('ka', 'a', katakana ? 'カ' : 'か', 'ka', '카'),
    ('ya', 'i', '偽', 'yi', '이'),
    ('wa', 'o', katakana ? 'ヲ' : 'を', 'wo', '오'),
    ('n', 'a', katakana ? 'ン' : 'ん', 'n', 'ん'),
  ];
  return [
    for (final (row, column, character, romaji, pronunciation) in records)
      KanaCharacterModel(
        id: '$type-$romaji',
        kanaType: type,
        character: character,
        romaji: romaji,
        pronunciation: pronunciation,
        row: row,
        column: column,
        strokeCount: 1,
        category: 'basic',
        order: 1,
      ),
  ];
}
