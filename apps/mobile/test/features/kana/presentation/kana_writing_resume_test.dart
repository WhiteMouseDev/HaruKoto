import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/kana/data/kana_writing_progress_store.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_writing_progress.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';
import 'package:harukoto_mobile/features/kana/presentation/katakana_pilot_page.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/katakana_pilot_strokes.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scope = KanaWritingScope(owner: 'writer-a', hiragana: false);
const _canvas = ValueKey('katakana-recall-canvas');

void main() {
  for (final hiragana in [false, true]) {
    testWidgets('restore the same second glyph and all three steps ($hiragana)',
        (tester) async {
      final store = _MemoryStore();
      final prefs = await _prefs();
      final scope = KanaWritingScope(owner: 'writer-a', hiragana: hiragana);
      final letters = KanaPracticeRow.firstRow.letters(hiragana: hiragana);
      await _pump(tester, prefs, store, hiragana: hiragana);
      expect(
          find.text(
              '다음 추천: ${KanaPracticeRow.firstRow.label(hiragana: hiragana)}'),
          findsOneWidget);
      await _tapKey(tester, 'kana-writing-recommendation');
      await _finishLetter(tester, letters.first);
      await _tap(tester, '다음 글자');
      expect(find.text('2/5 글자 · 1/3 단계'), findsOneWidget);

      await _tapKey(tester, 'kana-writing-picker');
      await _pump(tester, prefs, store, hiragana: hiragana);
      expect(find.textContaining('${letters[1].glyph} · 2/5 글자 · 획순 보기'),
          findsOneWidget);
      await _tapKey(tester, 'kana-writing-resume');
      expect(find.text('2/5 글자 · 1/3 단계'), findsOneWidget);
      await _tap(tester, '가리고 쓰기');
      await tester.ensureVisible(find.byKey(_canvas));
      await tester.drag(find.byKey(_canvas), const Offset(50, -40));
      await tester.pumpAndSettle();
      await _tap(tester, '예시와 비교');
      await _tapKey(tester, 'kana-writing-picker');
      await _pump(tester, prefs, store, hiragana: hiragana);
      await _tapKey(tester, 'kana-writing-resume');
      expect(find.text('2/5 글자 · 2/3 단계'), findsOneWidget);
      expect(find.text('분홍색 예시와 내 글씨를 비교해 보세요.'), findsOneWidget);
      final pad =
          tester.widget<KatakanaRecallPad>(find.byType(KatakanaRecallPad));
      expect(pad.example, letters[1]);
      expect(pad.initialStrokes, hasLength(1));
      expect(store.document(scope).session!.strokes, hasLength(1));

      await _tap(tester, '단어에서 찾기');
      await _chooseCorrect(tester, letters[1]);
      await _pump(tester, prefs, store, hiragana: hiragana);
      await _tapKey(tester, 'kana-writing-resume');
      expect(find.text('2/5 글자 · 3/3 단계'), findsOneWidget);
      expect(find.textContaining('맞았어요!'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '다음 글자'))
              .onPressed,
          isNotNull);
      expect(store.document(scope).completedBasicCount, 0);
      expect(prefs.getBool('katakana_pilot_review.v1.writer-a.u'), true);
      expect(prefs.getBool('hiragana_pilot_review.v1.writer-a.u'), true);
      expect(prefs.getInt('existing-learning-record'), 8);
    });
  }

  testWidgets('only finishing a basic row advances the next-row recommendation',
      (tester) async {
    final store = _MemoryStore();
    final prefs = await _prefs();
    await _pump(tester, prefs, store);
    await _tap(tester, 'カ・キ・ク・ケ・コ');
    for (final letter in KanaPracticeRow.kaRow.letters(hiragana: false)) {
      await _finishLetter(tester, letter);
      await _tap(tester, letter == KatakanaPilotLetter.ko ? '연습 마치기' : '다음 글자');
    }
    expect(find.text('이 기기의 기본 쓰기 연습 5/46자 완료'), findsOneWidget);
    expect(find.text('다음 추천: ア・イ・ウ・エ・オ'), findsOneWidget);
    expect(store.document(_scope).completedBasicRows, {KanaPracticeRow.kaRow});
    await _tapKey(tester, 'kana-writing-recommendation');
    for (final letter in KanaPracticeRow.firstRow.letters(hiragana: false)) {
      await _finishLetter(tester, letter);
      await _tap(tester, letter == KatakanaPilotLetter.o ? '연습 마치기' : '다음 글자');
    }
    await _pump(tester, prefs, store);
    expect(find.text('이 기기의 기본 쓰기 연습 10/46자 완료'), findsOneWidget);
    expect(find.text('다음 추천: サ・シ・ス・セ・ソ'), findsOneWidget);
    await _tap(tester, 'ヵ・ヶ');
    expect(find.text('1/2 글자 · 1/3 단계'), findsOneWidget);
  });

  testWidgets('failed transition stays on the same step and retries its intent',
      (tester) async {
    final store = _MemoryStore();
    final prefs = await _prefs();
    await _pump(tester, prefs, store);
    await _tapKey(tester, 'kana-writing-recommendation');
    store.failNext = true;
    await _tap(tester, '가리고 쓰기');
    expect(find.text('1/5 글자 · 1/3 단계'), findsOneWidget);
    expect(store.document(_scope).session!.step, KanaWritingStep.compare);
    expect(tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        false);
    await _tap(tester, '쓰기 위치 저장 다시 시도');
    expect(find.text('1/5 글자 · 2/3 단계'), findsOneWidget);
    expect(store.document(_scope).session!.step, KanaWritingStep.recall);
    await _pump(tester, prefs, store);
    await _tapKey(tester, 'kana-writing-resume');
    expect(find.text('1/5 글자 · 2/3 단계'), findsOneWidget);
  });

  testWidgets('ink save locks navigation without shifting the canvas',
      (tester) async {
    final store = _MemoryStore();
    final prefs = await _prefs();
    await _pump(tester, prefs, store);
    await _tapKey(tester, 'kana-writing-recommendation');
    await _tap(tester, '가리고 쓰기');
    await tester.ensureVisible(find.byKey(_canvas));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byKey(_canvas));
    store.gate = Completer<void>();
    await tester.drag(find.byKey(_canvas), const Offset(45, -35));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_canvas)), before);
    expect(tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        false);
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('kana-writing-picker')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '예시와 비교'))
            .onPressed,
        isNull);
    store.gate!.complete();
    store.gate = null;
    await tester.pumpAndSettle();
    expect(tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        true);
    expect(store.document(_scope).session!.strokes, hasLength(1));
  });

  testWidgets(
      'replacement confirmation preserves prior session on cancel and failure',
      (tester) async {
    final store = _MemoryStore();
    final prefs = await _prefs();
    await _pump(tester, prefs, store);
    await _tapKey(tester, 'kana-writing-recommendation');
    await _tap(tester, '가리고 쓰기');
    await _tapKey(tester, 'kana-writing-picker');
    await _tap(tester, 'シ・ツ・ソ・ン');
    await _tap(tester, '취소');
    expect(store.document(_scope).session!.letter, KatakanaPilotLetter.a);
    await _tap(tester, 'シ・ツ・ソ・ン');
    store.failNext = true;
    await _tap(tester, '새 연습 시작');
    expect(store.document(_scope).session!.letter, KatakanaPilotLetter.a);
    await _tap(tester, '쓰기 위치 저장 다시 시도');
    expect(find.text('1/4 글자 · 1/3 단계'), findsOneWidget);
    expect(store.document(_scope).session!.letter, KatakanaPilotLetter.shi);
    expect(store.document(_scope).completedBasicCount, 0);
  });

  testWidgets('word choice and final-row failures retry once without skipping',
      (tester) async {
    final store = _MemoryStore();
    final prefs = await _prefs();
    await _pump(tester, prefs, store);
    await _tapKey(tester, 'kana-writing-recommendation');
    await _tap(tester, '가리고 쓰기');
    await _tap(tester, '쓰기 건너뛰기');
    store.failNext = true;
    await _chooseCorrect(tester, KatakanaPilotLetter.a);
    expect(find.textContaining('맞았어요!'), findsNothing);
    expect(store.document(_scope).session!.selectedIndex, isNull);
    await _tap(tester, '쓰기 위치 저장 다시 시도');
    expect(find.textContaining('맞았어요!'), findsOneWidget);
    expect(find.text('1/5 글자 · 3/3 단계'), findsOneWidget);
    await _tap(tester, '다음 글자');
    final remaining = KanaPracticeRow.firstRow.letters(hiragana: false).skip(1);
    for (final letter in remaining) {
      await _finishLetter(tester, letter);
      if (letter != KatakanaPilotLetter.o) await _tap(tester, '다음 글자');
    }
    store.failNext = true;
    await _tap(tester, '연습 마치기');
    expect(find.text('5/5 글자 · 3/3 단계'), findsOneWidget);
    expect(store.document(_scope).completedBasicCount, 0);
    await _tap(tester, '쓰기 위치 저장 다시 시도');
    expect(find.text('이 기기의 기본 쓰기 연습 5/46자 완료'), findsOneWidget);
    expect(find.text('다음 추천: カ・キ・ク・ケ・コ'), findsOneWidget);
    expect(
        store.document(_scope).completedBasicRows, {KanaPracticeRow.firstRow});
    expect(store.document(_scope).session, isNull);
    await _pump(tester, prefs, store);
    expect(find.text('이 기기의 기본 쓰기 연습 5/46자 완료'), findsOneWidget);
  });

  testWidgets('daily review preserves a saved general-writing checkpoint',
      (tester) async {
    final store = _MemoryStore();
    final prefs = await _prefs();
    await _pump(tester, prefs, store);
    await _tapKey(tester, 'kana-writing-recommendation');
    await _tap(tester, '가리고 쓰기');
    final before = store.document(_scope).encode();
    await _tapKey(tester, 'kana-writing-picker');
    await _tap(tester, '새 단어로 복습');
    const letter = KatakanaPilotLetter.u;
    final index = letter.reviewWord.text.runes
        .toList()
        .indexOf(letter.glyph.runes.single);
    await _tapKey(tester, 'katakana-word-character-$index');
    await _tap(tester, '연습 마치기');
    expect(store.document(_scope).encode(), before);
    expect(store.document(_scope).completedBasicCount, 0);
    await _tapKey(tester, 'kana-writing-resume');
    expect(find.text('1/5 글자 · 2/3 단계'), findsOneWidget);
  });

  testWidgets(
      'account and script switches restore only their own writing position',
      (tester) async {
    final store = _MemoryStore();
    final prefs = await _prefs();
    await _pump(tester, prefs, store);
    await _tap(tester, 'ガ・ギ・グ・ゲ・ゴ');
    await _tap(tester, '가리고 쓰기');
    await _pump(tester, prefs, store, owner: 'writer-b');
    expect(find.byKey(const ValueKey('kana-writing-resume')), findsNothing);
    await _tapKey(tester, 'kana-writing-recommendation');
    expect(find.text('ア · あ'), findsOneWidget);
    await _pump(tester, prefs, store, hiragana: true);
    expect(find.byKey(const ValueKey('kana-writing-resume')), findsNothing);
    await _pump(tester, prefs, store);
    await _tapKey(tester, 'kana-writing-resume');
    expect(find.text('1/5 글자 · 2/3 단계'), findsOneWidget);
    expect(find.text('が'), findsOneWidget);
  });
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({
    'katakana_pilot_review.v1.writer-a.u': true,
    'hiragana_pilot_review.v1.writer-a.u': true,
    'existing-learning-record': 8,
  });
  return SharedPreferences.getInstance();
}

