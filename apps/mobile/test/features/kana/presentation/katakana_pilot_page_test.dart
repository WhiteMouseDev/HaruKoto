import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';
import 'package:harukoto_mobile/features/kana/presentation/kana_type_page.dart';
import 'package:harukoto_mobile/features/kana/presentation/katakana_pilot_page.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/katakana_pilot_strokes.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';
import 'package:harukoto_mobile/features/kana/providers/katakana_pilot_review_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const markKey = 'katakana_pilot_review.v1.account-a.shi';
  const fuMarkKey = 'katakana_pilot_review.v1.account-a.fu';
  const uMarkKey = 'katakana_pilot_review.v1.account-a.u';
  final canvas = find.byKey(const ValueKey('katakana-recall-canvas'));

  Future<void> showText(WidgetTester tester, String label) async {
    final target = find.text(label);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 160);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    await showText(tester, label);
    await tester.tap(find.text(label));
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

  Future<void> skipWriteAndFind(
    WidgetTester tester,
    KatakanaPilotLetter letter,
  ) async {
    await tapText(tester, '가리고 쓰기');
    await tapText(tester, '쓰기 건너뛰기');
    await tapText(tester, letter.glyph);
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
    await showText(tester, '이 기기에 저장된 복습');
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

  testWidgets('the first row teaches five individual letters in order',
      (tester) async {
    final prefs = await _preferences();
    await _pumpPilot(tester, prefs, width: 320, textScale: 1.4);
    await tapText(tester, 'ア・イ・ウ・エ・オ');

    final letters = KatakanaPracticeGroup.firstRow.letters;
    for (final (index, letter) in letters.indexed) {
      expect(find.text('${index + 1}/5 글자 · 1/3 단계'), findsOneWidget);
      expect(find.text('획순 보기'), findsOneWidget);
      expect(find.text('${letter.glyph} · ${letter.reading}'), findsOneWidget);
      expect(find.text('フ · ふ'), findsNothing);
      expect(find.text('ワ · わ'), findsNothing);
      await tapText(tester, '획순 재생');
      await tapText(tester, '가리고 쓰기');
      expect(find.text(letter.glyph), findsNothing);
      expect(find.text(letter.reading), findsOneWidget);

      if (index == 0) {
        await tester.ensureVisible(canvas);
        await tester.pumpAndSettle();
        await tester.drag(canvas, const Offset(30, -45));
        await tester.pump();
        expectCanCompare(tester, true);
        await tapText(tester, '한 획 지우기');
        expectCanCompare(tester, false);
        await tester.ensureVisible(canvas);
        await tester.pumpAndSettle();
        await tester.drag(canvas, const Offset(30, -45));
        await tester.pump();
        await tapText(tester, '예시와 비교');
        expect(find.text('분홍색 예시와 내 글씨를 비교해 보세요.'), findsOneWidget);
        await tapText(tester, '단어에서 찾기');
      } else {
        await tapText(tester, '쓰기 건너뛰기');
      }

      await tapText(tester, letter.glyph);
      expect(find.textContaining('맞았어요! ${letter.word}'), findsOneWidget);
      if (index == 0) await tapText(tester, '헷갈렸어요');
      await tapText(tester, index == 4 ? '연습 마치기' : '다음 글자');
    }

    expect(find.text('기본 가타카나 쓰기'), findsOneWidget);
    await tapText(tester, '헷갈린 글자 복습');
    expect(find.text('1/1 글자 · 1/3 단계'), findsOneWidget);
    expect(find.text('획순 보기'), findsOneWidget);
    expect(find.text('ア · あ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiragana first row uses sound hints and its own review marks',
      (tester) async {
    final prefs = await _preferences({markKey: true});
    await _pumpPilot(tester, prefs, hiragana: true);
    expect(find.text('히라가나 집중 연습'), findsOneWidget);
    expect(find.text('シ'), findsNothing);
    await tapText(tester, 'あ・い・う・え・お');

    final letters = KanaPracticeRow.firstRow.letters(hiragana: true);
    for (final (index, letter) in letters.indexed) {
      expect(find.text('${index + 1}/5 글자 · 1/3 단계'), findsOneWidget);
      expect(find.text('${letter.glyph} · ${letter.reading}'), findsOneWidget);
      await tapText(tester, '획순 재생');
      await tapText(tester, '가리고 쓰기');
      expect(find.text(letter.glyph), findsNothing);
      expect(find.text(letter.reading), findsOneWidget);

      if (index == 0) {
        await tester.drag(canvas, const Offset(30, -45));
        await tester.pump();
        await tapText(tester, '예시와 비교');
        expect(find.text('분홍색 예시와 내 글씨를 비교해 보세요.'), findsOneWidget);
        await tapText(tester, '단어에서 찾기');
      } else {
        await tapText(tester, '쓰기 건너뛰기');
      }

      await tapText(tester, letter.glyph);
      expect(find.text('맞았어요! ${letter.word} · ${letter.meaning}'),
          findsOneWidget);
      if (index == 0) await tapText(tester, '헷갈렸어요');
      await tapText(tester, index == 4 ? '연습 마치기' : '다음 글자');
    }

    expect(prefs.getBool('hiragana_pilot_review.v1.account-a.a'), isTrue);
    expect(prefs.getBool('katakana_pilot_review.v1.account-a.a'), isNull);
    expect(prefs.getBool(markKey), isTrue);
    await tapText(tester, '헷갈린 글자 복습');
    expect(find.text('1/1 글자 · 1/3 단계'), findsOneWidget);
    expect(find.text('あ · 아'), findsOneWidget);
  });

  testWidgets('the last row teaches wo as a particle in both scripts',
      (tester) async {
    final prefs = await _preferences({markKey: true});
    for (final hiragana in [true, false]) {
      await _pumpPilot(tester, prefs, hiragana: hiragana);
      await tapText(
        tester,
        KanaPracticeRow.waRow.label(hiragana: hiragana),
      );
      expect(find.text('1/3 글자 · 1/3 단계'), findsOneWidget);
      await tapText(tester, '가리고 쓰기');
      await tapText(tester, '쓰기 건너뛰기');
      await tapText(tester, hiragana ? 'わ' : 'ワ');
      await tapText(tester, '다음 글자');
      expect(find.text('2/3 글자 · 1/3 단계'), findsOneWidget);
      await tapText(tester, '가리고 쓰기');
      expect(find.text(hiragana ? '오 (목적격 조사)' : 'を'), findsOneWidget);
      await tapText(tester, '쓰기 건너뛰기');
      expect(find.text('문장에서 찾기'), findsOneWidget);
      if (!hiragana) {
        expect(find.textContaining('가타카나로 옮겨 적은 문장'), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('katakana-word-character-0')));
      await tester.pump();
      expect(find.textContaining('다시 찾아보세요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('katakana-word-character-2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('맞았어요!'), findsOneWidget);
      expect(prefs.getBool(markKey), isTrue);
    }
  });

  testWidgets('small hiragana keeps a separate mark and shows a size hint',
      (tester) async {
    const regularA = 'hiragana_pilot_review.v1.account-a.a';
    const smallA = 'hiragana_pilot_review.v1.account-a.smallA';
    final prefs = await _preferences({regularA: true});
    await _pumpPilot(tester, prefs, hiragana: true);
    await tapText(tester, 'ぁ・ぃ・ぅ・ぇ・ぉ');
    expect(find.text('1/5 글자 · 1/3 단계'), findsOneWidget);
    await tapText(tester, '가리고 쓰기');
    expect(find.text('작은 아'), findsOneWidget);
    expect(find.text('ぁ'), findsNothing);
    await tapText(tester, '쓰기 건너뛰기');
    expect(find.text('글자 조합에서 찾기'), findsOneWidget);
    await tapText(tester, 'ぁ');
    expect(find.textContaining('맞았어요! ふぁ'), findsOneWidget);
    await tapText(tester, '헷갈렸어요');
    expect(prefs.getBool(regularA), isTrue);
    expect(prefs.getBool(smallA), isTrue);
    expect(prefs.getBool('katakana_pilot_review.v1.account-a.smallA'), isNull);
  });

  testWidgets('textbook replay and compare share the same filled outline',
      (tester) async {
    const letter = KatakanaPilotLetter.e;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            const KatakanaStrokeComparison(
              letter: letter,
              showComparison: false,
            ),
            KatakanaRecallPad(example: letter, onInkChanged: (_) {}),
          ],
        ),
      ),
    ));

    List<Invocation> paint(Finder widget) {
      final square = find.descendant(
        of: widget,
        matching: find.byType(AspectRatio),
      );
      final customPaint = find.descendant(
        of: square,
        matching: find.byType(CustomPaint),
      );
      final recording = TestRecordingCanvas();
      tester.widget<CustomPaint>(customPaint).painter!.paint(
            recording,
            const Size.square(144),
          );
      return recording.invocations.map((record) => record.invocation).toList();
    }

    final diagram = find.byType(KatakanaStrokeComparison);
    await tester.tap(find.text('획순 재생'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(paint(diagram).map((call) => call.memberName), contains(#clipPath));
    await tester.pumpAndSettle();

    List<Path> filledPaths(Finder widget) => [
          for (final call in paint(widget))
            if (call.memberName == #drawPath &&
                (call.positionalArguments[1] as Paint).style ==
                    PaintingStyle.fill)
              call.positionalArguments.first as Path,
        ];
    final silhouette = filledPaths(diagram).single;
    final overlay = filledPaths(find.byType(KatakanaRecallPad)).single;
    expect(
      Path.combine(PathOperation.xor, silhouette, overlay).computeMetrics(),
      isEmpty,
    );
  });

  testWidgets('both entrances share one persisted ウ review mark',
      (tester) async {
    final prefs = await _preferences({markKey: true});
    final day = DateTime(2026, 11, 4, 23, 59);
    const u = KatakanaPilotLetter.u;
    await _pumpPilot(tester, prefs, clock: () => day);

    await tapText(tester, 'フ・ワ・ウ');
    for (final letter in [KatakanaPilotLetter.fu, KatakanaPilotLetter.wa]) {
      await skipWriteAndFind(tester, letter);
      await tapText(tester, '다음 글자');
    }
    await skipWriteAndFind(tester, u);
    await tapText(tester, '헷갈렸어요');
    await tapText(tester, '연습 마치기');

    await tapText(tester, 'ア・イ・ウ・エ・オ');
    for (final letter in [KatakanaPilotLetter.a, KatakanaPilotLetter.i]) {
      await skipWriteAndFind(tester, letter);
      await tapText(tester, '다음 글자');
    }
    await skipWriteAndFind(tester, u);
    expect(find.text('다음 복습에 저장했어요.'), findsOneWidget);
    await tapText(tester, '헷갈림 표시 지우기');
    expect(prefs.getBool(uMarkKey), false);
    await tapText(tester, '헷갈렸어요');
    expect(prefs.getBool(uMarkKey), true);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final nextDay = DateTime(2026, 11, 5);
    await _pumpPilot(tester, prefs, clock: () => nextDay);
    await showText(tester, '이 기기에 저장된 복습');
    expect(find.text('シ · ウ'), findsOneWidget);
    expect(find.text('오늘 새 단어로 복습할 글자 2개'), findsOneWidget);
    await tapText(tester, '새 단어로 복습');
    await tapText(tester, 'シ');
    await tapText(tester, '다음 글자');
    expect(find.text('2/2 글자 · 새 단어 복습'), findsOneWidget);
    await tapText(tester, 'ウ');
    expect(find.textContaining('맞았어요! ウール'), findsOneWidget);
    await tapText(tester, '연습 마치기');
    await showText(tester, '이 기기에 저장된 복습');
    expect(find.text('새 단어로 복습'), findsNothing);
    expect(find.text('シ · ウ'), findsOneWidget);
    expect(prefs.getBool(markKey), true);
    expect(prefs.getBool(uMarkKey), true);
    expect(prefs.getInt('existing-learning-value'), 3);
  });

  testWidgets('stored uncertainty offers only the marked letter on re-entry',
      (tester) async {
    final prefs = await _preferences({markKey: true});
    await _pumpPilot(tester, prefs, owner: 'account-b');
    await showText(tester, '이 기기에 저장된 복습');
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
    await showText(tester, '이 기기에 저장된 복습');
    expect(find.text('헷갈린 글자 복습'), findsNothing);
    expect(prefs.getBool(markKey), isNot(true));
  });

  testWidgets('a new mark offers an alternate word after local midnight',
      (tester) async {
    final prefs = await _preferences();
    var now = DateTime(2026, 11, 4, 23, 59);
    await _pumpPilot(tester, prefs, clock: () => now);
    await start(tester);
    await tapText(tester, '쓰기 건너뛰기');
    await tapText(tester, 'シ');
    expect(find.textContaining('맞았어요! ミシン'), findsOneWidget);
    await tapText(tester, '헷갈렸어요');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await _pumpPilot(tester, prefs, clock: () => now);
    await showText(tester, '이 기기에 저장된 복습');
    expect(find.text('새 단어로 복습'), findsNothing);
    expect(find.text('헷갈린 글자 복습'), findsOneWidget);

    now = DateTime(2026, 11, 5);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    await tapText(tester, '새 단어로 복습');
    expect(find.text('1/1 글자 · 새 단어 복습'), findsOneWidget);
    expect(find.textContaining('‘し’에 해당하는 글자'), findsOneWidget);
    expect(find.text('ミ'), findsNothing);
    await tapText(tester, 'ル');
    expect(find.textContaining('다시 찾아보세요.'), findsOneWidget);
    await tapText(tester, 'シ');
    expect(find.textContaining('맞았어요! シール'), findsOneWidget);
    await tapText(tester, '연습 마치기');

    await showText(tester, '이 기기에 저장된 복습');
    expect(find.text('새 단어로 복습'), findsNothing);
    expect(find.text('헷갈린 글자 복습'), findsOneWidget);
    expect(prefs.getBool(markKey), true);
  });

  testWidgets('daily review reopens with only the remaining marked letter',
      (tester) async {
    final prefs = await _preferences({markKey: true, fuMarkKey: true});
    final now = DateTime(2026, 11, 5, 10);
    await _pumpPilot(tester, prefs, clock: () => now);
    await tapText(tester, '새 단어로 복습');
    expect(find.text('1/2 글자 · 새 단어 복습'), findsOneWidget);
    await tapText(tester, 'シ');
    expect(find.textContaining('맞았어요! シール'), findsOneWidget);

    final next = find.widgetWithText(FilledButton, '다음 글자');
    final onNext = tester.widget<FilledButton>(next).onPressed!;
    onNext();
    onNext();
    await tester.pumpAndSettle();
    expect(find.text('2/2 글자 · 새 단어 복습'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await _pumpPilot(tester, prefs, clock: () => now);
    await showText(tester, '이 기기에 저장된 복습');
    expect(find.text('シ · フ'), findsOneWidget);
    expect(find.text('오늘 새 단어로 복습할 글자 1개'), findsOneWidget);
    await tapText(tester, '새 단어로 복습');
    expect(find.text('1/1 글자 · 새 단어 복습'), findsOneWidget);
    expect(find.textContaining('‘ふ’에 해당하는 글자'), findsOneWidget);
    await tapText(tester, 'フ');
    expect(find.textContaining('맞았어요! ナイフ'), findsOneWidget);

    await tapText(tester, '헷갈림 표시 지우기');
    await tapText(tester, '헷갈렸어요');
    await tapText(tester, '연습 마치기');
    await showText(tester, '이 기기에 저장된 복습');
    expect(find.text('새 단어로 복습'), findsNothing);
    expect(prefs.getBool(markKey), true);
    expect(prefs.getBool(fuMarkKey), true);
    expect(prefs.getInt('existing-learning-value'), 3);
  });

  testWidgets('a failed daily completion stays on the answer and can retry',
      (tester) async {
    final prefs = await _preferences({markKey: true});
    await _pumpPilot(tester, prefs, reviewFactory: _FailOnceReview.new);
    await tapText(tester, '새 단어로 복습');
    await tapText(tester, 'シ');
    await tapText(tester, '연습 마치기');
    expect(find.text('기기에 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('맞았어요! シール'), findsOneWidget);
    await tapText(tester, '연습 마치기');
    await showText(tester, '이 기기에 저장된 복습');
    expect(find.text('새 단어로 복습'), findsNothing);
    expect(find.text('헷갈린 글자 복습'), findsOneWidget);
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
    expect(find.text('가타카나 쓰기 연습'), findsOneWidget);
  });

  testWidgets('hiragana has the local entry even when stage fetch fails',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kanaStagesProvider('HIRAGANA')
              .overrideWith((ref) async => throw StateError('offline')),
        ],
        child: const MaterialApp(home: KanaTypePage(type: 'hiragana')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('히라가나 쓰기 연습'), findsOneWidget);
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
  DateTime Function()? clock,
  KatakanaPilotReview Function()? reviewFactory,
  double width = 412,
  double textScale = 1,
  bool hiragana = false,
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
        if (clock != null) studyClockProvider.overrideWithValue(clock),
        if (reviewFactory != null)
          katakanaPilotReviewProvider.overrideWith(reviewFactory),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: KanaPilotPage(hiragana: hiragana),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FailOnceReview extends KatakanaPilotReview {
  bool _failed = false;

  @override
  Future<void> completeDailyReview(
    KanaPracticeLetter letter,
    DateTime day,
  ) async {
    if (!_failed) {
      _failed = true;
      throw const ApiException(message: '기기에 저장하지 못했어요. 다시 시도해 주세요.');
    }
    await super.completeDailyReview(letter, day);
  }
}