Future<void> _pump(
    WidgetTester tester, SharedPreferences prefs, _MemoryStore store,
    {bool hiragana = false, String owner = 'writer-a'}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      kanaWritingProgressStoreProvider.overrideWithValue(store),
      currentAccountIdProvider.overrideWithValue(owner),
      currentAccountReaderProvider.overrideWithValue(() => owner),
    ],
    child: MaterialApp(home: KanaPilotPage(hiragana: hiragana)),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) await tester.scrollUntilVisible(finder, 180);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) await tester.scrollUntilVisible(finder, 180);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _chooseCorrect(
    WidgetTester tester, KanaPracticeLetter letter) async {
  final index = letter.word.runes.toList().indexOf(letter.glyph.runes.single);
  await _tapKey(tester, 'katakana-word-character-$index');
}

Future<void> _finishLetter(
    WidgetTester tester, KanaPracticeLetter letter) async {
  await _tap(tester, '가리고 쓰기');
  await _tap(tester, '쓰기 건너뛰기');
  await _chooseCorrect(tester, letter);
}

class _MemoryStore implements KanaWritingProgressStore {
  final _documents = <KanaWritingScope, String>{};
  bool failNext = false;
  Completer<void>? gate;

  KanaWritingProgress document(KanaWritingScope scope) =>
      KanaWritingProgress.decode(_documents[scope]!, scope);

  @override
  Future<String?> read(KanaWritingScope scope) async => _documents[scope];

  @override
  Future<void> compareAndSet(KanaWritingScope scope,
      {required String? expected,
      required String value,
      required bool Function() isCurrent}) async {
    if (gate != null) await gate!.future;
    if (failNext) {
      failNext = false;
      throw const KanaWritingStorageException();
    }
    if (!isCurrent() || _documents[scope] != expected) {
      throw const KanaWritingStorageException();
    }
    _documents[scope] = value;
  }
}
